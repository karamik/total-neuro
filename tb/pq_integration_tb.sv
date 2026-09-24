`timescale 1ns/1ps

module pq_integration_tb;

    localparam int CMD_WIDTH      = 32;
    localparam int REFUSAL_WIDTH  = 8;

    logic clk_main  = 0;
    logic clk_gate  = 0;
    logic clk_audit = 0;

    logic rst_main_n  = 0;
    logic rst_gate_n  = 0;
    logic rst_audit_n = 0;

    logic                  cmd_valid_i = 0;
    logic [CMD_WIDTH-1:0]  cmd_data_i  = 0;

    logic sig_ecdsa_valid_i    = 1'b0;
    logic sig_dilithium_valid_i = 1'b0;

    logic verify_toggle_i = 1'b0;
    logic heartbeat_i     = 1'b0;
    wire  both_valid_w;

    logic external_consent_i = 0;
    logic tamper_detect_i    = 1'b0;

    logic                  gated_cmd_valid_o;
    logic [CMD_WIDTH-1:0]  gated_cmd_data_o;
    logic                  refusal_flag_o;
    logic                  kill_switch_o;
    logic [REFUSAL_WIDTH-1:0] refusal_count_o;
    logic                  audit_valid_o;
    logic [31:0]           audit_event_o;

    wire verifier_alive_w;

    pq_verifier_mcu #(
        .HEARTBEAT_TIMEOUT_CYCLES(2000)
    ) u_mcu (
        .clk_gate(clk_gate),
        .rst_gate_n(rst_gate_n),
        .verify_toggle_i(verify_toggle_i),
        .heartbeat_i(heartbeat_i),
        .both_valid_o(both_valid_w),
        .verifier_alive_o(verifier_alive_w)
    );

    consent_gate #(
        .CMD_WIDTH(CMD_WIDTH),
        .TIMEOUT_CYCLES(200),
        .REFUSAL_WIDTH(REFUSAL_WIDTH)
    ) u_gate (
        .clk_main(clk_main),
        .rst_main_n(rst_main_n),
        .clk_gate(clk_gate),
        .rst_gate_n(rst_gate_n),
        .clk_audit(clk_audit),
        .rst_audit_n(rst_audit_n),
        .cmd_valid_i(cmd_valid_i),
        .cmd_data_i(cmd_data_i),
        .sig_ecdsa_valid_i(sig_ecdsa_valid_i),
        .sig_dilithium_valid_i(sig_dilithium_valid_i),
        .both_valid_i(both_valid_w),
        .external_consent_i(external_consent_i),
        .tamper_detect_i(tamper_detect_i),
        .gated_cmd_valid_o(gated_cmd_valid_o),
        .gated_cmd_data_o(gated_cmd_data_o),
        .refusal_flag_o(refusal_flag_o),
        .kill_switch_o(kill_switch_o),
        .refusal_count_o(refusal_count_o),
        .audit_valid_o(audit_valid_o),
        .audit_event_o(audit_event_o)
    );

    always #5  clk_main  = ~clk_main;
    always #7  clk_gate  = ~clk_gate;
    always #13 clk_audit = ~clk_audit;

    // ---------- Paced helpers (all in gate clock cycles) ----------

    task automatic hb_pulse();
        @(posedge clk_gate);
        heartbeat_i = ~heartbeat_i;
    endtask

    task automatic verify_pulse();
        @(posedge clk_gate);
        verify_toggle_i = ~verify_toggle_i;
    endtask

    // Wait until gate FSM returns to IDLE and settles
    task automatic wait_idle();
        while (u_gate.state !== 3'd0)
            @(posedge clk_gate);
        repeat (5) @(posedge clk_gate);
    endtask

    // Start a command and let the FSM resolve it (either PASS or REFUSE).
    // Returns after FSM is back in IDLE.
    task automatic run_command(input logic [31:0] data);
        wait_idle();
        cmd_data_i = data;
        cmd_valid_i = 1;
        repeat (5) @(posedge clk_gate);
        cmd_valid_i = 0;
        while (u_gate.state !== 3'd0)
            @(posedge clk_gate);
        repeat (5) @(posedge clk_gate);
    endtask

    initial begin
        $dumpfile("sim/pq_integration.vcd");
        $dumpvars(0, pq_integration_tb);

        #200;
        rst_main_n = 1; rst_gate_n = 1; rst_audit_n = 1;
        repeat (10) @(posedge clk_gate);

        // ---------- TEST 1: no MCU -> REFUSE ----------
        $display("[%0t] === TEST 1: no MCU, command -> REFUSE ===", $time);
        run_command(32'hCAFEBABE);
        $display("[%0t]     after TEST1: count=%0d (expect 1)",
                 $time, refusal_count_o);

        // ---------- TEST 2: start MCU heartbeat ----------
        $display("[%0t] === TEST 2: start heartbeat ===", $time);
        repeat (10) hb_pulse();
        repeat (10) @(posedge clk_gate);
        $display("[%0t]     verifier_alive=%0b", $time, verifier_alive_w);
        if (verifier_alive_w !== 1'b1)
            $display("     FAIL: verifier not alive");
        else
            $display("     OK: verifier alive");

        // ---------- TEST 3: MCU alive, no verify -> REFUSE ----------
        $display("[%0t] === TEST 3: MCU alive, no verify -> REFUSE ===", $time);
        // Keep heartbeat alive during the wait
        fork
            begin
                repeat (40) hb_pulse();
            end
            begin
                run_command(32'h11111111);
            end
        join
        $display("[%0t]     after TEST3: count=%0d (expect 2)",
                 $time, refusal_count_o);

        // ---------- TEST 4: full PASS ----------
        $display("[%0t] === TEST 4: heartbeat + verify + consent -> PASS ===", $time);
        wait_idle();
        hb_pulse();
        repeat (3) @(posedge clk_gate);

        // Assert command
        cmd_data_i = 32'hDEADBEEF;
        cmd_valid_i = 1;
        repeat (5) @(posedge clk_gate);
        cmd_valid_i = 0;

        // Give it a few cycles to enter WAIT_SIG
        repeat (5) @(posedge clk_gate);

        // Now verify event from MCU
        verify_pulse();
        repeat (5) @(posedge clk_gate);

        // And human consent
        external_consent_i = 1;
        repeat (8) @(posedge clk_gate);
        external_consent_i = 0;

        // Wait for FSM to settle
        while (u_gate.state !== 3'd0)
            @(posedge clk_gate);
        repeat (5) @(posedge clk_gate);

        $display("[%0t]     after TEST4: count=%0d (expect 2, no new refuse)",
                 $time, refusal_count_o);

        // ---------- TEST 5: tamper ----------
        $display("[%0t] === TEST 5: tamper ===", $time);
        @(posedge clk_gate);
        tamper_detect_i = 1;
        repeat (10) @(posedge clk_gate);
        tamper_detect_i = 0;
        repeat (5) @(posedge clk_gate);
        $display("[%0t]     kill=%0b state=%0d",
                 $time, kill_switch_o, u_gate.state);
        if (kill_switch_o !== 1'b1)
            $display("     FAIL: kill switch not set");
        else
            $display("     OK: kill switch set");
        if (u_gate.state !== 3'd5)
            $display("     FAIL: state not ZEROIZE, got %0d", u_gate.state);
        else
            $display("     OK: ZEROIZE");

        // ---------- TEST 6: command after zeroize blocked ----------
        $display("[%0t] === TEST 6: command after zeroize ===", $time);
        repeat (5) hb_pulse();
        verify_pulse();
        repeat (3) @(posedge clk_gate);
        cmd_data_i = 32'hFEEDFACE;
        cmd_valid_i = 1;
        external_consent_i = 1;
        repeat (8) @(posedge clk_gate);
        cmd_valid_i = 0;
        external_consent_i = 0;
        repeat (15) @(posedge clk_gate);
        if (u_gate.state !== 3'd5)
            $display("     FAIL: state not ZEROIZE, got %0d", u_gate.state);
        else
            $display("     OK: still ZEROIZE");

        $display("[%0t] === Simulation complete ===", $time);
        $finish;
    end

    // ---------- Monitors ----------
    logic gv_d, rf_d, ks_d, bv_d;

    always @(posedge clk_gate) begin
        gv_d <= gated_cmd_valid_o;
        rf_d <= refusal_flag_o;
        ks_d <= kill_switch_o;
        bv_d <= both_valid_w;
    end

    always @(posedge clk_gate) begin
        if (gated_cmd_valid_o && !gv_d)
            $strobe("[%0t] >>> PASS cmd=0x%08X", $time, gated_cmd_data_o);
        if (refusal_flag_o && !rf_d)
            $strobe("[%0t] >>> REFUSE count=%0d", $time, refusal_count_o);
        if (kill_switch_o && !ks_d)
            $strobe("[%0t] >>> KILL SWITCH ACTIVE", $time);
        if (both_valid_w && !bv_d)
            $strobe("[%0t]     MCU both_valid pulse", $time);
    end

endmodule
