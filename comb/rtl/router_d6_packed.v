// router_d6_packed.v — semantic equivalent of router_d6.v with packed ports.
//
// Origin: 2026-05-21 RFC 006 §5 oracle re-measurement. See router_d4_packed.v
// for the rationale: yosys 0.65 / 0.33 reject ANSI-with-unpacked-array port
// lists. This variant packs each `[W-1:0] X [0:N]` port into a single
// `[(N+1)*W-1:0]` packed bus and exposes internal unpacked-array views via
// generate assigns. The body is byte-identical to router_d6.v after the port
// declarations.

`default_nettype none

module router_d6 #(
    parameter integer W       = 64,
    parameter integer ADDR_W  = 12,   // 2 × signed axial coord (q,r)
    parameter integer FIFO_LD = 2
) (
    input  wire             clk,
    input  wire             rst,
    // 6 axial input ports + local, packed
    input  wire [7*W-1:0]   in_data_p,
    input  wire [6:0]       in_valid_p,
    output wire [6:0]       in_ready_p,
    // 6 axial output ports + local, packed
    output wire [7*W-1:0]   out_data_p,
    output wire [6:0]       out_valid_p,
    input  wire [6:0]       out_ready_p,
    // this router's axial coordinate
    input  wire signed [ADDR_W/2-1:0] my_q,
    input  wire signed [ADDR_W/2-1:0] my_r
);
    localparam integer DEPTH = (1 << FIFO_LD);
    localparam integer P     = 7;       // 6 axial + local

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

    // port indices (literal constants for routing decisions)
    localparam [2:0] PQ = 3'd0, NQ = 3'd1, PR = 3'd2, NR = 3'd3,
                     PS = 3'd4, NS = 3'd5, LL = 3'd6;

    function automatic signed [ADDR_W/2-1:0] dst_q_of(input [W-1:0] d);
        dst_q_of = d[W-1 -: ADDR_W/2];
    endfunction
    function automatic signed [ADDR_W/2-1:0] dst_r_of(input [W-1:0] d);
        dst_r_of = d[W-1-ADDR_W/2 -: ADDR_W/2];
    endfunction

    // ── input FIFOs ──────────────────────────────────────────────
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

    // ── hex dimension-order routing ─────────────────────────────
    // Compute axial deltas; pick the axis with the largest |Δ|, then choose
    // direction. s = -q-r so (Δs = -Δq-Δr); we consider all 3 axes.
    function automatic [2:0] route_hex(input [W-1:0] pkt);
        reg signed [ADDR_W/2-1:0] dq, dr, ds;
        reg signed [ADDR_W/2-1:0] aq, ar, as_;
        begin
            dq  = dst_q_of(pkt) - my_q;
            dr  = dst_r_of(pkt) - my_r;
            ds  = -dq - dr;
            aq  = (dq < 0) ? -dq : dq;
            ar  = (dr < 0) ? -dr : dr;
            as_ = (ds < 0) ? -ds : ds;
            if (aq == 0 && ar == 0 && as_ == 0)              route_hex = LL;
            else if (aq >= ar && aq >= as_)                  route_hex = (dq > 0) ? PQ : NQ;
            else if (ar >= aq && ar >= as_)                  route_hex = (dr > 0) ? PR : NR;
            else                                              route_hex = (ds > 0) ? PS : NS;
        end
    endfunction

    // ── round-robin arbiter ────────────────────────────────────
    reg [2:0] rr_ptr;
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
                grant_out = route_hex(fifo_peek[idx]);
                if (out_ready[grant_out]) begin
                    any_grant = 1'b1;
                    grant_in  = idx[2:0];
                end
            end
        end
    end

    // ── FIFO + crossbar (single-issue) ─────────────────────────
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
            for (pp = 0; pp < P; pp = pp + 1) begin
                if (in_valid[pp] && !fifo_full[pp]) begin
                    fifo_mem[pp][fifo_tail[pp][FIFO_LD-1:0]] <= in_data[pp];
                    fifo_tail[pp] <= fifo_tail[pp] + 1;
                end
            end
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
