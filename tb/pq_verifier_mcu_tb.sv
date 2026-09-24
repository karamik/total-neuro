`timescale 1ns/1ps

module pq_verifier_mcu_tb;

    logic clk_gate = 0;
    logic rst_gate_n = 0;

    logic verify_toggle_i = 0;
    logic heartbeat_i = 0;

    logic both_valid_o;
    logic verifier_alive_o;

    pq_verifier_mcu #(
        .HEARTBEAT_TIMEOUT_CYCLES(50)
    ) dut (.*);

    always #5 clk_gate = ~clk_gate;

    // helper tasks
    task automatic hb_toggle();
        heartbeat_i = ~heartbeat_i;
        #20;
    endtask

    task automatic verify_toggle();
        verify_toggle_i = ~verify_toggle_i;
        #20;
    endtask

    initial begin
        $dumpfile("sim/pq_verifier_mcu.vcd");
        $dumpvars(0, pq_verifier_mcu_tb);

        #50;
        rst_gate_n = 1;
        #20;

        // -------- TEST 1: silent MCU, no heartbeat --------
        $display("[%0t] === TEST 1: no heartbeat, must be dead ===", $time);
        #200;
        if (verifier_alive_o !== 1'b0)
            $display("FAIL: verifier_alive should be 0, got %0b", verifier_alive_o);
        else
            $display("OK: verifier_alive=0");

        // -------- TEST 2: heartbeat, verifier comes alive --------
        $display("[%0t] === TEST 2: heartbeat starts ===", $time);
        for (int i = 0; i < 5; i++)
            hb_toggle();
        if (verifier_alive_o !== 1'b1)
            $display("FAIL: verifier_alive should be 1, got %0b", verifier_alive_o);
        else
            $display("OK: verifier_alive=1");

        // -------- TEST 3: verify_toggle while alive -> pulse --------
        $display("[%0t] === TEST 3: verify while alive ===", $time);
        hb_toggle();
        verify_toggle();
        #50;
        // both_valid_o is one-cycle, hard to catch in $display.
        // Use monitor below.

        // -------- TEST 4: verify_toggle while NOT alive -> no pulse --------
        $display("[%0t] === TEST 4: stop heartbeat, wait for timeout ===", $time);
        #1500;  // no heartbeat -> timeout -> alive=0
        if (verifier_alive_o !== 1'b0)
            $display("FAIL: verifier_alive should be 0, got %0b", verifier_alive_o);
        else
            $display("OK: verifier_alive=0 after timeout");

        $display("[%0t] === TEST 5: verify while dead -> no pulse ===", $time);
        verify_toggle();
        #50;
        // Monitor should show NO both_valid_o pulse.

        // -------- TEST 6: heartbeat resumes, verify passes --------
        $display("[%0t] === TEST 6: heartbeat resumes ===", $time);
        for (int i = 0; i < 5; i++)
            hb_toggle();
        verify_toggle();
        #50;

        #200;
        $display("[%0t] === Simulation complete ===", $time);
        $finish;
    end

    // Pulse monitor
    always @(posedge clk_gate) begin
        if (both_valid_o)
            $display("[%0t] >>> BOTH_VALID pulse", $time);
    end

endmodule
