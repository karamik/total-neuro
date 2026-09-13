// ========================================================================
// tb_apollo_kill_switch.sv – тестбенч для Apollo-2 Kill Switch
// Проверяет: arm, триггеры, latch, test_mode
// ========================================================================

`timescale 1ns / 1ps

module tb_apollo_kill_switch;

    localparam CLK_PERIOD = 10;

    logic clk;
    logic rst_n;
    logic zeroize_req;
    logic integrity_fault;
    logic clock_glitch;
    logic global_key;
    logic sovereign_key;
    logic arm;
    logic test_mode;
    logic power_cutoff;
    logic kill_armed;
    logic kill_triggered;

    // DUT
    apollo_kill_switch dut (
        .clk(clk),
        .rst_n(rst_n),
        .zeroize_req(zeroize_req),
        .integrity_fault(integrity_fault),
        .clock_glitch(clock_glitch),
        .global_key(global_key),
        .sovereign_key(sovereign_key),
        .arm(arm),
        .test_mode(test_mode),
        .power_cutoff(power_cutoff),
        .kill_armed(kill_armed),
        .kill_triggered(kill_triggered)
    );

    // Clock
    initial clk = 0;
    always #(CLK_PERIOD/2) clk = ~clk;

    // Reset helper
    task reset_dut();
        rst_n = 0;
        zeroize_req = 0;
        integrity_fault = 0;
        clock_glitch = 0;
        global_key = 0;
        sovereign_key = 0;
        arm = 0;
        test_mode = 0;
        #(CLK_PERIOD * 3);
        rst_n = 1;
        #(CLK_PERIOD * 2);
    endtask


    // ================================================================
    // Main test scenario
    // ================================================================
    initial begin
        $display("=== Apollo-2 Kill Switch Testbench ===");

        // ----------------------------------------------------------
        // Test 1: Default state after reset (should be disarmed)
        // ----------------------------------------------------------
        reset_dut();
        if (!kill_armed && !power_cutoff && !kill_triggered)
            $display("✅ Test 1 PASSED: Default state is disarmed");
        else
            $display("❌ Test 1 FAILED: unexpected state");

        // ----------------------------------------------------------
        // Test 2: Arm protection with both keys valid
        // ----------------------------------------------------------
        global_key = 1;
        sovereign_key = 1;
        arm = 1;
        #(CLK_PERIOD);
        arm = 0;
        #(CLK_PERIOD);
        if (kill_armed && !power_cutoff)
            $display("✅ Test 2 PASSED: Protection armed");
        else
            $display("❌ Test 2 FAILED: arm didn't work");


        // ----------------------------------------------------------
        // Test 3: Trigger via zeroize_req
        // ----------------------------------------------------------
        reset_dut();
        global_key = 1;
        sovereign_key = 1;
        arm = 1;
        #(CLK_PERIOD);
        arm = 0;
        #(CLK_PERIOD);
        zeroize_req = 1;
        #(CLK_PERIOD);
        if (power_cutoff && kill_triggered)
            $display("✅ Test 3 PASSED: zeroize_req triggers cutoff");
        else
            $display("❌ Test 3 FAILED: zeroize didn't trigger");

        // ----------------------------------------------------------
        // Test 4: Trigger via integrity_fault
        // ----------------------------------------------------------
        reset_dut();
        global_key = 1;
        sovereign_key = 1;
        arm = 1;
        #(CLK_PERIOD);
        arm = 0;
        #(CLK_PERIOD);
        integrity_fault = 1;
        #(CLK_PERIOD);
        if (power_cutoff)
            $display("✅ Test 4 PASSED: integrity_fault triggers cutoff");
        else
            $display("❌ Test 4 FAILED: integrity_fault didn't trigger");


        // ----------------------------------------------------------
        // Test 5: Trigger via clock_glitch
        // ----------------------------------------------------------
        reset_dut();
        global_key = 1;
        sovereign_key = 1;
        arm = 1;
        #(CLK_PERIOD);
        arm = 0;
        #(CLK_PERIOD);
        clock_glitch = 1;
        #(CLK_PERIOD);
        if (power_cutoff)
            $display("✅ Test 5 PASSED: clock_glitch triggers cutoff");
        else
            $display("❌ Test 5 FAILED: clock_glitch didn't trigger");

        // ----------------------------------------------------------
        // Test 6: Losing a key triggers cutoff
        // ----------------------------------------------------------
        reset_dut();
        global_key = 1;
        sovereign_key = 1;
        arm = 1;
        #(CLK_PERIOD);
        arm = 0;
        #(CLK_PERIOD);
        sovereign_key = 0;  // key revoked
        #(CLK_PERIOD);
        if (power_cutoff)
            $display("✅ Test 6 PASSED: key loss triggers cutoff");
        else
            $display("❌ Test 6 FAILED: key loss didn't trigger");


        // ----------------------------------------------------------
        // Test 7: No trigger when disarmed (protection off)
        // ----------------------------------------------------------
        reset_dut();
        // arm = 0 (not armed)
        zeroize_req = 1;
        #(CLK_PERIOD * 2);
        if (!power_cutoff)
            $display("✅ Test 7 PASSED: disarmed switch ignores trigger");
        else
            $display("❌ Test 7 FAILED: disarmed switch triggered");

        // ----------------------------------------------------------
        // Test 8: test_mode disables protection
        // ----------------------------------------------------------
        reset_dut();
        test_mode = 1;
        global_key = 1;
        sovereign_key = 1;
        arm = 1;
        #(CLK_PERIOD);
        zeroize_req = 1;
        #(CLK_PERIOD * 2);
        if (!power_cutoff)
            $display("✅ Test 8 PASSED: test_mode disables switch");
        else
            $display("❌ Test 8 FAILED: test_mode didn't disable");

        // ----------------------------------------------------------
        // Test 9: Latch persists after trigger removed
        // ----------------------------------------------------------
        reset_dut();
        global_key = 1;
        sovereign_key = 1;
        arm = 1;
        #(CLK_PERIOD);
        arm = 0;
        #(CLK_PERIOD);
        zeroize_req = 1;
        #(CLK_PERIOD);
        zeroize_req = 0;
        #(CLK_PERIOD * 3);
        if (power_cutoff)
            $display("✅ Test 9 PASSED: cutoff latched after trigger removed");
        else
            $display("❌ Test 9 FAILED: latch didn't persist");

        $display("=== Testbench complete ===");
        #(CLK_PERIOD * 5);
        $finish;
    end

endmodule
