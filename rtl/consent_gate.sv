`timescale 1ns/1ps
// consent_gate.sv
// Critical command gate with debug state output port.

module consent_gate #(
    parameter int CMD_WIDTH      = 32,
    parameter int TIMEOUT_CYCLES = 16,
    parameter int REFUSAL_WIDTH  = 8
) (
    input  logic                     clk_main,
    input  logic                     rst_main_n,
    input  logic                     clk_gate,
    input  logic                     rst_gate_n,
    input  logic                     clk_audit,
    input  logic                     rst_audit_n,

    input  logic                     cmd_valid_i,
    input  logic [CMD_WIDTH-1:0]     cmd_data_i,

    input  logic                     sig_ecdsa_valid_i,
    input  logic                     sig_dilithium_valid_i,
    input  logic                     both_valid_i,
    input  logic                     external_consent_i,
    input  logic                     tamper_detect_i,

    output logic                     gated_cmd_valid_o,
    output logic [CMD_WIDTH-1:0]     gated_cmd_data_o,
    output logic                     refusal_flag_o,
    output logic                     kill_switch_o,
    output logic [REFUSAL_WIDTH-1:0] refusal_count_o,

    output logic                     audit_valid_o,
    output logic [31:0]              audit_event_o,

    // Debug outputs for formal verification.
    output logic [2:0]               debug_state_o,
    output logic [2:0]               debug_state_r_o
);

    localparam logic [31:0] EVT_PASS   = 32'h00000001;
    localparam logic [31:0] EVT_REFUSE = 32'h00000002;
    localparam logic [31:0] EVT_TAMPER = 32'h00000003;

    localparam logic [2:0] S_IDLE         = 3'd0;
    localparam logic [2:0] S_WAIT_SIG     = 3'd1;
    localparam logic [2:0] S_WAIT_CONSENT = 3'd2;
    localparam logic [2:0] S_PASS         = 3'd3;
    localparam logic [2:0] S_REFUSE       = 3'd4;
    localparam logic [2:0] S_ZEROIZE      = 3'd5;

    logic cmd_valid_s1, cmd_valid_s2, cmd_valid_s3;
    logic [CMD_WIDTH-1:0] cmd_data_sync;
    logic [CMD_WIDTH-1:0] cmd_data_latched;

    always @(posedge clk_gate or negedge rst_gate_n) begin
        if (!rst_gate_n) begin
            cmd_valid_s1 <= 1'b0;
            cmd_valid_s2 <= 1'b0;
            cmd_valid_s3 <= 1'b0;
            cmd_data_sync <= '0;
        end else begin
            cmd_valid_s1 <= cmd_valid_i;
            cmd_valid_s2 <= cmd_valid_s1;
            cmd_valid_s3 <= cmd_valid_s2;
            if (cmd_valid_s1 && !cmd_valid_s2)
                cmd_data_sync <= cmd_data_i;
        end
    end

    wire cmd_rise = cmd_valid_s2 & ~cmd_valid_s3;

    logic tamper_s1, tamper_s2;
    initial begin
        tamper_s1 = 1'b0;
        tamper_s2 = 1'b0;
    end
    always @(posedge clk_gate) begin
        tamper_s1 <= tamper_detect_i;
        tamper_s2 <= tamper_s1;
    end

    logic kill_switch_latched;
    initial kill_switch_latched = 1'b0;
    always @(posedge clk_gate) begin
        if (tamper_s2)
            kill_switch_latched <= 1'b1;
    end

    logic [2:0] state_r;
    logic [2:0] next_state;
    logic [2:0] state;
    logic [31:0] timeout_counter;

    assign state = kill_switch_latched ? S_ZEROIZE : state_r;

    wire both_sigs_valid = (sig_ecdsa_valid_i & sig_dilithium_valid_i) | both_valid_i;
    wire timeout_expired = (timeout_counter >= TIMEOUT_CYCLES[31:0]);

    always @(posedge clk_gate or negedge rst_gate_n) begin
        if (!rst_gate_n)
            state_r <= S_IDLE;
        else
            state_r <= next_state;
    end

    always @(*) begin
        next_state = state;
        case (state)
            S_IDLE:         if (cmd_rise)                next_state = S_WAIT_SIG;
            S_WAIT_SIG:     if (timeout_expired)         next_state = S_REFUSE;
                            else if (both_sigs_valid)    next_state = S_WAIT_CONSENT;
            S_WAIT_CONSENT: if (timeout_expired)         next_state = S_REFUSE;
                            else if (external_consent_i) next_state = S_PASS;
            S_PASS:         next_state = S_IDLE;
            S_REFUSE:       next_state = S_IDLE;
            S_ZEROIZE:      next_state = S_ZEROIZE;
            default:        next_state = S_IDLE;
        endcase
    end

    always @(posedge clk_gate or negedge rst_gate_n) begin
        if (!rst_gate_n)
            timeout_counter <= 32'd0;
        else if (state == S_WAIT_SIG || state == S_WAIT_CONSENT)
            timeout_counter <= timeout_counter + 32'd1;
        else
            timeout_counter <= 32'd0;
    end

    always @(posedge clk_gate or negedge rst_gate_n) begin
        if (!rst_gate_n)
            cmd_data_latched <= '0;
        else if (state == S_IDLE && cmd_rise)
            cmd_data_latched <= cmd_data_sync;
    end

    logic [REFUSAL_WIDTH-1:0] refusal_count;
    initial refusal_count = '0;
    always @(posedge clk_gate) begin
        if (kill_switch_latched)
            refusal_count <= '0;
        else if (state == S_REFUSE)
            refusal_count <= refusal_count + 1'b1;
    end

    assign gated_cmd_valid_o = (state == S_PASS);
    assign gated_cmd_data_o  = cmd_data_latched;
    assign refusal_flag_o    = (state == S_REFUSE);
    assign kill_switch_o     = kill_switch_latched;
    assign refusal_count_o   = refusal_count;

    assign debug_state_o   = state;
    assign debug_state_r_o = state_r;

    // Audit
    logic [2:0] state_d;
    logic       tamper_s2_d;

    always @(posedge clk_gate or negedge rst_gate_n) begin
        if (!rst_gate_n) begin
            tamper_s2_d <= 1'b0;
            state_d     <= S_IDLE;
        end else begin
            tamper_s2_d <= tamper_s2;
            state_d     <= state;
        end
    end

    wire tamper_rise = tamper_s2 & ~tamper_s2_d;

    logic        audit_toggle_gate;
    logic [31:0] audit_event_gate;

    initial begin
        audit_toggle_gate = 1'b0;
        audit_event_gate  = 32'd0;
    end

    always @(posedge clk_gate) begin
        if (tamper_rise) begin
            audit_toggle_gate <= ~audit_toggle_gate;
            audit_event_gate  <= EVT_TAMPER;
        end else if (state == S_PASS && state_d != S_PASS) begin
            audit_toggle_gate <= ~audit_toggle_gate;
            audit_event_gate  <= EVT_PASS;
        end else if (state == S_REFUSE && state_d != S_REFUSE) begin
            audit_toggle_gate <= ~audit_toggle_gate;
            audit_event_gate  <= EVT_REFUSE;
        end
    end

    logic        audit_tog_s1, audit_tog_s2, audit_tog_s3;
    logic [31:0] audit_event_sync;
    logic        audit_valid_r;

    always @(posedge clk_audit or negedge rst_audit_n) begin
        if (!rst_audit_n) begin
            audit_tog_s1     <= 1'b0;
            audit_tog_s2     <= 1'b0;
            audit_tog_s3     <= 1'b0;
            audit_event_sync <= 32'd0;
            audit_valid_r    <= 1'b0;
        end else begin
            audit_tog_s1 <= audit_toggle_gate;
            audit_tog_s2 <= audit_tog_s1;
            audit_tog_s3 <= audit_tog_s2;

            audit_valid_r <= 1'b0;
            if ((audit_tog_s2 ^ audit_tog_s3) && (audit_event_gate != 32'd0)) begin
                audit_valid_r    <= 1'b1;
                audit_event_sync <= audit_event_gate;
            end
        end
    end

    assign audit_valid_o = audit_valid_r;
    assign audit_event_o = audit_event_sync;

endmodule
