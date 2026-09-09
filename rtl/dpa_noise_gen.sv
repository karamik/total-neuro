// ========================================================================
// dpa_noise_gen – генератор шума для противодействия DPA
// Создаёт псевдослучайные переходы, синхронизированные с тактом,
// и обеспечивает сигналы для WDDL (двойные линии данных).
// ========================================================================

module dpa_noise_gen (
    input  logic        clk,
    input  logic        rst_n,
    input  logic        enable,          // включение защиты
    input  logic        test_mode,
    output logic [31:0] noise_bus,       // шумовая шина для смешивания
    output logic        wddl_clk,        // тактовый сигнал для WDDL
    output logic        wddl_clk_n       // инверсный такт
);

    // Генератор шума на основе двух LFSR с разными полиномами
    logic [31:0] lfsr_a, lfsr_b;

    always_ff @(posedge clk or negedge rst_n) begin
        if (!rst_n) begin
            lfsr_a <= 32'h1234_5678;
            lfsr_b <= 32'h9ABC_DEF0;
        end else if (enable && !test_mode) begin
            // LFSR A – полином x^32 + x^22 + x^2 + x^1 + 1
            lfsr_a <= {lfsr_a[30:0], lfsr_a[31] ^ lfsr_a[21] ^ lfsr_a[1] ^ lfsr_a[0]};
            // LFSR B – другой полином x^32 + x^26 + x^23 + x^17 + 1
            lfsr_b <= {lfsr_b[30:0], lfsr_b[31] ^ lfsr_b[25] ^ lfsr_b[22] ^ lfsr_b[16]};
        end
    end

    // Формируем шумовой вектор (XOR двух LFSR)
    assign noise_bus = enable ? (lfsr_a ^ lfsr_b) : 32'h0;

    // Генерация двухфазного такта для WDDL
    assign wddl_clk   = enable ? clk : 1'b0;
    assign wddl_clk_n = enable ? ~clk : 1'b1;

endmodule
