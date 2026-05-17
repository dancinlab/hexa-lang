// router_d6_tb.v — iverilog testbench for router_d6.v
// 2026-05-18 · cycle-accurate functional verification of hex routing.
// Drives 4 destination cases and asserts the packet exits the correct
// axial output port. iverilog-runnable.

`timescale 1ns/1ps

module router_d6_tb;
    localparam integer W       = 64;
    localparam integer ADDR_W  = 12;
    localparam integer FIFO_LD = 2;
    localparam integer P       = 7;     // 6 axial + local

    reg                 clk = 1'b0;
    reg                 rst = 1'b1;
    always #5 clk = ~clk;

    // packed port arrays
    reg  [W-1:0]        in_data  [0:P-1];
    reg                 in_valid [0:P-1];
    wire                in_ready [0:P-1];
    wire [W-1:0]        out_data [0:P-1];
    wire                out_valid[0:P-1];
    reg                 out_ready[0:P-1];

    reg  signed [ADDR_W/2-1:0] my_q = 0;
    reg  signed [ADDR_W/2-1:0] my_r = 0;

    router_d6 #(.W(W), .ADDR_W(ADDR_W), .FIFO_LD(FIFO_LD)) DUT (
        .clk(clk), .rst(rst),
        .in_data(in_data), .in_valid(in_valid), .in_ready(in_ready),
        .out_data(out_data), .out_valid(out_valid), .out_ready(out_ready),
        .my_q(my_q), .my_r(my_r)
    );

    // pack destination into top 12 bits of payload
    function [W-1:0] mkpkt(input signed [5:0] dq, input signed [5:0] dr, input [W-1-12:0] body);
        mkpkt = {dq, dr, body};
    endfunction

    integer i;
    integer pass = 0, fail = 0;
    reg [3:0] expected_port;
    reg [3:0] observed_port;
    reg       saw_valid;

    task inject_and_check(input signed [5:0] dq, input signed [5:0] dr,
                          input [W-13:0] body, input [3:0] expect_port,
                          input [127:0] name);
        begin
            // wait an idle cycle
            @(negedge clk);
            in_data[6]  = mkpkt(dq, dr, body);     // inject on LL (local)
            in_valid[6] = 1'b1;
            @(negedge clk);
            in_valid[6] = 1'b0;
            // wait up to 6 cycles for it to emerge
            saw_valid = 1'b0;
            observed_port = 4'hF;
            for (i = 0; i < 6 && !saw_valid; i = i + 1) begin
                @(negedge clk);
                for (int k = 0; k < P; k = k + 1) begin
                    if (out_valid[k] && !saw_valid) begin
                        observed_port = k[3:0];
                        saw_valid     = 1'b1;
                    end
                end
            end
            if (saw_valid && observed_port == expect_port) begin
                pass = pass + 1;
                $display("PASS %0s: dst=(%0d,%0d) expect_port=%0d observed=%0d",
                         name, dq, dr, expect_port, observed_port);
            end else begin
                fail = fail + 1;
                $display("FAIL %0s: dst=(%0d,%0d) expect_port=%0d observed=%0d saw=%b",
                         name, dq, dr, expect_port, observed_port, saw_valid);
            end
        end
    endtask

    initial begin
        // initialise
        for (i = 0; i < P; i = i + 1) begin
            in_data[i]   = '0;
            in_valid[i]  = 1'b0;
            out_ready[i] = 1'b1;   // sinks always ready
        end
        // reset for 3 cycles
        rst = 1'b1;
        @(negedge clk); @(negedge clk); @(negedge clk);
        rst = 1'b0;
        @(negedge clk);

        // Port index convention (must match router_d6.v):
        //   PQ=0 (+q), NQ=1 (-q), PR=2 (+r), NR=3 (-r), PS=4 (+s), NS=5 (-s), LL=6
        // Hex dim-order chooses max-|Δ| axis, sign decides direction.

        // case 1: dst=(+3,0) → dq=3,dr=0,ds=-3 → |dq|=|ds|=3 (tie; aq>=ar>=as_ false
        //         since aq=as_, but condition `aq>=ar && aq>=as_` is true) → PQ
        inject_and_check(6'sd3,  6'sd0, '0, 4'd0, "dq=3");

        // case 2: dst=(-2,0) → dq=-2,dr=0,ds=2 → aq=as_=2; aq>=ar && aq>=as_ true → NQ
        inject_and_check(-6'sd2, 6'sd0, '0, 4'd1, "dq=-2");

        // case 3: dst=(0,+4) → dq=0,dr=4,ds=-4 → ar=as_=4, aq=0; ar>=aq && ar>=as_ true → PR
        inject_and_check(6'sd0,  6'sd4, '0, 4'd2, "dr=4");

        // case 4: dst=(0,0) → all zero → LL
        inject_and_check(6'sd0,  6'sd0, '0, 4'd6, "local");

        $display("");
        $display("SUMMARY: PASS=%0d FAIL=%0d", pass, fail);
        $finish;
    end
endmodule
