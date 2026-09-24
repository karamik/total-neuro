`timescale 1ns/1ps
// top_arty_a7.sv
// Demo wrapper for consent_gate on Digilent Arty A7-35T.
//
// Pin mapping:
//   sw[0] = external_consent_i
//   sw[1] = sig_ecdsa_valid_i
//   sw[2] = sig_dilithium_valid_i
//   sw[3] = cmd_valid_i
//   btn[0] = tamper_detect_i
//   btn[1] = reset (active-high, pressed = 1)
//   led[0] = kill_switch
//   led[1] = refuse (stretched)
//   led[2] = pass (stretched)
//   led[3] = heartbeat ~1 Hz
//   rgb_r/g/b = refusal_count[0..2]

module top_arty_a7 (
    input  logic       clk100,
    input  logic [3:0] btn,
    input  logic [3:0] sw,
    output logic [3:0] led,
    output logic       rgb_r,
    output logic       rgb_g,
    output logic       rgb_b
);

    wire rst_n = ~btn[1];

    wire clk_main  = clk100;
    wire clk_gate  = clk100;
    wire clk_audit = clk100;

    wire        cmd_valid     = sw[3];
    wire [31:0] cmd_data      = 32'hDEADBEEF;
    wire        sig_ecdsa     = sw[1];
    wire        sig_dilithium = sw[2];
    wire        consent       = sw[0];
    wire        tamper        = btn[0];

    wire         gated_cmd_valid;
    wire [31:0]  gated_cmd_data;
    wire         refusal_flag;
    wire         kill_switch;
    wire [7:0]   refusal_count;
    wire         audit_valid;
    wire [31:0]  audit_event;

    consent_gate #(
        .CMD_WIDTH(32),
        .TIMEOUT_CYCLES(16),
        .REFUSAL_WIDTH(8)
    ) u_gate (
        .clk_main(clk_main),
        .rst_main_n(rst_n),
        .clk_gate(clk_gate),
        .rst_gate_n(rst_n),
        .clk_audit(clk_audit),
        .rst_audit_n(rst_n),
        .cmd_valid_i(cmd_valid),
        .cmd_data_i(cmd_data),
        .sig_ecdsa_valid_i(sig_ecdsa),
        .sig_dilithium_valid_i(sig_dilithium),
        .both_valid_i(1'b0),
        .external_consent_i(consent),
        .tamper_detect_i(tamper),
        .gated_cmd_valid_o(gated_cmd_valid),
        .gated_cmd_data_o(gated_cmd_data),
        .refusal_flag_o(refusal_flag),
        .kill_switch_o(kill_switch),
        .refusal_count_o(refusal_count),
        .audit_valid_o(audit_valid),
        .audit_event_o(audit_event)
    );

    logic gated_d, refusal_d;
    always @(posedge clk100 or negedge rst_n) begin
        if (!rst_n) begin
            gated_d   <= 1'b0;
            refusal_d <= 1'b0;
        end else begin
            gated_d   <= gated_cmd_valid;
            refusal_d <= refusal_flag;
        end
    end

    wire pass_pulse   = gated_cmd_valid & ~gated_d;
    wire refuse_pulse = refusal_flag   & ~refusal_d;

    localparam int STRETCH_BITS = 26;
    logic [STRETCH_BITS-1:0] pass_stretch, refuse_stretch;
    wire pass_active   = |pass_stretch;
    wire refuse_active = |refuse_stretch;

    always @(posedge clk100 or negedge rst_n) begin
        if (!rst_n) begin
            pass_stretch   <= '0;
            refuse_stretch <= '0;
        end else begin
            if (pass_pulse)
                pass_stretch <= {STRETCH_BITS{1'b1}};
            else if (pass_active)
                pass_stretch <= pass_stretch - 1'b1;

            if (refuse_pulse)
                refuse_stretch <= {STRETCH_BITS{1'b1}};
            else if (refuse_active)
                refuse_stretch <= refuse_stretch - 1'b1;
        end
    end

    logic [26:0] hb;
    always @(posedge clk100 or negedge rst_n) begin
        if (!rst_n)
            hb <= '0;
        else
            hb <= hb + 1'b1;
    end

    assign led[0] = kill_switch;
    assign led[1] = refuse_active;
    assign led[2] = pass_active;
    assign led[3] = hb[26];

    assign rgb_r = refusal_count[0];
    assign rgb_g = refusal_count[1];
    assign rgb_b = refusal_count[2];

endmodule
