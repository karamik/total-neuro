// ========================================================================
// shield_health_monitor.sv – Graduated response для Active Shield
// Считает число обрывов в N+1 меандре и выдаёт уровень тревоги.
//   LEVEL 0 (OK):       0 обрывов  → всё работает
//   LEVEL 1 (WARNING):  1 обрыв    → требуется переаттестация
//   LEVEL 2 (CRITICAL): 2 обрыва   → блокировка новых операций
//   LEVEL 3 (ZEROIZE):  3 обрыва   → аварийное стирание ключей
// ========================================================================

module shield_health_monitor #(
    parameter NUM_TRACES = 3
)(
    input  logic        clk,
    input  logic        rst_n,

    // Входы от трёх параллельных меандров (1 = цел, 0 = обрыв)
    input  logic [NUM_TRACES-1:0] trace_ok,

    input  logic        test_mode,

    // Уровни тревоги
    output logic        level_ok,        // 0 обрывов
    output logic        level_warning,   // 1 обрыв
    output logic        level_critical,  // 2 обрыва
    output logic        level_zeroize,   // 3+ обрыва

    // Счётчик обрывов (для телеметрии)
    output logic [7:0]  breaks_count,
    output logic [1:0]  alarm_level
);


    // ================================================================
    // Internal registers
    // ================================================================
    logic [1:0]  alarm_level_reg;
    logic [7:0]  breaks_reg;

    // ================================================================
    // Count breaks in trace_ok vector
    // ================================================================
    logic [7:0] breaks_now;
    integer i;
    always_comb begin
        breaks_now = 8'h0;
        for (i = 0; i < NUM_TRACES; i = i + 1) begin
            if (!trace_ok[i]) breaks_now = breaks_now + 8'h1;
        end
    end

    // ================================================================
    // Sequential logic: update alarm level
    // ================================================================
    always_ff @(posedge clk or negedge rst_n) begin
        if (!rst_n) begin
            alarm_level_reg <= 2'b00;
            breaks_reg      <= 8'h0;
        end else if (test_mode) begin
            alarm_level_reg <= 2'b00;
            breaks_reg      <= 8'h0;
        end else begin
            breaks_reg <= breaks_now;

            if (breaks_now == 0)
                alarm_level_reg <= 2'b00;  // OK
            else if (breaks_now == 1)
                alarm_level_reg <= 2'b01;  // WARNING
            else if (breaks_now == 2)
                alarm_level_reg <= 2'b10;  // CRITICAL
            else
                alarm_level_reg <= 2'b11;  // ZEROIZE
        end
    end


    // ================================================================
    // Outputs
    // ================================================================
    assign alarm_level    = alarm_level_reg;
    assign breaks_count   = breaks_reg;

    assign level_ok       = (alarm_level_reg == 2'b00);
    assign level_warning  = (alarm_level_reg == 2'b01);
    assign level_critical = (alarm_level_reg == 2'b10);
    assign level_zeroize  = (alarm_level_reg == 2'b11);

endmodule
