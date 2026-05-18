// router_d4.v — degree-4 2D mesh router (synthesizable RTL baseline)
// 2026-05-18 · comb-side hand-written. Yosys-synthesizable subset.
// XY dimension-order routing, round-robin arbiter, 4 input FIFOs, crossbar.
//
// NOT tapeout-ready: no PDK mapping, no DRC, no STA. Synthesis + P&R +
// signoff = hexa-arch[chip] (Yosys/OpenROAD/SKY130 absorption).

`default_nettype none

module router_d4 #(
    parameter integer W       = 64,   // payload width
    parameter integer ADDR_W  = 8,    // 2x signed coord field (x, y)
    parameter integer FIFO_LD = 2     // log2 depth per input FIFO (4 entries)
) (
    input  wire             clk,
    input  wire             rst,
    // 4 input ports: N(+y), S(-y), E(+x), W(-x), plus local
    input  wire [W-1:0]     in_data  [0:4],
    input  wire             in_valid [0:4],
    output wire             in_ready [0:4],
    // 4 output ports + local
    output reg  [W-1:0]     out_data [0:4],
    output reg              out_valid[0:4],
    input  wire             out_ready[0:4],
    // this router's coordinate
    input  wire signed [ADDR_W/2-1:0] my_x,
    input  wire signed [ADDR_W/2-1:0] my_y
);
    localparam integer DEPTH = (1 << FIFO_LD);
    localparam integer P     = 5;       // 4 cardinal + local

    // payload layout: high bits = dst_x, dst_y; low = body
    function automatic signed [ADDR_W/2-1:0] dst_x_of(input [W-1:0] d);
        dst_x_of = d[W-1 -: ADDR_W/2];
    endfunction
    function automatic signed [ADDR_W/2-1:0] dst_y_of(input [W-1:0] d);
        dst_y_of = d[W-1-ADDR_W/2 -: ADDR_W/2];
    endfunction

    // ── input FIFOs (ring buffer per port) ─────────────────────────
    reg  [W-1:0] fifo_mem [0:P-1][0:DEPTH-1];
    reg  [FIFO_LD:0] fifo_head [0:P-1];
    reg  [FIFO_LD:0] fifo_tail [0:P-1];
    wire             fifo_empty[0:P-1];
    wire             fifo_full [0:P-1];
    wire [W-1:0]     fifo_peek [0:P-1];

    genvar p;
    generate for (p = 0; p < P; p = p + 1) begin : g_fifo
        assign fifo_empty[p] = (fifo_head[p] == fifo_tail[p]);
        assign fifo_full [p] = ((fifo_tail[p][FIFO_LD-1:0] == fifo_head[p][FIFO_LD-1:0])
                             && (fifo_tail[p][FIFO_LD] != fifo_head[p][FIFO_LD]));
        assign fifo_peek [p] = fifo_mem[p][fifo_head[p][FIFO_LD-1:0]];
        assign in_ready  [p] = !fifo_full[p];
    end endgenerate

    // ── XY dimension-order routing: returns output port for a packet ──
    function automatic [2:0] route_xy(input [W-1:0] pkt);
        reg signed [ADDR_W/2-1:0] dx, dy;
        begin
            dx = dst_x_of(pkt) - my_x;
            dy = dst_y_of(pkt) - my_y;
            if      (dx > 0) route_xy = 3'd2;   // E
            else if (dx < 0) route_xy = 3'd3;   // W
            else if (dy > 0) route_xy = 3'd0;   // N
            else if (dy < 0) route_xy = 3'd1;   // S
            else             route_xy = 3'd4;   // local
        end
    endfunction

    // ── round-robin arbiter pointer ────────────────────────────────
    reg [2:0] rr_ptr;

    // grant: pick the next non-empty input whose target port is free
    integer i, idx;
    reg     [2:0] grant_in;
    reg     [2:0] grant_out;
    reg           any_grant;

    always @* begin
        any_grant = 1'b0;
        grant_in  = 3'd0;
        grant_out = 3'd0;
        for (i = 0; i < P; i = i + 1) begin
            idx = (rr_ptr + i) % P;
            if (!any_grant && !fifo_empty[idx]) begin
                grant_out = route_xy(fifo_peek[idx]);
                if (out_ready[grant_out]) begin
                    any_grant = 1'b1;
                    grant_in  = idx[2:0];
                end
            end
        end
    end

    // ── FIFO updates + crossbar (one packet/cycle, single-issue) ──
    integer pp;
    always @(posedge clk) begin
        if (rst) begin
            rr_ptr <= 3'd0;
            for (pp = 0; pp < P; pp = pp + 1) begin
                fifo_head[pp] <= 0;
                fifo_tail[pp] <= 0;
                out_valid[pp] <= 1'b0;
            end
        end else begin
            // enqueue arrivals
            for (pp = 0; pp < P; pp = pp + 1) begin
                if (in_valid[pp] && !fifo_full[pp]) begin
                    fifo_mem[pp][fifo_tail[pp][FIFO_LD-1:0]] <= in_data[pp];
                    fifo_tail[pp] <= fifo_tail[pp] + 1;
                end
            end
            // dequeue grant + crossbar
            for (pp = 0; pp < P; pp = pp + 1) out_valid[pp] <= 1'b0;
            if (any_grant) begin
                out_data [grant_out] <= fifo_peek[grant_in];
                out_valid[grant_out] <= 1'b1;
                fifo_head[grant_in]  <= fifo_head[grant_in] + 1;
                rr_ptr               <= (grant_in + 1) % P;
            end
        end
    end
endmodule

`default_nettype wire
