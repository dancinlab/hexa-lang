// fabric_mesh7_sustained_tb.v — 7-router d4 mesh on a 3x3-minus-2-corners
// layout, sustained traffic. Same N=7 as fabric_hex7_sustained_tb.v for
// fair F1 comparison.
//
// Layout (XY coords):
//
//   (0,1) ── (1,1) ── (2,1)        node id : coord
//     │       │        │             0     : (0,1)
//   (0,0) ── (1,0) ── (2,0)          1     : (1,1)
//             │                       2     : (2,1)
//          (1,-1)                     3     : (0,0)
//                                     4     : (1,0)   <- central, 4 active nbrs
//                                     5     : (2,0)
//                                     6     : (1,-1)
//
// 8 edges (undirected); 12 boundary-port tie-offs.
// router_d4 ports: N=0, S=1, E=2, W=3, LL=4.

`timescale 1ns/1ps

module fabric_mesh7_sustained_tb;
    localparam integer W       = 64;
    localparam integer ADDR_W  = 8;
    localparam integer FIFO_LD = 2;
    localparam integer P       = 5;
    localparam integer SIM_CYCLES = 1000;
    localparam integer N_NODES = 7;

    reg clk = 1'b0; reg rst = 1'b1;
    always #5 clk = ~clk;

    wire [W-1:0] in_data  [0:6][0:4];
    wire         in_valid [0:6][0:4];
    wire         in_ready [0:6][0:4];
    wire [W-1:0] out_data [0:6][0:4];
    wire         out_valid[0:6][0:4];
    wire         out_ready[0:6][0:4];

    reg  [W-1:0] inj_data  [0:6];
    reg          inj_valid [0:6];
    wire         inj_ready [0:6];
    wire [W-1:0] sink_data [0:6];
    wire         sink_valid[0:6];

    genvar gi;
    generate for (gi = 0; gi < 7; gi = gi + 1) begin : g_ll
        assign in_data [gi][4] = inj_data [gi];
        assign in_valid[gi][4] = inj_valid[gi];
        assign inj_ready[gi]   = in_ready[gi][4];
        assign sink_data [gi]  = out_data [gi][4];
        assign sink_valid[gi]  = out_valid[gi][4];
        assign out_ready[gi][4] = 1'b1;
    end endgenerate

    // ── edge macro: A's port `ao` ↔ B's port `bi` (one direction's
    //    out on A → in on B), plus reverse (B's `bo` → A's `ai`).
    `define EDGE(a, ao, b, bi, bo, ai) \
        assign in_data [b][bi] = out_data [a][ao]; \
        assign in_valid[b][bi] = out_valid[a][ao]; \
        assign out_ready[a][ao] = in_ready[b][bi]; \
        assign in_data [a][ai] = out_data [b][bo]; \
        assign in_valid[a][ai] = out_valid[b][bo]; \
        assign out_ready[b][bo] = in_ready[a][ai];

    // 8 edges. router_d4 ports: N=0, S=1, E=2, W=3.
    `EDGE(0, /*E*/2, 1, /*W*/3, /*W*/3, /*E*/2)   // (0,1)↔(1,1)
    `EDGE(1, /*E*/2, 2, /*W*/3, /*W*/3, /*E*/2)   // (1,1)↔(2,1)
    `EDGE(0, /*S*/1, 3, /*N*/0, /*N*/0, /*S*/1)   // (0,1)↔(0,0)
    `EDGE(1, /*S*/1, 4, /*N*/0, /*N*/0, /*S*/1)   // (1,1)↔(1,0)
    `EDGE(2, /*S*/1, 5, /*N*/0, /*N*/0, /*S*/1)   // (2,1)↔(2,0)
    `EDGE(3, /*E*/2, 4, /*W*/3, /*W*/3, /*E*/2)   // (0,0)↔(1,0)
    `EDGE(4, /*E*/2, 5, /*W*/3, /*W*/3, /*E*/2)   // (1,0)↔(2,0)
    `EDGE(4, /*S*/1, 6, /*N*/0, /*N*/0, /*S*/1)   // (1,0)↔(1,-1)

    // boundary tie-offs (port-index ports listed):
    //   node 0 (0,1):  N(0), W(3) boundary
    //   node 1 (1,1):  N(0)        boundary
    //   node 2 (2,1):  N(0), E(2) boundary
    //   node 3 (0,0):  W(3), S(1) boundary
    //   node 4 (1,0):  all 4 active — no boundary except LL (already done)
    //   node 5 (2,0):  E(2), S(1) boundary
    //   node 6 (1,-1): W(3), E(2), S(1) boundary
    `define BOUNDARY(n, p) \
        assign in_data [n][p] = '0; \
        assign in_valid[n][p] = 1'b0; \
        assign out_ready[n][p] = 1'b1;

    `BOUNDARY(0, 0)  `BOUNDARY(0, 3)
    `BOUNDARY(1, 0)
    `BOUNDARY(2, 0)  `BOUNDARY(2, 2)
    `BOUNDARY(3, 3)  `BOUNDARY(3, 1)
    `BOUNDARY(5, 2)  `BOUNDARY(5, 1)
    `BOUNDARY(6, 3)  `BOUNDARY(6, 2)  `BOUNDARY(6, 1)

    // 7 router instances with XY coords
    router_d4 #(.W(W), .ADDR_W(ADDR_W), .FIFO_LD(FIFO_LD)) R0 (
        .clk(clk), .rst(rst), .in_data(in_data[0]), .in_valid(in_valid[0]), .in_ready(in_ready[0]),
        .out_data(out_data[0]), .out_valid(out_valid[0]), .out_ready(out_ready[0]),
        .my_x(4'sd0), .my_y(4'sd1));
    router_d4 #(.W(W), .ADDR_W(ADDR_W), .FIFO_LD(FIFO_LD)) R1 (
        .clk(clk), .rst(rst), .in_data(in_data[1]), .in_valid(in_valid[1]), .in_ready(in_ready[1]),
        .out_data(out_data[1]), .out_valid(out_valid[1]), .out_ready(out_ready[1]),
        .my_x(4'sd1), .my_y(4'sd1));
    router_d4 #(.W(W), .ADDR_W(ADDR_W), .FIFO_LD(FIFO_LD)) R2 (
        .clk(clk), .rst(rst), .in_data(in_data[2]), .in_valid(in_valid[2]), .in_ready(in_ready[2]),
        .out_data(out_data[2]), .out_valid(out_valid[2]), .out_ready(out_ready[2]),
        .my_x(4'sd2), .my_y(4'sd1));
    router_d4 #(.W(W), .ADDR_W(ADDR_W), .FIFO_LD(FIFO_LD)) R3 (
        .clk(clk), .rst(rst), .in_data(in_data[3]), .in_valid(in_valid[3]), .in_ready(in_ready[3]),
        .out_data(out_data[3]), .out_valid(out_valid[3]), .out_ready(out_ready[3]),
        .my_x(4'sd0), .my_y(4'sd0));
    router_d4 #(.W(W), .ADDR_W(ADDR_W), .FIFO_LD(FIFO_LD)) R4 (
        .clk(clk), .rst(rst), .in_data(in_data[4]), .in_valid(in_valid[4]), .in_ready(in_ready[4]),
        .out_data(out_data[4]), .out_valid(out_valid[4]), .out_ready(out_ready[4]),
        .my_x(4'sd1), .my_y(4'sd0));
    router_d4 #(.W(W), .ADDR_W(ADDR_W), .FIFO_LD(FIFO_LD)) R5 (
        .clk(clk), .rst(rst), .in_data(in_data[5]), .in_valid(in_valid[5]), .in_ready(in_ready[5]),
        .out_data(out_data[5]), .out_valid(out_valid[5]), .out_ready(out_ready[5]),
        .my_x(4'sd2), .my_y(4'sd0));
    router_d4 #(.W(W), .ADDR_W(ADDR_W), .FIFO_LD(FIFO_LD)) R6 (
        .clk(clk), .rst(rst), .in_data(in_data[6]), .in_valid(in_valid[6]), .in_ready(in_ready[6]),
        .out_data(out_data[6]), .out_valid(out_valid[6]), .out_ready(out_ready[6]),
        .my_x(4'sd1), .my_y(-4'sd1));

    function [W-1:0] mkpkt(input signed [3:0] dx, input signed [3:0] dy, input [31:0] icyc);
        mkpkt = {dx, dy, 24'h0, icyc};
    endfunction
    function signed [3:0] pkt_dx(input [W-1:0] p); pkt_dx = p[W-1 -: 4]; endfunction
    function signed [3:0] pkt_dy(input [W-1:0] p); pkt_dy = p[W-5 -: 4]; endfunction
    function [31:0]      pkt_icyc(input [W-1:0] p); pkt_icyc = p[31:0]; endfunction

    function signed [3:0] node_x(input integer n);
        case (n)
            0: node_x = 0; 1: node_x = 1; 2: node_x = 2;
            3: node_x = 0; 4: node_x = 1; 5: node_x = 2;
            6: node_x = 1; default: node_x = 0;
        endcase
    endfunction
    function signed [3:0] node_y(input integer n);
        case (n)
            0: node_y = 1; 1: node_y = 1; 2: node_y = 1;
            3: node_y = 0; 4: node_y = 0; 5: node_y = 0;
            6: node_y = -1; default: node_y = 0;
        endcase
    endfunction

    reg [31:0] lfsr;
    always @(posedge clk) lfsr <= rst ? 32'hCAFEBABE : {lfsr[30:0], lfsr[31]^lfsr[21]^lfsr[1]^lfsr[0]};

    reg [7:0] workload;
    task automatic pick_dst(input integer src, output signed [3:0] dx, output signed [3:0] dy);
        integer pick, far;
        begin
            case (workload)
                0: begin pick = lfsr[2:0] % 7; dx = node_x(pick); dy = node_y(pick); end  // uniform
                1: begin dx = node_x(4); dy = node_y(4); end                              // hotspot-center
                2: begin
                    // stencil: nearest neighbor of src
                    case (src)
                        0: begin pick = (lfsr[0]) ? 1 : 3; end  // (0,1) → (1,1) or (0,0)
                        1: begin pick = (lfsr[1:0] % 3); if(pick==0) pick=0; else if(pick==1) pick=2; else pick=4; end
                        2: begin pick = (lfsr[0]) ? 1 : 5; end
                        3: begin pick = (lfsr[0]) ? 0 : 4; end
                        4: begin pick = lfsr[1:0]; case(pick) 0:pick=1; 1:pick=3; 2:pick=5; default:pick=6; endcase end
                        5: begin pick = (lfsr[0]) ? 2 : 4; end
                        6: begin pick = 4; end
                        default: pick = 4;
                    endcase
                    dx = node_x(pick); dy = node_y(pick);
                end
                3: begin
                    // diameter: each src → (src + 3) mod 7 (far-ish, deterministic)
                    far = (src + 3) % 7;
                    dx = node_x(far); dy = node_y(far);
                end
                default: begin dx = 0; dy = 0; end
            endcase
        end
    endtask

    integer cyc;
    integer pkts_injected, pkts_delivered, latency_sum;
    integer i, ej_cyc;
    reg signed [3:0] dx_tmp, dy_tmp;

    initial begin
        for (i = 0; i < 7; i = i + 1) begin
            inj_data [i] = '0;
            inj_valid[i] = 1'b0;
        end
        $display("=== 7-node mesh fabric sustained traffic — degree-4 (router_d4) — SAME-N vs hex7 ===");
        $display("workload     cycles  injected  delivered  in_flight  avg_lat");

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
                        pick_dst(i, dx_tmp, dy_tmp);
                        inj_data [i] = mkpkt(dx_tmp, dy_tmp, cyc[31:0]);
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
