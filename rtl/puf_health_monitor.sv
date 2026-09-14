// ========================================================================
// puf_health_monitor.sv – Мониторинг старения PUF
// Отслеживает дрейф отпечатка во времени, сигнализирует о необходимости
// переаттестации ДО того, как PUF выйдет за границы коррекции.
// ========================================================================

module puf_health_monitor #(
    parameter DRIFT_WARNING_THRESHOLD  = 8'h10,  // 16% дрейфа = warning
    parameter DRIFT_CRITICAL_THRESHOLD = 8'h20,  // 32% дрейфа = critical
    parameter SAMPLE_INTERVAL          = 32'd1000000  // тактов между проверками
)(
    input  logic        clk,
    input  logic        rst_n,

    // Входы от PUF
    input  logic [127:0] puf_id_current,     // текущий отпечаток
    input  logic [127:0] puf_id_golden,      // эталон (зашит при инициализации)
    input  logic         puf_valid,          // HIGH – отпечаток готов к чтению

    input  logic         test_mode,

    // Выходы
    output logic         drift_warning,      // HIGH – требуется переаттестация
    output logic         drift_critical,     // HIGH – приближается к пределу
    output logic [7:0]   drift_percent,      // процент дрейфа
    output logic [31:0]  samples_since_reset // счётчик проверок
);


    // ================================================================
    // Internal registers
    // ================================================================
    logic [31:0] sample_counter;
    logic [7:0]  drift_reg;
    logic        warning_reg;
    logic        critical_reg;
    logic [31:0] samples_reg;

    // ================================================================
    // Hamming distance (bit differences between current and golden)
    // ================================================================
    logic [7:0] hamming_dist;
    integer i;
    always_comb begin
        hamming_dist = 8'h0;
        for (i = 0; i < 128; i = i + 1) begin
            if (puf_id_current[i] != puf_id_golden[i])
                hamming_dist = hamming_dist + 8'h1;
        end
    end

    // Drift percent = hamming_dist * 100 / 128 (approx: * 100 >> 7)
    logic [15:0] drift_calc;
    always_comb begin
        // hamming_dist * 100 / 128 = hamming_dist * 25 / 32
        drift_calc = (hamming_dist * 16'd25) >> 5;
    end


    // ================================================================
    // Sequential logic
    // ================================================================
    always_ff @(posedge clk or negedge rst_n) begin
        if (!rst_n) begin
            sample_counter <= 32'h0;
            drift_reg      <= 8'h0;
            warning_reg    <= 1'b0;
            critical_reg   <= 1'b0;
            samples_reg    <= 32'h0;
        end else if (test_mode) begin
            sample_counter <= 32'h0;
            drift_reg      <= 8'h0;
            warning_reg    <= 1'b0;
            critical_reg   <= 1'b0;
            samples_reg    <= 32'h0;
        end else begin
            // Update drift whenever PUF is read
            if (puf_valid) begin
                drift_reg <= drift_calc[7:0];
                samples_reg <= samples_reg + 32'h1;

                // Set warning/critical based on drift
                if (drift_calc[7:0] >= DRIFT_CRITICAL_THRESHOLD) begin
                    critical_reg <= 1'b1;
                    warning_reg  <= 1'b1;
                end else if (drift_calc[7:0] >= DRIFT_WARNING_THRESHOLD) begin
                    warning_reg  <= 1'b1;
                    critical_reg <= 1'b0;
                end else begin
                    warning_reg  <= 1'b0;
                    critical_reg <= 1'b0;
                end
            end

            // Periodic sampling counter
            if (sample_counter < SAMPLE_INTERVAL)
                sample_counter <= sample_counter + 32'h1;
            else
                sample_counter <= 32'h0;
        end
    end


    // ================================================================
    // Outputs
    // ================================================================
    assign drift_warning      = warning_reg;
    assign drift_critical     = critical_reg;
    assign drift_percent      = drift_reg;
    assign samples_since_reset = samples_reg;

endmodule
