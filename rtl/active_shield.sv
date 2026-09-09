// ========================================================================
// Active Shield – защита от физического вмешательства
// Генерирует случайный меандр, проверяет целостность цепей.
// При обрыве – аварийное стирание (zeroization) и блокировка.
// ========================================================================

module active_shield (
    input  logic        clk,
    input  logic        rst_n,
    input  logic        shield_enable,   // активация защиты (после загрузки)
    input  logic        scan_mode,       // отключаем для DFT
    input  logic        test_mode,       // отключаем для тестов
    output logic        shield_ok,       // HIGH – меандр цел
    output logic        shield_fault,    // HIGH – обнаружено нарушение
    output logic        zeroize_req      // запрос на стирание ключей и сброс
);

    // Меандр: случайная последовательность длиной 32 бита
    // Она «размазывается» по верхнему слою металла в виде змеевидной дорожки.
    // Входной сигнал сравнивается с ожидаемым (заданным при инициализации).

    localparam SHIELD_PATTERN_LEN = 32;
    logic [SHIELD_PATTERN_LEN-1:0] expected_pattern;
    logic [SHIELD_PATTERN_LEN-1:0] actual_pattern;
    logic [SHIELD_PATTERN_LEN-1:0] pattern_reg;

    // Генератор псевдослучайной последовательности (LFSR) для меандра
    logic [31:0] lfsr;
    always_ff @(posedge clk or negedge rst_n) begin
        if (!rst_n) begin
            lfsr <= 32'hDEAD_BEEF;   // начальное семя
        end else if (shield_enable && !scan_mode && !test_mode) begin
            // Классический LFSR (32-бит)
            lfsr <= {lfsr[30:0], lfsr[31] ^ lfsr[21] ^ lfsr[1] ^ lfsr[0]};
        end
    end

    // Ожидаемый паттерн – начальное состояние, запоминается при первом включении
    always_ff @(posedge clk or negedge rst_n) begin
        if (!rst_n) begin
            expected_pattern <= 32'h0;
        end else if (shield_enable && !scan_mode && !test_mode) begin
            // Запоминаем эталон только один раз
            if (expected_pattern == 32'h0)
                expected_pattern <= lfsr;
        end
    end

    // Фактический паттерн – считанный с меандра (в реальности это физические пины)
    // Для симуляции используем тот же LFSR, но в реальности это порт ввода.
    // Мы создаём отдельный сигнал, который в симуляции можно инжектировать сбой.
    assign actual_pattern = lfsr; // заглушка – в реальности подключить к буферу меандра

    // Сравнение с допустимым отклонением (допускаем небольшие флуктуации)
    logic mismatch;
    assign mismatch = (actual_pattern != expected_pattern) && shield_enable && !scan_mode && !test_mode;

    // Интегратор для фильтрации кратковременных помех (анти-дребезг)
    logic [3:0] fault_counter;
    always_ff @(posedge clk or negedge rst_n) begin
        if (!rst_n) begin
            fault_counter <= 4'h0;
            shield_fault <= 1'b0;
            zeroize_req <= 1'b0;
        end else if (scan_mode || test_mode) begin
            shield_fault <= 1'b0;
            zeroize_req <= 1'b0;
        end else if (mismatch) begin
            if (fault_counter < 4'd15)
                fault_counter <= fault_counter + 1;
            else begin
                shield_fault <= 1'b1;
                zeroize_req <= 1'b1;  // активация стирания
            end
        end else begin
            if (fault_counter > 0)
                fault_counter <= fault_counter - 1;
            else
                shield_fault <= 1'b0;
        end
    end

    // Сигнал OK – если нет ошибки
    assign shield_ok = !shield_fault && shield_enable;

endmodule
