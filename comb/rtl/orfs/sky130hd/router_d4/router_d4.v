`default_nettype none
module router_d4 (
	clk,
	rst,
	in_data,
	in_valid,
	in_ready,
	out_data,
	out_valid,
	out_ready,
	my_x,
	my_y
);
	reg _sv2v_0;
	parameter integer W = 64;
	parameter integer ADDR_W = 8;
	parameter integer FIFO_LD = 2;
	input wire clk;
	input wire rst;
	input wire [(5 * W) - 1:0] in_data;
	input wire [0:4] in_valid;
	output wire [0:4] in_ready;
	output reg [(5 * W) - 1:0] out_data;
	output reg [0:4] out_valid;
	input wire [0:4] out_ready;
	input wire signed [(ADDR_W / 2) - 1:0] my_x;
	input wire signed [(ADDR_W / 2) - 1:0] my_y;
	localparam integer DEPTH = 1 << FIFO_LD;
	localparam integer P = 5;
	function automatic signed [(ADDR_W / 2) - 1:0] dst_x_of;
		input [W - 1:0] d;
		dst_x_of = d[W - 1-:ADDR_W / 2];
	endfunction
	function automatic signed [(ADDR_W / 2) - 1:0] dst_y_of;
		input [W - 1:0] d;
		dst_y_of = d[(W - 1) - (ADDR_W / 2)-:ADDR_W / 2];
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
	function automatic [2:0] route_xy;
		input [W - 1:0] pkt;
		reg signed [(ADDR_W / 2) - 1:0] dx;
		reg signed [(ADDR_W / 2) - 1:0] dy;
		begin
			dx = dst_x_of(pkt) - my_x;
			dy = dst_y_of(pkt) - my_y;
			if (dx > 0)
				route_xy = 3'd2;
			else if (dx < 0)
				route_xy = 3'd3;
			else if (dy > 0)
				route_xy = 3'd0;
			else if (dy < 0)
				route_xy = 3'd1;
			else
				route_xy = 3'd4;
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
					grant_out = route_xy(fifo_peek[idx]);
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
					fifo_mem[pp][fifo_tail[pp][FIFO_LD - 1:0]] <= in_data[(4 - pp) * W+:W];
					fifo_tail[pp] <= fifo_tail[pp] + 1;
				end
			for (pp = 0; pp < P; pp = pp + 1)
				out_valid[pp] <= 1'b0;
			if (any_grant) begin
				out_data[(4 - grant_out) * W+:W] <= fifo_peek[grant_in];
				out_valid[grant_out] <= 1'b1;
				fifo_head[grant_in] <= fifo_head[grant_in] + 1;
				rr_ptr <= (grant_in + 1) % P;
			end
		end
	initial _sv2v_0 = 0;
endmodule
`default_nettype wire
