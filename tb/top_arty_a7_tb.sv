`timescale 1ns/1ps

module top_arty_a7_tb;

    logic       clk100 = 0;
    logic [3:0] btn    = 4'b0010;  // btn[1]=1, reset pressed at start
    logic [3:0] sw     = 4'b0000;
    logic [3:0] led;
    logic       rgb_r, rgb_g, rgb_b;

    top_arty_a7 dut (.*);

    always #5 clk100 = ~clk100;  // 100 MHz

    initial begin
        $dumpfile("sim/top_arty_a7.vcd");
        $dumpvars(0, top_arty_a7_tb);

        #200;
        btn[1] = 0;  // release reset
        #100;

        // -------- TEST 1: PASS --------
        $display("[%0t] === TEST 1: PASS ===", $time);
        sw[1] = 1;  // ecdsa
        sw[2] = 1;  // dilithium
        #50;
        sw[0] = 1;  // consent
        sw[3] = 1;  // cmd
        #300;
        sw[3] = 0;
        #100;
        $display("[%0t] led=%b rgb=%b%b%b count=%0d",
                 $time, led, rgb_r, rgb_g, rgb_b, dut.refusal_count);
        sw[0] = 0; sw[1] = 0; sw[2] = 0;
        #1000;

        // -------- TEST 2: REFUSE (no consent) --------
        $display("[%0t] === TEST 2: REFUSE no consent ===", $time);
        sw[1] = 1; sw[2] = 1;
        #50;
        sw[3] = 1;  // cmd, but no consent
        #300;
        sw[3] = 0;
        #500;
        $display("[%0t] led=%b rgb=%b%b%b count=%0d (expected 1)",
                 $time, led, rgb_r, rgb_g, rgb_b, dut.refusal_count);
        sw[1] = 0; sw[2] = 0;
        #500;

        // -------- TEST 3: reset pulse, counter must persist --------
        $display("[%0t] === TEST 3: reset pulse ===", $time);
        btn[1] = 1;
        #100;
        btn[1] = 0;
        #200;
        $display("[%0t] after reset: count=%0d (expected 1)",
                 $time, dut.refusal_count);

        // -------- TEST 4: TAMPER + RESET --------
        $display("[%0t] === TEST 4: TAMPER + RESET ===", $time);
        btn[0] = 1;   // tamper
        btn[1] = 1;   // reset at same time
        #100;
        btn[1] = 0;   // release reset, tamper still held
        #100;
        btn[0] = 0;   // release tamper
        #200;
        $display("[%0t] kill=%0b state=%0d count=%0d",
                 $time, dut.kill_switch, dut.u_gate.state, dut.refusal_count);
        if (dut.kill_switch !== 1'b1)
            $display("FAIL: kill switch not set");
        else
            $display("OK: kill switch latched");
        if (dut.u_gate.state !== 3'd5)
            $display("FAIL: state not ZEROIZE (got %0d)", dut.u_gate.state);
        else
            $display("OK: state is ZEROIZE");
        if (dut.refusal_count !== '0)
            $display("FAIL: refusal_count not cleared");
        else
            $display("OK: refusal_count cleared");

        // -------- TEST 5: command after zeroize --------
        $display("[%0t] === TEST 5: cmd after zeroize ===", $time);
        sw[0] = 1; sw[1] = 1; sw[2] = 1; sw[3] = 1;
        #300;
        sw[3] = 0;
        #200;
        if (dut.u_gate.state !== 3'd5)
            $display("FAIL: state changed from ZEROIZE (got %0d)", dut.u_gate.state);
        else
            $display("OK: state still ZEROIZE");

        // -------- TEST 6: second reset after zeroize --------
        $display("[%0t] === TEST 6: second reset ===", $time);
        btn[1] = 1;
        #200;
        btn[1] = 0;
        #200;
        $display("[%0t] kill=%0b state=%0d",
                 $time, dut.kill_switch, dut.u_gate.state);
        if (dut.u_gate.state !== 3'd5)
            $display("FAIL: reset revived FSM (state=%0d)", dut.u_gate.state);
        else
            $display("OK: FSM remains ZEROIZE");

        $display("[%0t] === Simulation complete ===", $time);
        $finish;
    end

endmodule
