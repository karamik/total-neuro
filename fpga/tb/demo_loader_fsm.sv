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
                regs[paddr[3:2]] <= pwdata;
            end
        end

        assign pready = 1'b1;
        assign prdata = regs[paddr[3:2]];

        // Simulate load completion after a few cycles
        logic load_done;
        logic [31:0] counter;

        always @(posedge clk or negedge rst_n) begin
            if (!rst_n) begin
                counter <= 0;
                load_done <= 0;
            end else begin
                if (regs[1][0]) begin
                    if (counter < 100) counter <= counter + 1;
                    else begin
                        load_done <= 1;
                        regs[0][0] <= 1'b1; // STATUS.DONE
                    end
                end
            end
        end
    endmodule
