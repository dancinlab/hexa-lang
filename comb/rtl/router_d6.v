// router_d6.v — degree-6 hex axial router (synthesizable RTL)
// 2026-05-18 · comb-side hand-written. Yosys-synthesizable subset.
// Hex dimension-order routing on axial (q,r,s=-q-r), round-robin arbiter,
// 6 input FIFOs + local, crossbar. Mirrors router_d4 structure for clean
// 1:1 metric comparison (T1A_analytical.md §2 — both isolated to graph
// dynamics, no wire-model overlay; that lives in hexa-arch[chip]).
//
// Ports follow comb axial convention (axis_b_topology.md):
//   pq=(+1,0)  nq=(-1,0)  pr=(0,+1)  nr=(0,-1)  ps=(+1,-1)  ns=(-1,+1)
//   local=index 6
//
// NOT tapeout-ready (Yosys + OpenROAD + SKY130 + DRC = hexa-arch[chip]).

`default_nettype none

module router_d6 #(
    parameter integer W       = 64,
    parameter integer ADDR_W  = 12,   // 2 × signed axial coord (q,r)
    parameter integer FIFO_LD = 2
) (
    input  wire             clk,
    input  wire             rst,
    // 6 axial input ports + local
    input  wire [W-1:0]     in_data  [0:6],
    input  wire             in_valid [0:6],
    output wire             in_ready [0:6],
    // 6 axial output ports + local
    output reg  [W-1:0]     out_data [0:6],
    output reg              out_valid[0:6],
    input  wire             out_ready[0:6],
    // this router's axial coordinate
    input  wire signed [ADDR_W/2-1:0] my_q,
    input  wire signed [ADDR_W/2-1:0] my_r
);
    localparam integer DEPTH = (1 << FIFO_LD);
    localparam integer P     = 7;       // 6 axial + local

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
        assign in_ready  [p] = !fifo_full[p];
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
