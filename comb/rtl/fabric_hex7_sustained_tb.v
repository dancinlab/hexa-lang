// fabric_hex7_sustained_tb.v — 7-router hex region (R=1) sustained
// traffic cycle-accurate sim. degree-6 fabric counterpart to
// fabric_2x2_sustained_tb.v. Real workloads for direct d4-vs-d6
// comparison.
//
// Layout (hex region radius=1, axial coords):
//
//                R3(0,1) ── R6(-1,1)
//               /    \    /    \
//          R1(1,0)── R0(0,0) ── R2(-1,0)
//               \    /    \    /
//                R5(1,-1)── R4(0,-1)
//
// Edges (12 undirected):
//   center: R0↔R1, R0↔R2, R0↔R3, R0↔R4, R0↔R5, R0↔R6   (6)
//   ring:   R1↔R5, R1↔R3, R2↔R6, R2↔R4, R3↔R6, R4↔R5   (6)
//
// Port indices in router_d6: PQ=0, NQ=1, PR=2, NR=3, PS=4, NS=5, LL=6
// Edge port pairs derived from axial vectors (PQ=+q, etc).

`timescale 1ns/1ps

module fabric_hex7_sustained_tb;
    localparam integer W       = 64;
    localparam integer ADDR_W  = 12;
    localparam integer FIFO_LD = 2;
    localparam integer P       = 7;
    localparam integer SIM_CYCLES = 1000;
    localparam integer N_NODES = 7;

    reg clk = 1'b0; reg rst = 1'b1;
    always #5 clk = ~clk;

    // Per-router port buses
    wire [W-1:0] in_data  [0:6][0:6];
    wire         in_valid [0:6][0:6];
    wire         in_ready [0:6][0:6];
    wire [W-1:0] out_data [0:6][0:6];
    wire         out_valid[0:6][0:6];
    wire         out_ready[0:6][0:6];

    // LL injection/sink per node
    reg  [W-1:0] inj_data  [0:6];
    reg          inj_valid [0:6];
    wire         inj_ready [0:6];
    wire [W-1:0] sink_data [0:6];
    wire         sink_valid[0:6];

    genvar gi;
    generate for (gi = 0; gi < 7; gi = gi + 1) begin : g_ll
        assign in_data [gi][6] = inj_data [gi];
        assign in_valid[gi][6] = inj_valid[gi];
        assign inj_ready[gi]   = in_ready[gi][6];
        assign sink_data [gi]  = out_data [gi][6];
        assign sink_valid[gi]  = out_valid[gi][6];
        assign out_ready[gi][6] = 1'b1;
    end endgenerate

    // ── edge macro: bidirectional connection between two ports ────
    // EDGE(a, ao, b, bi, b, bo, a, ai):
    //   a.<ao> out → b.<bi> in,  b.<bo> out → a.<ai> in
    `define EDGE(a, ao, b, bi, bo, ai) \
        assign in_data [b][bi] = out_data [a][ao]; \
        assign in_valid[b][bi] = out_valid[a][ao]; \
        assign out_ready[a][ao] = in_ready[b][bi]; \
        assign in_data [a][ai] = out_data [b][bo]; \
        assign in_valid[a][ai] = out_valid[b][bo]; \
        assign out_ready[b][bo] = in_ready[a][ai];

    // 12 edges (axial-correct):
    //   port indices: PQ=0 NQ=1 PR=2 NR=3 PS=4 NS=5
    //   for edge X↔Y, the port pair is (X's axial direction to Y, Y's axial direction to X)
    //                                            R0  Rx     Rx  R0
    `EDGE(0, /*R0.PQ*/0, 1, /*R1.NQ*/1, /*R1.NQ*/1, /*R0.PQ*/0)  // R0↔R1
    `EDGE(0, /*R0.NQ*/1, 2, /*R2.PQ*/0, /*R2.PQ*/0, /*R0.NQ*/1)  // R0↔R2
    `EDGE(0, /*R0.PR*/2, 3, /*R3.NR*/3, /*R3.NR*/3, /*R0.PR*/2)  // R0↔R3
    `EDGE(0, /*R0.NR*/3, 4, /*R4.PR*/2, /*R4.PR*/2, /*R0.NR*/3)  // R0↔R4
    `EDGE(0, /*R0.PS*/4, 5, /*R5.NS*/5, /*R5.NS*/5, /*R0.PS*/4)  // R0↔R5
    `EDGE(0, /*R0.NS*/5, 6, /*R6.PS*/4, /*R6.PS*/4, /*R0.NS*/5)  // R0↔R6
    // ring edges (R1↔R5: R1.NR→R5; R5.PR→R1)
    `EDGE(1, /*R1.NR*/3, 5, /*R5.PR*/2, /*R5.PR*/2, /*R1.NR*/3)  // R1↔R5
    `EDGE(1, /*R1.NS*/5, 3, /*R3.PS*/4, /*R3.PS*/4, /*R1.NS*/5)  // R1↔R3
    `EDGE(2, /*R2.PR*/2, 6, /*R6.NR*/3, /*R6.NR*/3, /*R2.PR*/2)  // R2↔R6
    `EDGE(2, /*R2.PS*/4, 4, /*R4.NS*/5, /*R4.NS*/5, /*R2.PS*/4)  // R2↔R4
    `EDGE(3, /*R3.NQ*/1, 6, /*R6.PQ*/0, /*R6.PQ*/0, /*R3.NQ*/1)  // R3↔R6
    `EDGE(4, /*R4.PQ*/0, 5, /*R5.NQ*/1, /*R5.NQ*/1, /*R4.PQ*/0)  // R4↔R5

    // ── boundary tie-offs ────────────────────────────────────────
    // R0 has all 6 active (no boundary except LL — already done).
    // For each ring node, list its 3 boundary ports (the 3 unused
    // axial directions out of 6 = those leading outside R=1 region).
    `define BOUNDARY(n, p) \
        assign in_data [n][p] = '0; \
        assign in_valid[n][p] = 1'b0; \
        assign out_ready[n][p] = 1'b1;

    // R1(1,0):  PQ(0), PR(2), PS(4) boundary
    `BOUNDARY(1, 0)  `BOUNDARY(1, 2)  `BOUNDARY(1, 4)
    // R2(-1,0): NQ(1), NR(3), NS(5) boundary
    `BOUNDARY(2, 1)  `BOUNDARY(2, 3)  `BOUNDARY(2, 5)
    // R3(0,1):  PQ(0), PR(2), NS(5) boundary
    `BOUNDARY(3, 0)  `BOUNDARY(3, 2)  `BOUNDARY(3, 5)
    // R4(0,-1): NQ(1), NR(3), PS(4) boundary
    `BOUNDARY(4, 1)  `BOUNDARY(4, 3)  `BOUNDARY(4, 4)
    // R5(1,-1): PQ(0), NR(3), PS(4) boundary
    `BOUNDARY(5, 0)  `BOUNDARY(5, 3)  `BOUNDARY(5, 4)
    // R6(-1,1): NQ(1), PR(2), NS(5) boundary
    `BOUNDARY(6, 1)  `BOUNDARY(6, 2)  `BOUNDARY(6, 5)

    // ── 7 router instances with axial coords ─────────────────────
    router_d6 #(.W(W), .ADDR_W(ADDR_W), .FIFO_LD(FIFO_LD)) R0 (
        .clk(clk), .rst(rst), .in_data(in_data[0]), .in_valid(in_valid[0]), .in_ready(in_ready[0]),
        .out_data(out_data[0]), .out_valid(out_valid[0]), .out_ready(out_ready[0]),
        .my_q(6'sd0), .my_r(6'sd0));
    router_d6 #(.W(W), .ADDR_W(ADDR_W), .FIFO_LD(FIFO_LD)) R1 (
        .clk(clk), .rst(rst), .in_data(in_data[1]), .in_valid(in_valid[1]), .in_ready(in_ready[1]),
        .out_data(out_data[1]), .out_valid(out_valid[1]), .out_ready(out_ready[1]),
        .my_q(6'sd1), .my_r(6'sd0));
    router_d6 #(.W(W), .ADDR_W(ADDR_W), .FIFO_LD(FIFO_LD)) R2 (
        .clk(clk), .rst(rst), .in_data(in_data[2]), .in_valid(in_valid[2]), .in_ready(in_ready[2]),
        .out_data(out_data[2]), .out_valid(out_valid[2]), .out_ready(out_ready[2]),
        .my_q(-6'sd1), .my_r(6'sd0));
    router_d6 #(.W(W), .ADDR_W(ADDR_W), .FIFO_LD(FIFO_LD)) R3 (
        .clk(clk), .rst(rst), .in_data(in_data[3]), .in_valid(in_valid[3]), .in_ready(in_ready[3]),
        .out_data(out_data[3]), .out_valid(out_valid[3]), .out_ready(out_ready[3]),
        .my_q(6'sd0), .my_r(6'sd1));
    router_d6 #(.W(W), .ADDR_W(ADDR_W), .FIFO_LD(FIFO_LD)) R4 (
        .clk(clk), .rst(rst), .in_data(in_data[4]), .in_valid(in_valid[4]), .in_ready(in_ready[4]),
        .out_data(out_data[4]), .out_valid(out_valid[4]), .out_ready(out_ready[4]),
        .my_q(6'sd0), .my_r(-6'sd1));
    router_d6 #(.W(W), .ADDR_W(ADDR_W), .FIFO_LD(FIFO_LD)) R5 (
        .clk(clk), .rst(rst), .in_data(in_data[5]), .in_valid(in_valid[5]), .in_ready(in_ready[5]),
        .out_data(out_data[5]), .out_valid(out_valid[5]), .out_ready(out_ready[5]),
        .my_q(6'sd1), .my_r(-6'sd1));
    router_d6 #(.W(W), .ADDR_W(ADDR_W), .FIFO_LD(FIFO_LD)) R6 (
        .clk(clk), .rst(rst), .in_data(in_data[6]), .in_valid(in_valid[6]), .in_ready(in_ready[6]),
        .out_data(out_data[6]), .out_valid(out_valid[6]), .out_ready(out_ready[6]),
        .my_q(-6'sd1), .my_r(6'sd1));

    // ── packet (dst_q[63:58] || dst_r[57:52] || inject_cycle[51:20] || _[19:0]) ──
    function [W-1:0] mkpkt(input signed [5:0] dq, input signed [5:0] dr, input [31:0] icyc);
        mkpkt = {dq, dr, icyc, 20'h0};
    endfunction
    function signed [5:0] pkt_dq(input [W-1:0] p); pkt_dq = p[W-1 -: 6]; endfunction
    function signed [5:0] pkt_dr(input [W-1:0] p); pkt_dr = p[W-7 -: 6]; endfunction
    function [31:0]      pkt_icyc(input [W-1:0] p); pkt_icyc = p[W-13 -: 32]; endfunction

    // ── node id → axial coord ────────────────────────────────────
    // R0(0,0), R1(1,0), R2(-1,0), R3(0,1), R4(0,-1), R5(1,-1), R6(-1,1)
    function signed [5:0] node_q(input integer n);
        case (n)
            0: node_q = 0;  1: node_q =  1;  2: node_q = -1;
            3: node_q = 0;  4: node_q =  0;  5: node_q =  1;
            6: node_q = -1; default: node_q = 0;
        endcase
    endfunction
    function signed [5:0] node_r(input integer n);
        case (n)
            0: node_r = 0;  1: node_r = 0;  2: node_r = 0;
            3: node_r = 1;  4: node_r = -1; 5: node_r = -1;
            6: node_r = 1;  default: node_r = 0;
        endcase
    endfunction

    // ── PRNG ─────────────────────────────────────────────────────
    reg [31:0] lfsr;
    always @(posedge clk) lfsr <= rst ? 32'hDEADBEEF : {lfsr[30:0], lfsr[31]^lfsr[21]^lfsr[1]^lfsr[0]};

    // ── workload picker ──────────────────────────────────────────
    //   0=uniform: any of 7 nodes (sender allowed; harmless self-pkt)
    //   1=hotspot: everyone sends to R0(center)
    //   2=stencil: send to one immediate neighbor (1..6 if I'm R0, else R0)
    //   3=diameter: send to opposite ring node (1↔2, 3↔4, 5↔6, R0→random)
    reg [7:0] workload;
    task automatic pick_dst(input integer src, output signed [5:0] dq, output signed [5:0] dr);
        integer pick3, opp;
        begin
            case (workload)
                0: begin pick3 = lfsr[2:0] % 7; dq = node_q(pick3); dr = node_r(pick3); end
                1: begin dq = 0; dr = 0; end
                2: begin
                    if (src == 0) begin pick3 = (lfsr[3:1] % 6) + 1;
                        dq = node_q(pick3); dr = node_r(pick3);
                    end else begin dq = 0; dr = 0; end
                end
                3: begin
                    case (src)
                        1: opp = 2; 2: opp = 1; 3: opp = 4; 4: opp = 3;
                        5: opp = 6; 6: opp = 5; default: opp = (lfsr[2:0] % 6) + 1;
                    endcase
                    dq = node_q(opp); dr = node_r(opp);
                end
                default: begin dq = 0; dr = 0; end
            endcase
        end
    endtask

    // ── stats ────────────────────────────────────────────────────
    integer cyc;
    integer pkts_injected, pkts_delivered, latency_sum;
    integer i, ej_cyc;
    reg signed [5:0] dq_tmp, dr_tmp;

    initial begin
        for (i = 0; i < 7; i = i + 1) begin
            inj_data [i] = '0;
            inj_valid[i] = 1'b0;
        end
        cyc = 0;
        $display("=== 7-node hex fabric sustained traffic — degree-6 (router_d6) ===");
        $display("workload     cycles  injected  delivered  drop_rate  avg_lat");

        for (workload = 0; workload < 4; workload = workload + 1) begin
            rst = 1'b1;
            for (i = 0; i < 7; i = i + 1) inj_valid[i] = 1'b0;
            repeat (5) @(negedge clk);
            rst = 1'b0;
            pkts_injected = 0; pkts_delivered = 0; latency_sum = 0;

            for (cyc = 0; cyc < SIM_CYCLES; cyc = cyc + 1) begin
                @(negedge clk);
                for (i = 0; i < 7; i = i + 1) begin
                    if (lfsr[i+4] && inj_ready[i] && !inj_valid[i]) begin
                        pick_dst(i, dq_tmp, dr_tmp);
                        inj_data [i] = mkpkt(dq_tmp, dr_tmp, cyc[31:0]);
                        inj_valid[i] = 1'b1;
                        pkts_injected = pkts_injected + 1;
                    end else if (inj_ready[i]) begin
                        inj_valid[i] = 1'b0;
                    end
                end
                for (i = 0; i < 7; i = i + 1) begin
                    if (sink_valid[i]) begin
                        ej_cyc = pkt_icyc(sink_data[i]);
                        latency_sum = latency_sum + (cyc - ej_cyc);
                        pkts_delivered = pkts_delivered + 1;
                    end
                end
            end
            for (i = 0; i < 7; i = i + 1) inj_valid[i] = 1'b0;
            for (cyc = SIM_CYCLES; cyc < SIM_CYCLES + 50; cyc = cyc + 1) begin
                @(negedge clk);
                for (i = 0; i < 7; i = i + 1) begin
                    if (sink_valid[i]) begin
                        ej_cyc = pkt_icyc(sink_data[i]);
                        latency_sum = latency_sum + (cyc - ej_cyc);
                        pkts_delivered = pkts_delivered + 1;
                    end
                end
            end

            $display("%0d (%s) %8d  %8d   %8d    %0d%%       %0d",
                     workload,
                     (workload==0)?"uniform   ":(workload==1)?"hotspot-C ":
                     (workload==2)?"stencil   ":"diameter  ",
                     SIM_CYCLES, pkts_injected, pkts_delivered,
                     (pkts_injected > 0) ? (100 * (pkts_injected - pkts_delivered) / pkts_injected) : 0,
                     (pkts_delivered > 0) ? (latency_sum / pkts_delivered) : 0);
        end

        $display("=== done ===");
        $finish;
    end
endmodule
