`default_nettype none
module router_d6 (
	clk,
	rst,
	in_data,
	in_valid,
	in_ready,
	out_data,
	out_valid,
	out_ready,
	my_q,
	my_r
);
	reg _sv2v_0;
	parameter integer W = 64;
	parameter integer ADDR_W = 12;
	parameter integer FIFO_LD = 2;
	input wire clk;
	input wire rst;
	input wire [(7 * W) - 1:0] in_data;
	input wire [0:6] in_valid;
	output wire [0:6] in_ready;
	output reg [(7 * W) - 1:0] out_data;
	output reg [0:6] out_valid;
	input wire [0:6] out_ready;
	input wire signed [(ADDR_W / 2) - 1:0] my_q;
	input wire signed [(ADDR_W / 2) - 1:0] my_r;
	localparam integer DEPTH = 1 << FIFO_LD;
	localparam integer P = 7;
	localparam [2:0] PQ = 3'd0;
	localparam [2:0] NQ = 3'd1;
	localparam [2:0] PR = 3'd2;
	localparam [2:0] NR = 3'd3;
	localparam [2:0] PS = 3'd4;
	localparam [2:0] NS = 3'd5;
	localparam [2:0] LL = 3'd6;
	function automatic signed [(ADDR_W / 2) - 1:0] dst_q_of;
		input [W - 1:0] d;
		dst_q_of = d[W - 1-:ADDR_W / 2];
	endfunction
	function automatic signed [(ADDR_W / 2) - 1:0] dst_r_of;
		input [W - 1:0] d;
		dst_r_of = d[(W - 1) - (ADDR_W / 2)-:ADDR_W / 2];
	endfunction
	reg [W - 1:0] fifo_mem [0:P - 1][0:DEPTH - 1];
	reg [FIFO_LD:0] fifo_head [0:P - 1];
	reg [FIFO_LD:0] fifo_tail [0:P - 1];
	wire fifo_empty [0:P - 1];
	wire fifo_full [0:P - 1];
	wire [W - 1:0] fifo_peek [0:P - 1];
	genvar _gv_p_1;
	generate
		for (_gv_p_1 = 0; _gv_p_1 < P; _gv_p_1 = _gv_p_1 + 1) begin : g_fifo
			localparam p = _gv_p_1;
			assign fifo_empty[p] = fifo_head[p] == fifo_tail[p];
			assign fifo_full[p] = (fifo_tail[p][FIFO_LD - 1:0] == fifo_head[p][FIFO_LD - 1:0]) && (fifo_tail[p][FIFO_LD] != fifo_head[p][FIFO_LD]);
			assign fifo_peek[p] = fifo_mem[p][fifo_head[p][FIFO_LD - 1:0]];
			assign in_ready[p] = !fifo_full[p];
		end
	endgenerate
	function automatic [2:0] route_hex;
		input [W - 1:0] pkt;
		reg signed [(ADDR_W / 2) - 1:0] dq;
		reg signed [(ADDR_W / 2) - 1:0] dr;
		reg signed [(ADDR_W / 2) - 1:0] ds;
		reg signed [(ADDR_W / 2) - 1:0] aq;
		reg signed [(ADDR_W / 2) - 1:0] ar;
		reg signed [(ADDR_W / 2) - 1:0] as_;
		begin
			dq = dst_q_of(pkt) - my_q;
			dr = dst_r_of(pkt) - my_r;
			ds = -(dq + dr);
			aq = (dq < 0 ? -dq : dq);
			ar = (dr < 0 ? -dr : dr);
			as_ = (ds < 0 ? -ds : ds);
			if (((aq == 0) && (ar == 0)) && (as_ == 0))
				route_hex = LL;
			else if ((aq >= ar) && (aq >= as_))
				route_hex = (dq > 0 ? PQ : NQ);
			else if ((ar >= aq) && (ar >= as_))
				route_hex = (dr > 0 ? PR : NR);
			else
				route_hex = (ds > 0 ? PS : NS);
		end
	endfunction
	reg [2:0] rr_ptr;
	integer i;
	integer idx;
	reg [2:0] grant_in;
	reg [2:0] grant_out;
	reg any_grant;
	always @(*) begin
		any_grant = 1'b0;
		grant_in = 3'd0;
		grant_out = 3'd0;
		for (i = 0; i < P; i = i + 1)
			begin
				idx = (rr_ptr + i) % P;
				if (!any_grant && !fifo_empty[idx]) begin
					grant_out = route_hex(fifo_peek[idx]);
					if (out_ready[grant_out]) begin
						any_grant = 1'b1;
						grant_in = idx[2:0];
					end
				end
			end
	end
	integer pp;
	always @(posedge clk)
		if (rst) begin
			rr_ptr <= 3'd0;
			for (pp = 0; pp < P; pp = pp + 1)
				begin
					fifo_head[pp] <= 0;
					fifo_tail[pp] <= 0;
					out_valid[pp] <= 1'b0;
				end
		end
		else begin
			for (pp = 0; pp < P; pp = pp + 1)
				if (in_valid[pp] && !fifo_full[pp]) begin
					fifo_mem[pp][fifo_tail[pp][FIFO_LD - 1:0]] <= in_data[(6 - pp) * W+:W];
					fifo_tail[pp] <= fifo_tail[pp] + 1;
				end
			for (pp = 0; pp < P; pp = pp + 1)
				out_valid[pp] <= 1'b0;
			if (any_grant) begin
				out_data[(6 - grant_out) * W+:W] <= fifo_peek[grant_in];
				out_valid[grant_out] <= 1'b1;
				fifo_head[grant_in] <= fifo_head[grant_in] + 1;
				rr_ptr <= (grant_in + 1) % P;
			end
		end
	initial _sv2v_0 = 0;
endmodule
`default_nettype wire
