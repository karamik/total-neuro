// ========================================================================
// apollo_kill_switch.sv – аппаратный разрыв питания (Apollo-2)
// Последний рубеж защиты: физически отключает чип при компрометации.
// Логика: power_cutoff = zeroize_req OR integrity_fault OR !(global_key AND sovereign_key)
// ========================================================================

module apollo_kill_switch (
    input  logic        clk,
    input  logic        rst_n,

    // Триггеры активации
    input  logic        zeroize_req,        // от Active Shield
    input  logic        integrity_fault,    // от TMR (majority disagreement)
    input  logic        clock_glitch,       // от детектора глитчей

    // Двухключевая система
    input  logic        global_key,         // от 2/3 валидаторов сети
    input  logic        sovereign_key,      // от оператора/государства

    // Управление
    input  logic        arm,                // включение защиты (после загрузки)
    input  logic        test_mode,          // отключает kill switch для DFT

    // Выходы
    output logic        power_cutoff,       // HIGH – физически рвёт питание
    output logic        kill_armed,         // защита активна
    output logic        kill_triggered      // защита сработала (latched)
);


    // ================================================================
    // Internal registers
    // ================================================================
    logic cutoff_latched;
    logic armed_reg;

    // ================================================================
    // Key combination (dual-key AND)
    // ================================================================
    wire keys_valid = global_key && sovereign_key;

    // ================================================================
    // Kill trigger logic
    // ================================================================
    wire kill_event = zeroize_req || integrity_fault || clock_glitch || !keys_valid;

    // ================================================================
    // Sequential logic: arm, trigger, latch
    // ================================================================
    always_ff @(posedge clk or negedge rst_n) begin
        if (!rst_n) begin
            armed_reg     <= 1'b0;
            cutoff_latched <= 1'b0;
        end else if (test_mode) begin
            // В тестовом режиме защита отключена
            armed_reg     <= 1'b0;
            cutoff_latched <= 1'b0;
        end else begin
            // Arm protection
            if (arm) begin
                armed_reg <= 1'b1;
            end

            // Trigger cutoff (irreversible until reset)
            if (armed_reg && kill_event) begin
                cutoff_latched <= 1'b1;
            end
        end
    end


    // ================================================================
    // Outputs
    // ================================================================
    assign power_cutoff   = cutoff_latched;
    assign kill_armed     = armed_reg;
    assign kill_triggered = cutoff_latched;

endmodule
