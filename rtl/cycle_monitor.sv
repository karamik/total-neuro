// ========================================================================
// cycle_monitor.sv – Fixed Cycle Count Monitor для STDP-окон
// Защита от clock glitching: считает такты для критических операций,
// сравнивает с ожидаемым, сигнализирует о глитче при несовпадении.
// ========================================================================

module cycle_monitor #(
    parameter EXPECTED_CYCLES = 32'd12000000,  // 12M cycles по умолчанию
    parameter TOLERANCE       = 32'd0          // 0 – точное совпадение
)(
    input  logic        clk,
    input  logic        rst_n,

    // Управление
    input  logic        start,                 // старт операции
    input  logic        done,                  // сигнал завершения
    input  logic        test_mode,             // отключить в тестах

    // Статус
    output logic        glitch_detected,       // HIGH – цикл не совпал
    output logic        operation_ok,          // HIGH – цикл совпал
    output logic [31:0] cycles_measured        // для отладки
);


    // ================================================================
    // Internal registers
    // ================================================================
    logic [31:0] cycle_counter;
    logic        counting;
    logic        glitch_reg;
    logic        ok_reg;

    // ================================================================
    // Sequential logic
    // ================================================================
    always_ff @(posedge clk or negedge rst_n) begin
        if (!rst_n) begin
            cycle_counter  <= 32'h0;
            counting       <= 1'b0;
            glitch_reg     <= 1'b0;
            ok_reg         <= 1'b0;
        end else if (test_mode) begin
            cycle_counter  <= 32'h0;
            counting       <= 1'b0;
            glitch_reg     <= 1'b0;
            ok_reg         <= 1'b1;
        end else begin
            // Start counting
            if (start && !counting) begin
                cycle_counter <= 32'h0;
                counting      <= 1'b1;
                glitch_reg    <= 1'b0;
                ok_reg        <= 1'b0;
            end else if (counting) begin
                cycle_counter <= cycle_counter + 32'h1;

                // Done - check cycle count
                if (done) begin
                    counting <= 1'b0;
                    // Note: cycle_counter is about to increment (non-blocking)
                    if ((cycle_counter + 1) >= (EXPECTED_CYCLES - TOLERANCE) &&
                        (cycle_counter + 1) <= (EXPECTED_CYCLES + TOLERANCE)) begin
                        ok_reg     <= 1'b1;
                        glitch_reg <= 1'b0;
                    end else begin
                        ok_reg     <= 1'b0;
                        glitch_reg <= 1'b1;  // glitch detected!
                    end
                end
            end
        end
    end


    // ================================================================
    // Outputs
    // ================================================================
    assign glitch_detected = glitch_reg;
    assign operation_ok    = ok_reg;
    assign cycles_measured = cycle_counter;

endmodule
