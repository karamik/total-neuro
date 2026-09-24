`timescale 1ns/1ps
// pq_verifier_mcu.v
// Interface between an isolated MCU (running ECDSA + Dilithium3
// verification via liboqs) and the consent_gate.
//
// Security model:
//   - MCU toggles `verify_toggle_i` when both signatures verify.
//   - MCU toggles `heartbeat_i` periodically.
//     If heartbeats stop for HEARTBEAT_TIMEOUT_CYCLES, the MCU is
//     assumed dead or compromised, and both_valid_o goes low.
//   - both_valid_o is a one-cycle pulse in clk_gate domain.

module pq_verifier_mcu #(
    parameter int HEARTBEAT_TIMEOUT_CYCLES = 100_000
) (
    input  logic clk_gate,
    input  logic rst_gate_n,

    input  logic verify_toggle_i,
    input  logic heartbeat_i,

    output logic both_valid_o,
    output logic verifier_alive_o
);

    // Sync MCU signals into gate domain (3-FF for edge detect)
    logic vt_s1, vt_s2, vt_s3;
    logic hb_s1, hb_s2, hb_s3;

    always @(posedge clk_gate or negedge rst_gate_n) begin
        if (!rst_gate_n) begin
            vt_s1 <= 1'b0; vt_s2 <= 1'b0; vt_s3 <= 1'b0;
            hb_s1 <= 1'b0; hb_s2 <= 1'b0; hb_s3 <= 1'b0;
        end else begin
            vt_s1 <= verify_toggle_i;
            vt_s2 <= vt_s1;
            vt_s3 <= vt_s2;

            hb_s1 <= heartbeat_i;
            hb_s2 <= hb_s1;
            hb_s3 <= hb_s2;
        end
    end

    wire verify_edge    = vt_s2 ^ vt_s3;
    wire heartbeat_edge = hb_s2 ^ hb_s3;

    // Heartbeat watchdog
    logic [$clog2(HEARTBEAT_TIMEOUT_CYCLES+1)-1:0] hb_counter;
    logic verifier_alive_r;

    always @(posedge clk_gate or negedge rst_gate_n) begin
        if (!rst_gate_n) begin
            hb_counter       <= '0;
            verifier_alive_r <= 1'b0;
        end else begin
            if (heartbeat_edge) begin
                hb_counter       <= '0;
                verifier_alive_r <= 1'b1;
            end else if (hb_counter >= HEARTBEAT_TIMEOUT_CYCLES) begin
                verifier_alive_r <= 1'b0;
            end else begin
                hb_counter <= hb_counter + 1'b1;
            end
        end
    end

    assign verifier_alive_o = verifier_alive_r;

    // Verification pulse: verify_edge AND alive
    logic verify_pulse_r;

    always @(posedge clk_gate or negedge rst_gate_n) begin
        if (!rst_gate_n)
            verify_pulse_r <= 1'b0;
        else
            verify_pulse_r <= verify_edge & verifier_alive_r;
    end

    assign both_valid_o = verify_pulse_r;

endmodule
