// ========================================================================
// tmr_reg – Triple Modular Redundancy регистр
// Защищает критичные данные от сбоев (в т.ч. лазерных)
// ========================================================================

module tmr_reg #(
    parameter WIDTH = 32
)(
    input  logic               clk,
    input  logic               rst_n,
    input  logic               enable,       // разрешение записи
    input  logic [WIDTH-1:0]   d_in,         // входные данные
    input  logic               test_mode,    // отключаем для тестов
    output logic [WIDTH-1:0]   d_out         // выходные данные (исправленные)
);

    // Три независимых регистра с разными начальными состояниями (для разнообразия)
    logic [WIDTH-1:0] reg_a, reg_b, reg_c;

    always_ff @(posedge clk or negedge rst_n) begin
        if (!rst_n) begin
            reg_a <= {WIDTH{1'b0}};
            reg_b <= {WIDTH{1'b1}};  // инверсное начальное состояние
            reg_c <= 'hA5A5;          // другое случайное
        end else if (enable) begin
            reg_a <= d_in;
            reg_b <= d_in;
            reg_c <= d_in;
        end
    end

    // Мажоритарный голос (поразрядно)
    assign d_out = (reg_a & reg_b) | (reg_a & reg_c) | (reg_b & reg_c);

endmodule
