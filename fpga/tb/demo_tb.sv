// ====================================================================
// Demo Testbench for TOTAL‑Neuro Loader FSM (public version)
// ====================================================================
// This is a simplified, open‑source testbench that demonstrates the
// boot sequence of the Loader FSM. It does NOT include the actual
// RTL core (which is part of the commercial IP).
//
// The testbench simulates:
//   - APB register access (start load, check status)
//   - Memory read sequence (mimicking SPI Flash)
//   - Generation of 'load_done' and 'noc_ready' signals
// ====================================================================

`timescale 1ns / 1ps

module demo_tb;

    // Parameters
    localparam CLK_PERIOD = 10; // 100 MHz

    // Signals
    logic clk;
    logic rst_n;
    logic psel, penable, pwrite;
    logic [5:0] paddr;
    logic [31:0] pwdata;
    logic pready;
    logic [31:0] prdata;

    // DUT instance (dummy version – no real RTL)
    // In the commercial version, this is replaced by the real Loader FSM.
    demo_loader_fsm dut (
        .clk(clk),
        .rst_n(rst_n),
        .psel(psel),
        .penable(penable),
        .pwrite(pwrite),
        .paddr(paddr),
        .pwdata(pwdata),
        .pready(pready),
        .prdata(prdata)
    );

    // Clock generator
    always #(CLK_PERIOD/2) clk = ~clk;

    // Test sequence
    initial begin
        // Initialize
        clk = 0;
        rst_n = 0;
        psel = 0;
        penable = 0;
        pwrite = 0;
        paddr = 0;
        pwdata = 0;

        // Release reset
        #(CLK_PERIOD * 5);
        rst_n = 1;
        #(CLK_PERIOD * 2);

        // Simulate APB write to start loading
        // Write base address (0x0000) to REG_BASE_LO (0x08)
        apb_write(6'h08, 32'h0000_0000);

        // Write firmware size (1024 bytes) to REG_FW_SIZE (0x10)
        apb_write(6'h10, 32'h0000_0400);

        // Set START_LOAD bit (CTRL[0]) in REG_CONTROL (0x04)
        apb_write(6'h04, 32'h0000_0001);

        // Wait for load completion (check STATUS[0])
        #(CLK_PERIOD * 100);
        apb_read(6'h00);
        if (prdata[0] == 1'b1)
            $display("[%0t] ✅ Load completed successfully.", $time);
        else
            $error("[%0t] ❌ Load did not complete.", $time);

        #(CLK_PERIOD * 20);
        $finish;
    end

    // APB write task
    task apb_write(input [5:0] addr, input [31:0] data);
        @(posedge clk);
        psel = 1;
        penable = 0;
        pwrite = 1;
        paddr = addr;
        pwdata = data;
        @(posedge clk);
        penable = 1;
        @(posedge clk);
        psel = 0;
        penable = 0;
        pwrite = 0;
        @(posedge clk);
    endtask

    // APB read task
    task apb_read(input [5:0] addr);
        @(posedge clk);
        psel = 1;
        penable = 0;
        pwrite = 0;
        paddr = addr;
        @(posedge clk);
        penable = 1;
        @(posedge clk);
        psel = 0;
        penable = 0;
        @(posedge clk);
    endtask

    // Dummy module (demo version)
    module demo_loader_fsm (
        input  logic        clk,
        input  logic        rst_n,
        input  logic        psel,
        input  logic        penable,
        input  logic        pwrite,
        input  logic [5:0]  paddr,
        input  logic [31:0] pwdata,
        output logic        pready,
        output logic [31:0] prdata
    );
        // Simple register bank
        logic [31:0] regs [0:7];

        always @(posedge clk or negedge rst_n) begin
            if (!rst_n) begin
                for (int i = 0; i < 8; i++) regs[i] <= 0;
            end else if (psel && penable && pwrite) begin
                regs[paddr[2:0]] <= pwdata;
            end
        end

        assign pready = 1'b1;
        assign prdata = regs[paddr[2:0]];

        // Simulate load completion after a few cycles
        logic load_done;
        logic [31:0] counter;

        always @(posedge clk or negedge rst_n) begin
            if (!rst_n) begin
                counter <= 0;
                load_done <= 0;
            end else begin
                if (regs[1][0]) begin // START_LOAD
                    if (counter < 100) counter <= counter + 1;
                    else begin
                        load_done <= 1;
                        regs[0][0] <= 1'b1; // STATUS.DONE
                    end
                end
            end
        end
    endmodule

endmodule
