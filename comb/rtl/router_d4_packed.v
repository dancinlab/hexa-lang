// router_d4_packed.v — semantic equivalent of router_d4.v with packed ports.
//
// Origin: 2026-05-21 RFC 006 §5 oracle re-measurement. Yosys 0.65 and 0.33
// both reject the ANSI-with-unpacked-array port list in `router_d4.v` line 18
// (`input wire [W-1:0] in_data [0:4]`) with a syntax error. To re-derive the
// substrate area oracle, this file packs each `[W-1:0] X [0:N]` port into a
// single packed `[(N+1)*W-1:0] X_p` and ties internal unpacked arrays via
// generate assigns. The body of the module is byte-identical to router_d4.v
// after the port declarations.
//
// Semantic equivalence: each unpacked element X[k] in the original maps to
// X_p[((k+1)*W-1) -: W] in the packed version. The synthesis flow sees an
// identical netlist after `flatten`; ABC sees a packed bus instead of 5
// separate single-bit nets but the gate-level optimization is unchanged.

`default_nettype none

module router_d4 #(
    parameter integer W       = 64,   // payload width
    parameter integer ADDR_W  = 8,    // 2x signed coord field (x, y)
    parameter integer FIFO_LD = 2     // log2 depth per input FIFO (4 entries)
) (
    input  wire             clk,
    input  wire             rst,
    // 4 input ports + local, packed
    input  wire [5*W-1:0]   in_data_p,
    input  wire [4:0]       in_valid_p,
    output wire [4:0]       in_ready_p,
    // 4 output ports + local, packed
    output wire [5*W-1:0]   out_data_p,
    output wire [4:0]       out_valid_p,
    input  wire [4:0]       out_ready_p,
    // this router's coordinate
    input  wire signed [ADDR_W/2-1:0] my_x,
    input  wire signed [ADDR_W/2-1:0] my_y
);
    localparam integer DEPTH = (1 << FIFO_LD);
    localparam integer P     = 5;       // 4 cardinal + local

    // ── Unpacked-array views of the packed ports (body uses these unchanged) ──
    wire [W-1:0]     in_data  [0:P-1];
    wire             in_valid [0:P-1];
    wire             in_ready_w[0:P-1];
    reg  [W-1:0]     out_data [0:P-1];
    reg              out_valid[0:P-1];
    wire             out_ready[0:P-1];

    genvar gi;
    generate for (gi = 0; gi < P; gi = gi + 1) begin : g_unpack_in
        assign in_data [gi] = in_data_p [((gi+1)*W-1) -: W];
        assign in_valid[gi] = in_valid_p[gi];
        assign in_ready_p[gi] = in_ready_w[gi];
        assign out_data_p [((gi+1)*W-1) -: W] = out_data [gi];
        assign out_valid_p[gi] = out_valid[gi];
        assign out_ready[gi]   = out_ready_p[gi];
    end endgenerate

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
        assign in_ready_w[p] = !fifo_full[p];
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
