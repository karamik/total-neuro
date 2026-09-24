`timescale 1ns/1ps
// consent_gate_formal.sv
// Formal verification harness using only DUT output ports.
// No hierarchical references, no $past on internal signals.

module consent_gate_formal (
    input logic clk,
    input logic rst_n
);

    (* anyseq *) logic        cmd_valid;
    (* anyseq *) logic [31:0] cmd_data;
    (* anyseq *) logic        sig_ecdsa;
    (* anyseq *) logic        sig_dilithium;
    (* anyseq *) logic        both_valid;
    (* anyseq *) logic        consent;
    (* anyseq *) logic        tamper;

    wire        gated_cmd_valid;
    wire [31:0] gated_cmd_data;
    wire        refusal_flag;
    wire        kill_switch;
    wire [7:0]  refusal_count;
    wire        audit_valid;
    wire [31:0] audit_event;
    wire [2:0]  debug_state;
    wire [2:0]  debug_state_r;

    consent_gate #(
        .CMD_WIDTH(32),
        .TIMEOUT_CYCLES(16),
        .REFUSAL_WIDTH(8)
    ) dut (
        .clk_main(clk),
        .rst_main_n(rst_n),
        .clk_gate(clk),
        .rst_gate_n(rst_n),
        .clk_audit(clk),
        .rst_audit_n(rst_n),
        .cmd_valid_i(cmd_valid),
        .cmd_data_i(cmd_data),
        .sig_ecdsa_valid_i(sig_ecdsa),
        .sig_dilithium_valid_i(sig_dilithium),
        .both_valid_i(both_valid),
        .external_consent_i(consent),
        .tamper_detect_i(tamper),
        .gated_cmd_valid_o(gated_cmd_valid),
        .gated_cmd_data_o(gated_cmd_data),
        .refusal_flag_o(refusal_flag),
        .kill_switch_o(kill_switch),
        .refusal_count_o(refusal_count),
        .audit_valid_o(audit_valid),
        .audit_event_o(audit_event),
        .debug_state_o(debug_state),
        .debug_state_r_o(debug_state_r)
    );

    localparam logic [2:0] S_IDLE         = 3'd0;
    localparam logic [2:0] S_WAIT_SIG     = 3'd1;
    localparam logic [2:0] S_WAIT_CONSENT = 3'd2;
    localparam logic [2:0] S_PASS         = 3'd3;
    localparam logic [2:0] S_REFUSE       = 3'd4;
    localparam logic [2:0] S_ZEROIZE      = 3'd5;

    always @(posedge clk) begin
        if ($initstate)
            assume(!rst_n);
    end

    logic rst_n_d1, rst_n_d2, rst_n_d3;
    always @(posedge clk) begin
        rst_n_d1 <= rst_n;
        rst_n_d2 <= rst_n_d1;
        rst_n_d3 <= rst_n_d2;
    end
    wire check_active = rst_n_d1 && rst_n_d2 && rst_n_d3 && rst_n;

    // Invariant 1: kill_switch is sticky.
    always @(posedge clk) begin
        if (check_active && $past(kill_switch, 1) && $past(rst_n, 1))
            assert(kill_switch);
    end

    // Invariant 2a: entering WAIT_CONSENT requires both signatures
    // valid in the transition cycle.
    always @(posedge clk) begin
        if (check_active
            && debug_state_r == S_WAIT_CONSENT
            && $past(debug_state_r, 1) == S_WAIT_SIG)
            assert($past(both_valid, 1)
                || ($past(sig_ecdsa, 1) && $past(sig_dilithium, 1)));
    end

    // Invariant 2b: entering PASS requires consent in the transition cycle.
    always @(posedge clk) begin
        if (check_active
            && debug_state_r == S_PASS
            && $past(debug_state_r, 1) == S_WAIT_CONSENT)
            assert($past(consent, 1));
    end

    // Invariant 2c: gated_cmd_valid implies effective state is S_PASS.
    always @(posedge clk) begin
        if (check_active && gated_cmd_valid)
            assert(debug_state == S_PASS);
    end

    // Invariant 3: kill_switch and gated_cmd_valid are mutually exclusive.
    always @(posedge clk) begin
        if (check_active)
            assert(!(kill_switch && gated_cmd_valid));
    end

endmodule
