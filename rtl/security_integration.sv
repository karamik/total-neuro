// ========================================================================
// security_integration.sv – связка cycle_monitor + apollo_kill_switch
// Автоматическая активация kill switch при обнаружении clock glitch.
// ========================================================================

module security_integration #(
    parameter EXPECTED_CYCLES = 32'd12000000,
    parameter TOLERANCE       = 32'd0
)(
    input  logic        clk,
    input  logic        rst_n,

    // Cycle monitor control
    input  logic        op_start,           // старт критической операции
    input  logic        op_done,            // завершение операции

    // Apollo triggers
    input  logic        zeroize_req,
    input  logic        integrity_fault,
    input  logic        global_key,
    input  logic        sovereign_key,

    // Control
    input  logic        arm,
    input  logic        test_mode,

    // Status
    output logic        power_cutoff,
    output logic        kill_armed,
    output logic        kill_triggered,
    output logic        glitch_detected,
    output logic        operation_ok,
    output logic [31:0] cycles_measured
);

    // Wire from cycle_monitor to apollo
    logic cm_glitch;

    // Cycle monitor instance
    cycle_monitor #(
        .EXPECTED_CYCLES(EXPECTED_CYCLES),
        .TOLERANCE(TOLERANCE)
    ) u_cycle_mon (
        .clk(clk),
        .rst_n(rst_n),
        .start(op_start),
        .done(op_done),
        .test_mode(test_mode),
        .glitch_detected(cm_glitch),
        .operation_ok(operation_ok),
        .cycles_measured(cycles_measured)
    );


    // Apollo kill switch instance
    apollo_kill_switch u_apollo (
        .clk(clk),
        .rst_n(rst_n),
        .zeroize_req(zeroize_req),
        .integrity_fault(integrity_fault),
        .clock_glitch(cm_glitch),      // <-- auto-trigger from cycle monitor
        .global_key(global_key),
        .sovereign_key(sovereign_key),
        .arm(arm),
        .test_mode(test_mode),
        .power_cutoff(power_cutoff),
        .kill_armed(kill_armed),
        .kill_triggered(kill_triggered)
    );

    // Expose glitch signal
    assign glitch_detected = cm_glitch;

endmodule
