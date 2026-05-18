// fabric_2x2_tb.v — 2x2 mesh fabric testbench (4 router_d4 instances)
// 2026-05-18 · iverilog-runnable. Demonstrates inter-router traffic flow
// through a real multi-router fabric, end-to-end packet traversal with
// cycle-accurate handshaking.
//
// Layout (XY coordinates, router at each grid point):
//
//        (0,1)──E───(1,1)
//          │         │
//          N         N
//          │         │
//        (0,0)──E───(1,0)
//
//   each router has 5 ports: N(+y), S(-y), E(+x), W(-x), LL(local)
//   boundary ports (S of bottom row, W of left col, etc.) sink/null
//
// Injects a packet at (0,0) LL with dst=(1,1); expects it to exit at LL
// of (1,1) after XY routing (E first, then N) — 2 inter-router hops.

`timescale 1ns/1ps

module fabric_2x2_tb;
    localparam integer W       = 64;
    localparam integer ADDR_W  = 8;
    localparam integer FIFO_LD = 2;
    localparam integer P       = 5;   // 4 cardinal + local

    reg clk = 1'b0; reg rst = 1'b1;
    always #5 clk = ~clk;

    // 4 routers' port buses
    wire [W-1:0] in_data  [0:3][0:P-1];
    wire         in_valid [0:3][0:P-1];
    wire         in_ready [0:3][0:P-1];
    wire [W-1:0] out_data [0:3][0:P-1];
    wire         out_valid[0:3][0:P-1];
    wire         out_ready[0:3][0:P-1];

    // mux: each router's input is driven either by an external source
    // (LL only) or by a neighbor's output. We model the inter-router
    // wires as direct assigns and provide LL-injection / LL-sink as the
    // sole testbench-controlled ports.
    //
    //   port idx: N=0, S=1, E=2, W=3, LL=4

    // ── LL-injection drivers (sources) ────────────────────────────
    reg  [W-1:0] inj_data  [0:3];
    reg          inj_valid [0:3];
    wire         inj_ready [0:3];
    // ── LL-sink (sinks always ready) ─────────────────────────────
    wire [W-1:0] sink_data [0:3];
    wire         sink_valid[0:3];

    genvar gi;
    generate for (gi = 0; gi < 4; gi = gi + 1) begin : g_ll
        // LL input = injection
        assign in_data [gi][4] = inj_data [gi];
        assign in_valid[gi][4] = inj_valid[gi];
        assign inj_ready[gi]   = in_ready[gi][4];
        // LL output = sink
        assign sink_data [gi] = out_data [gi][4];
        assign sink_valid[gi] = out_valid[gi][4];
        assign out_ready[gi][4] = 1'b1;     // sink always ready
    end endgenerate

    // ── inter-router wiring (mesh edges) ─────────────────────────
    // router id mapping: r0=(0,0), r1=(1,0), r2=(0,1), r3=(1,1)
    //
    //   r2 -- E --> r3        (E:r2.out → W:r3.in ; W:r3.out → E:r2.in)
    //   |           |
    //   N           N
    //   |           |
    //   r0 -- E --> r1
    //
    // E-direction edge r_left ↔ r_right
    `define HORZ(l, r) \
        assign in_data [r][3] = out_data [l][2]; \
        assign in_valid[r][3] = out_valid[l][2]; \
        assign out_ready[l][2] = in_ready[r][3]; \
        assign in_data [l][2] = out_data [r][3]; \
        assign in_valid[l][2] = out_valid[r][3]; \
        assign out_ready[r][3] = in_ready[l][2];

    `define VERT(b, t) \
        assign in_data [t][1] = out_data [b][0]; \
        assign in_valid[t][1] = out_valid[b][0]; \
        assign out_ready[b][0] = in_ready[t][1]; \
        assign in_data [b][0] = out_data [t][1]; \
        assign in_valid[b][0] = out_valid[t][1]; \
        assign out_ready[t][1] = in_ready[b][0];

    `HORZ(0, 1)   // r0 ↔ r1 (bottom row)
    `HORZ(2, 3)   // r2 ↔ r3 (top row)
    `VERT(0, 2)   // r0 ↔ r2 (left col)
    `VERT(1, 3)   // r1 ↔ r3 (right col)

    // ── boundary tie-offs ─────────────────────────────────────────
    // r0(0,0): S=1 (no -y), W=3 (no -x)
    // r1(1,0): S=1, E=2 → r1's E is boundary? no — wait, r1 is at (1,0)
    //          so it HAS no E neighbor in 2x2 if grid is 2x2 (x=0,1).
    //          So r1.E is boundary. But we used HORZ(0,1) connecting
    //          r0.E ↔ r1.W. r1.E and r0.W are still boundaries.
    // tie boundary in_valid=0, out_ready=1
    assign in_data [0][1] = '0; assign in_valid[0][1] = 1'b0; assign out_ready[0][1] = 1'b1; // r0.S
    assign in_data [0][3] = '0; assign in_valid[0][3] = 1'b0; assign out_ready[0][3] = 1'b1; // r0.W
    assign in_data [1][1] = '0; assign in_valid[1][1] = 1'b0; assign out_ready[1][1] = 1'b1; // r1.S
    assign in_data [1][2] = '0; assign in_valid[1][2] = 1'b0; assign out_ready[1][2] = 1'b1; // r1.E
    assign in_data [2][0] = '0; assign in_valid[2][0] = 1'b0; assign out_ready[2][0] = 1'b1; // r2.N
    assign in_data [2][3] = '0; assign in_valid[2][3] = 1'b0; assign out_ready[2][3] = 1'b1; // r2.W
    assign in_data [3][0] = '0; assign in_valid[3][0] = 1'b0; assign out_ready[3][0] = 1'b1; // r3.N
    assign in_data [3][2] = '0; assign in_valid[3][2] = 1'b0; assign out_ready[3][2] = 1'b1; // r3.E

    // ── 4 router instances ────────────────────────────────────────
    // coords: r0=(0,0) r1=(1,0) r2=(0,1) r3=(1,1)
    router_d4 #(.W(W), .ADDR_W(ADDR_W), .FIFO_LD(FIFO_LD)) R0 (
        .clk(clk), .rst(rst),
        .in_data(in_data[0]), .in_valid(in_valid[0]), .in_ready(in_ready[0]),
        .out_data(out_data[0]), .out_valid(out_valid[0]), .out_ready(out_ready[0]),
        .my_x(4'sd0), .my_y(4'sd0)
    );
    router_d4 #(.W(W), .ADDR_W(ADDR_W), .FIFO_LD(FIFO_LD)) R1 (
        .clk(clk), .rst(rst),
        .in_data(in_data[1]), .in_valid(in_valid[1]), .in_ready(in_ready[1]),
        .out_data(out_data[1]), .out_valid(out_valid[1]), .out_ready(out_ready[1]),
        .my_x(4'sd1), .my_y(4'sd0)
    );
    router_d4 #(.W(W), .ADDR_W(ADDR_W), .FIFO_LD(FIFO_LD)) R2 (
        .clk(clk), .rst(rst),
        .in_data(in_data[2]), .in_valid(in_valid[2]), .in_ready(in_ready[2]),
        .out_data(out_data[2]), .out_valid(out_valid[2]), .out_ready(out_ready[2]),
        .my_x(4'sd0), .my_y(4'sd1)
    );
    router_d4 #(.W(W), .ADDR_W(ADDR_W), .FIFO_LD(FIFO_LD)) R3 (
        .clk(clk), .rst(rst),
        .in_data(in_data[3]), .in_valid(in_valid[3]), .in_ready(in_ready[3]),
        .out_data(out_data[3]), .out_valid(out_valid[3]), .out_ready(out_ready[3]),
        .my_x(4'sd1), .my_y(4'sd1)
    );

    // ── test: inject (0,0) → (1,1) ────────────────────────────────
    function [W-1:0] mkpkt(input signed [3:0] dx, input signed [3:0] dy);
        mkpkt = {dx, dy, 56'h0};
    endfunction

    integer cyc, inject_cyc, deliver_cyc;
    integer i;

    initial begin
        for (i = 0; i < 4; i = i + 1) begin
            inj_data [i] = '0;
            inj_valid[i] = 1'b0;
        end
        cyc = 0;
        inject_cyc  = -1;
        deliver_cyc = -1;
        rst = 1'b1;
        repeat (3) @(negedge clk);
        rst = 1'b0;
        @(negedge clk);

        // inject at R0 (0,0) targeting (1,1)
        inj_data [0] = mkpkt(4'sd1, 4'sd1);
        inj_valid[0] = 1'b1;
        inject_cyc   = cyc;
        @(negedge clk);
        inj_valid[0] = 1'b0;

        // wait for sink at R3
        for (i = 0; i < 60; i = i + 1) begin
            @(negedge clk);
            cyc = cyc + 1;
            if (sink_valid[3] && deliver_cyc < 0) begin
                deliver_cyc = cyc;
                $display("DELIVERED at R3(1,1): cycle=%0d data=0x%016h", cyc, sink_data[3]);
            end
        end

        if (deliver_cyc > 0) begin
            $display("END-TO-END latency: %0d cycles (inject=%0d deliver=%0d, 2-hop expected)",
                     deliver_cyc - inject_cyc, inject_cyc, deliver_cyc);
            $display("RESULT: PASS (multi-router fabric routes correctly)");
        end else begin
            $display("RESULT: FAIL (packet not delivered after 60 cycles)");
        end
        $finish;
    end
endmodule
