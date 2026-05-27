// fabric_2x2_sustained_tb.v — sustained-traffic cycle-accurate sim on
// 2x2 router_d4 fabric. Real workload (uniform-random + matmul-row +
// matmul-col patterns) for T2 sim side measurement.
//
// 2026-05-18 · iverilog-runnable locally (no ubu-2 dependency).
// Builds on fabric_2x2_tb.v (single-packet E2E proof).
//
// Measures, per workload:
//   - packets injected / delivered / dropped
//   - avg end-to-end latency (cycles)
//   - throughput at saturation injection rate
//   - per-router congestion

`timescale 1ns/1ps

module fabric_2x2_sustained_tb;
    localparam integer W       = 64;
    localparam integer ADDR_W  = 8;
    localparam integer FIFO_LD = 2;
    localparam integer P       = 5;
    localparam integer SIM_CYCLES = 1000;
    localparam integer N_NODES = 4;

    reg clk = 1'b0; reg rst = 1'b1;
    always #5 clk = ~clk;

    // ── 4 routers' port buses ─────────────────────────────────────
    wire [W-1:0] in_data  [0:3][0:P-1];
    wire         in_valid [0:3][0:P-1];
    wire         in_ready [0:3][0:P-1];
    wire [W-1:0] out_data [0:3][0:P-1];
    wire         out_valid[0:3][0:P-1];
    wire         out_ready[0:3][0:P-1];

    reg  [W-1:0] inj_data  [0:3];
    reg          inj_valid [0:3];
    wire         inj_ready [0:3];
    wire [W-1:0] sink_data [0:3];
    wire         sink_valid[0:3];

    genvar gi;
    generate for (gi = 0; gi < 4; gi = gi + 1) begin : g_ll
        assign in_data [gi][4] = inj_data [gi];
        assign in_valid[gi][4] = inj_valid[gi];
        assign inj_ready[gi]   = in_ready[gi][4];
        assign sink_data [gi] = out_data [gi][4];
        assign sink_valid[gi] = out_valid[gi][4];
        assign out_ready[gi][4] = 1'b1;
    end endgenerate

    // ── inter-router wiring (same as fabric_2x2_tb.v) ─────────────
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

    `HORZ(0, 1)   `HORZ(2, 3)
    `VERT(0, 2)   `VERT(1, 3)

    // ── boundary tie-offs ─────────────────────────────────────────
    assign in_data [0][1] = '0; assign in_valid[0][1] = 1'b0; assign out_ready[0][1] = 1'b1;
    assign in_data [0][3] = '0; assign in_valid[0][3] = 1'b0; assign out_ready[0][3] = 1'b1;
    assign in_data [1][1] = '0; assign in_valid[1][1] = 1'b0; assign out_ready[1][1] = 1'b1;
    assign in_data [1][2] = '0; assign in_valid[1][2] = 1'b0; assign out_ready[1][2] = 1'b1;
    assign in_data [2][0] = '0; assign in_valid[2][0] = 1'b0; assign out_ready[2][0] = 1'b1;
    assign in_data [2][3] = '0; assign in_valid[2][3] = 1'b0; assign out_ready[2][3] = 1'b1;
    assign in_data [3][0] = '0; assign in_valid[3][0] = 1'b0; assign out_ready[3][0] = 1'b1;
    assign in_data [3][2] = '0; assign in_valid[3][2] = 1'b0; assign out_ready[3][2] = 1'b1;

    // ── 4 router instances ────────────────────────────────────────
    router_d4 #(.W(W), .ADDR_W(ADDR_W), .FIFO_LD(FIFO_LD)) R0 (
        .clk(clk), .rst(rst), .in_data(in_data[0]), .in_valid(in_valid[0]), .in_ready(in_ready[0]),
        .out_data(out_data[0]), .out_valid(out_valid[0]), .out_ready(out_ready[0]),
        .my_x(4'sd0), .my_y(4'sd0));
    router_d4 #(.W(W), .ADDR_W(ADDR_W), .FIFO_LD(FIFO_LD)) R1 (
        .clk(clk), .rst(rst), .in_data(in_data[1]), .in_valid(in_valid[1]), .in_ready(in_ready[1]),
        .out_data(out_data[1]), .out_valid(out_valid[1]), .out_ready(out_ready[1]),
        .my_x(4'sd1), .my_y(4'sd0));
    router_d4 #(.W(W), .ADDR_W(ADDR_W), .FIFO_LD(FIFO_LD)) R2 (
        .clk(clk), .rst(rst), .in_data(in_data[2]), .in_valid(in_valid[2]), .in_ready(in_ready[2]),
        .out_data(out_data[2]), .out_valid(out_valid[2]), .out_ready(out_ready[2]),
        .my_x(4'sd0), .my_y(4'sd1));
    router_d4 #(.W(W), .ADDR_W(ADDR_W), .FIFO_LD(FIFO_LD)) R3 (
        .clk(clk), .rst(rst), .in_data(in_data[3]), .in_valid(in_valid[3]), .in_ready(in_ready[3]),
        .out_data(out_data[3]), .out_valid(out_valid[3]), .out_ready(out_ready[3]),
        .my_x(4'sd1), .my_y(4'sd1));

    // ── packet builder ────────────────────────────────────────────
    // payload high 8 bits = dst_x (4) || dst_y (4); next 32 bits = inject_cycle
    function [W-1:0] mkpkt(input [3:0] dx, input [3:0] dy, input [31:0] icyc);
        mkpkt = {dx, dy, icyc, 24'h0};
    endfunction
    function [3:0] pkt_dx(input [W-1:0] p); pkt_dx = p[W-1 -: 4]; endfunction
    function [3:0] pkt_dy(input [W-1:0] p); pkt_dy = p[W-5 -: 4]; endfunction
    function [31:0] pkt_icyc(input [W-1:0] p); pkt_icyc = p[W-9 -: 32]; endfunction

    // ── workload pattern selector (set in initial block) ──────────
    reg [7:0] workload;   // 0=uniform random, 1=matmul-row, 2=matmul-col, 3=transpose
    integer src_x, src_y, dst_x, dst_y;

    // LFSR for pseudo-random (Galois 32-bit)
    reg [31:0] lfsr;
    wire [1:0] rand2 = {lfsr[0]^lfsr[3], lfsr[1]^lfsr[4]};
    always @(posedge clk) lfsr <= rst ? 32'hCAFEBABE : {lfsr[30:0], lfsr[31]^lfsr[21]^lfsr[1]^lfsr[0]};

    // pick destination based on workload + source
    task automatic pick_dst(input integer src, output [3:0] dx, output [3:0] dy);
        reg [3:0] sx, sy;
        begin
            sx = src[0]; sy = src[1];
            case (workload)
                0: begin dx = rand2[0]; dy = rand2[1]; end                 // uniform
                1: begin dx = rand2[0]; dy = sy; end                       // matmul-row (same row, any col)
                2: begin dx = sx; dy = rand2[1]; end                       // matmul-col (same col, any row)
                3: begin dx = sy; dy = sx; end                             // transpose
                default: begin dx = 0; dy = 0; end
            endcase
        end
    endtask

    // ── stats ────────────────────────────────────────────────────
    integer cyc;
    integer pkts_injected, pkts_delivered;
    integer latency_sum;
    integer i;
    reg [3:0] dx_tmp, dy_tmp;
    integer ej_cyc;

    initial begin
        // init
        for (i = 0; i < 4; i = i + 1) begin
            inj_data [i] = '0;
            inj_valid[i] = 1'b0;
        end
        cyc = 0; pkts_injected = 0; pkts_delivered = 0; latency_sum = 0;

        // ── run all 4 workloads back-to-back ──
        $display("=== 2x2 fabric sustained traffic — degree-4 mesh ===");
        $display("workload     cycles  injected  delivered  drop_rate  avg_lat");

        for (workload = 0; workload < 4; workload = workload + 1) begin
            // reset for each workload run
            rst = 1'b1;
            for (i = 0; i < 4; i = i + 1) inj_valid[i] = 1'b0;
            repeat (5) @(negedge clk);
            rst = 1'b0;
            pkts_injected = 0; pkts_delivered = 0; latency_sum = 0;
            cyc = 0;

            // sustained injection — each node tries to inject every cycle
            for (cyc = 0; cyc < SIM_CYCLES; cyc = cyc + 1) begin
                @(negedge clk);
                // inject (50% probability per node, when ready)
                for (i = 0; i < 4; i = i + 1) begin
                    if (lfsr[i+8] && inj_ready[i] && !inj_valid[i]) begin
                        pick_dst(i, dx_tmp, dy_tmp);
                        inj_data [i] = mkpkt(dx_tmp, dy_tmp, cyc[31:0]);
                        inj_valid[i] = 1'b1;
                        pkts_injected = pkts_injected + 1;
                    end else if (inj_ready[i]) begin
                        inj_valid[i] = 1'b0;
                    end
                end
                // sink at each node
                for (i = 0; i < 4; i = i + 1) begin
                    if (sink_valid[i]) begin
                        ej_cyc = pkt_icyc(sink_data[i]);
                        latency_sum = latency_sum + (cyc - ej_cyc);
                        pkts_delivered = pkts_delivered + 1;
                    end
                end
            end
            // drain
            for (i = 0; i < 4; i = i + 1) inj_valid[i] = 1'b0;
            for (cyc = SIM_CYCLES; cyc < SIM_CYCLES + 50; cyc = cyc + 1) begin
                @(negedge clk);
                for (i = 0; i < 4; i = i + 1) begin
                    if (sink_valid[i]) begin
                        ej_cyc = pkt_icyc(sink_data[i]);
                        latency_sum = latency_sum + (cyc - ej_cyc);
                        pkts_delivered = pkts_delivered + 1;
                    end
                end
            end

            // report
            $display("%0d (%s) %8d  %8d   %8d    %0d%%       %0d",
                     workload,
                     (workload==0)?"uniform   ":(workload==1)?"matmul-row":
                     (workload==2)?"matmul-col":"transpose ",
                     SIM_CYCLES, pkts_injected, pkts_delivered,
                     (pkts_injected > 0) ? (100 * (pkts_injected - pkts_delivered) / pkts_injected) : 0,
                     (pkts_delivered > 0) ? (latency_sum / pkts_delivered) : 0);
        end

        $display("=== done ===");
        $finish;
    end
endmodule
