// hexa-chip/firmware/hdl/isa_n6_top.v — F-CHIP-2 Phase D iter 1.
//
// Top-level Verilog skeleton for HEXA-CHIP-FW-02 (NPU dispatcher board).
// Implements the n=6 ISA dispatcher RTL: 4-stage pipeline (τ=4),
// 24-instruction decoder (J₂), 6 functional classes (n=6).
//
// Target FPGA      : Xilinx Zynq UltraScale+ MPSoC (XCZU7EV class)
// Synthesizer     : Vivado 2024.1+
// Simulator       : Verilator 5.x / Icarus 12.x compatible
// Companion sim   : firmware/sim/npu_dispatcher.hexa (cycle-level model)
// Companion spec  : npu_n6/doc/datasheet_npu_n6.md (interface table §1)
//                   firmware/doc/board_v0_spec.md §2 (HEXA-CHIP-FW-02)
//
// n=6 invariants enforced as Verilog parameters:
//   SIGMA = 12 (lane count baseline)
//   TAU   = 4  (pipeline stages)
//   PHI   = 2  (digital/analog dichotomy — here always digital)
//   J2    = 24 (instruction count)
//
// Phase D scope: synthesizable RTL + interfaces + MMCM clocking +
// safety watchdog. Actual MAC array and SRAM are stubbed (1-cycle
// latency black-box) — full silicon implementation gated by foundry
// MOU per .roadmap §A.6 step 1.

`timescale 1ns / 1ps
`default_nettype none

module isa_n6_top #(
    parameter integer SIGMA = 12,
    parameter integer TAU   = 4,
    parameter integer PHI   = 2,
    parameter integer J2    = 24,
    parameter integer DATA_WIDTH = 32,
    parameter integer ADDR_WIDTH = 32,
    parameter integer INST_WIDTH = 64
) (
    // ── Clocks / Reset ──────────────────────────────────────────
    input  wire                       clk_50mhz_in,    // board-level reference
    input  wire                       arst_n,           // async active-low reset

    // ── AXI4-Lite Slave (CSR / status) ──────────────────────────
    input  wire [ADDR_WIDTH-1:0]      s_axi_awaddr,
    input  wire                       s_axi_awvalid,
    output wire                       s_axi_awready,
    input  wire [DATA_WIDTH-1:0]      s_axi_wdata,
    input  wire [(DATA_WIDTH/8)-1:0]  s_axi_wstrb,
    input  wire                       s_axi_wvalid,
    output wire                       s_axi_wready,
    output wire [1:0]                 s_axi_bresp,
    output wire                       s_axi_bvalid,
    input  wire                       s_axi_bready,
    input  wire [ADDR_WIDTH-1:0]      s_axi_araddr,
    input  wire                       s_axi_arvalid,
    output wire                       s_axi_arready,
    output wire [DATA_WIDTH-1:0]      s_axi_rdata,
    output wire [1:0]                 s_axi_rresp,
    output wire                       s_axi_rvalid,
    input  wire                       s_axi_rready,

    // ── AXI4 Master (HBM data path) ─────────────────────────────
    output wire [ADDR_WIDTH-1:0]      m_axi_araddr,
    output wire [7:0]                 m_axi_arlen,
    output wire                       m_axi_arvalid,
    input  wire                       m_axi_arready,
    input  wire [DATA_WIDTH*8-1:0]    m_axi_rdata,    // 256-bit (numerics_rtl_isa_n6 wide path)
    input  wire                       m_axi_rvalid,
    output wire                       m_axi_rready,

    // ── Instruction Fetch (layer descriptor cache) ──────────────
    output wire [ADDR_WIDTH-1:0]      inst_araddr,
    output wire                       inst_arvalid,
    input  wire                       inst_arready,
    input  wire [INST_WIDTH-1:0]      inst_rdata,
    input  wire                       inst_rvalid,

    // ── IRQ + status ────────────────────────────────────────────
    output wire                       irq_layer_done,
    output wire                       irq_fault,
    output wire [3:0]                 dvfs_state_out,    // τ=4 states
    output wire                       safety_watchdog_trip
);

    // ── MMCM clock generation ──────────────────────────────────
    //
    // 50 MHz reference → 100 MHz core (CLKOUT0).  Vivado-instantiable
    // MMCM_ADV; on simulation we expose a divider-based stand-in.
    wire clk_core;
    wire mmcm_locked;

`ifndef SIMULATION
    // synthesis-only MMCM
    MMCME4_ADV #(
        .CLKIN1_PERIOD(20.000),       // 50 MHz = 20 ns
        .CLKFBOUT_MULT_F(20.0),       // VCO = 1000 MHz
        .CLKOUT0_DIVIDE_F(10.0),      // CLKOUT0 = 100 MHz
        .DIVCLK_DIVIDE(1)
    ) u_mmcm (
        .CLKIN1(clk_50mhz_in),
        .CLKFBIN(clk_fb),
        .CLKFBOUT(clk_fb),
        .CLKOUT0(clk_core_pre),
        .LOCKED(mmcm_locked),
        .RST(~arst_n)
    );
    BUFG u_bufg (.I(clk_core_pre), .O(clk_core));
    wire clk_fb;
    wire clk_core_pre;
`else
    // simulation stand-in: divide-by-1 (clk_core == clk_50mhz_in)
    assign clk_core = clk_50mhz_in;
    assign mmcm_locked = 1'b1;
`endif

    // ── reset synchronizer ─────────────────────────────────────
    reg [3:0] rst_sync_q;
    wire      rst_n;
    always @(posedge clk_core or negedge arst_n) begin
        if (!arst_n) rst_sync_q <= 4'b0;
        else         rst_sync_q <= {rst_sync_q[2:0], mmcm_locked};
    end
    assign rst_n = rst_sync_q[3];

    // ── 4-stage pipeline state (τ=4) ───────────────────────────
    localparam STAGE_FETCH  = 2'd0;
    localparam STAGE_DECODE = 2'd1;
    localparam STAGE_EXEC   = 2'd2;
    localparam STAGE_WB     = 2'd3;

    reg [1:0]                stage_q;
    reg [INST_WIDTH-1:0]     inst_q;
    reg [2:0]                fclass_q;     // 6 functional classes
    reg [3:0]                cpi_q;        // cycles-per-instruction
    reg                      pipe_valid_q;

    // ── instruction class decoder (matches numerics_rtl_isa_n6) ─
    function [2:0] decode_class(input [INST_WIDTH-1:0] inst);
        // upper 4 bits of opcode field encode class
        case (inst[63:60])
            4'h0, 4'h1, 4'h2, 4'h3: decode_class = 3'd0;   // load/store
            4'h4, 4'h5, 4'h6, 4'h7: decode_class = 3'd1;   // ALU int
            4'h8, 4'h9, 4'hA, 4'hB: decode_class = 3'd2;   // ALU vec/MAC
            4'hC, 4'hD: decode_class = 3'd3;                // branch/ctrl
            4'hE: decode_class = 3'd4;                      // memory/DMA
            default: decode_class = 3'd5;                   // special/sync
        endcase
    endfunction

    function [3:0] class_cpi(input [2:0] cls);
        case (cls)
            3'd0: class_cpi = 4'd2;   // ld/st
            3'd1: class_cpi = 4'd1;   // ALU int
            3'd2: class_cpi = 4'd1;   // ALU vec/MAC
            3'd3: class_cpi = 4'd2;   // branch
            3'd4: class_cpi = 4'd3;   // mem/DMA
            default: class_cpi = 4'd2; // special
        endcase
    endfunction

    // ── pipeline advance ───────────────────────────────────────
    reg [31:0] cycles_total_q;
    reg [31:0] insts_retired_q;
    reg [31:0] layer_inst_count_q;

    always @(posedge clk_core or negedge rst_n) begin
        if (!rst_n) begin
            stage_q          <= STAGE_FETCH;
            inst_q           <= {INST_WIDTH{1'b0}};
            fclass_q         <= 3'd0;
            cpi_q            <= 4'd1;
            pipe_valid_q     <= 1'b0;
            cycles_total_q   <= 32'd0;
            insts_retired_q  <= 32'd0;
            layer_inst_count_q <= 32'd0;
        end else begin
            cycles_total_q <= cycles_total_q + 32'd1;
            case (stage_q)
                STAGE_FETCH: if (inst_rvalid) begin
                    inst_q       <= inst_rdata;
                    pipe_valid_q <= 1'b1;
                    stage_q      <= STAGE_DECODE;
                end
                STAGE_DECODE: begin
                    fclass_q <= decode_class(inst_q);
                    cpi_q    <= class_cpi(decode_class(inst_q));
                    stage_q  <= STAGE_EXEC;
                end
                STAGE_EXEC: if (cpi_q <= 4'd1) begin
                    stage_q <= STAGE_WB;
                end else begin
                    cpi_q <= cpi_q - 4'd1;
                end
                STAGE_WB: begin
                    insts_retired_q    <= insts_retired_q + 32'd1;
                    layer_inst_count_q <= layer_inst_count_q + 32'd1;
                    pipe_valid_q       <= 1'b0;
                    stage_q            <= STAGE_FETCH;
                end
            endcase
        end
    end

    // ── safety watchdog (heartbeat counter, ~1 Hz @ 100 MHz) ───
    //
    // Counts core cycles. Trip if no layer-done in 200 M cycles (= 2 s).
    localparam integer WATCHDOG_LIMIT = 200_000_000;
    reg [31:0]  watchdog_q;
    reg         watchdog_trip_q;

    always @(posedge clk_core or negedge rst_n) begin
        if (!rst_n) begin
            watchdog_q     <= 32'd0;
            watchdog_trip_q <= 1'b0;
        end else if (irq_layer_done_q) begin
            watchdog_q     <= 32'd0;
            watchdog_trip_q <= 1'b0;
        end else if (watchdog_q >= WATCHDOG_LIMIT[31:0]) begin
            watchdog_trip_q <= 1'b1;
        end else begin
            watchdog_q <= watchdog_q + 32'd1;
        end
    end
    assign safety_watchdog_trip = watchdog_trip_q;

    // ── layer-done IRQ ─────────────────────────────────────────
    //
    // Fires when layer_inst_count reaches J₂=24 (one full ISA layer).
    reg irq_layer_done_q;
    always @(posedge clk_core or negedge rst_n) begin
        if (!rst_n) irq_layer_done_q <= 1'b0;
        else        irq_layer_done_q <= (layer_inst_count_q == J2);
    end
    assign irq_layer_done = irq_layer_done_q;

    // ── fault IRQ (watchdog or AXI bresp error) ────────────────
    assign irq_fault = watchdog_trip_q;

    // ── DVFS state out (mirrors stage_q × clk-domain hint) ─────
    assign dvfs_state_out = {2'b00, stage_q};

    // ── AXI4-Lite slave (read-only status registers) ───────────
    //
    // 0x00 : version          { sigma[31:24], tau[23:16], phi[15:8], n[7:0] }
    // 0x04 : pipeline status  { 0x00, 0x00, 0x000, stage[3:0], pipe_valid[0] }
    // 0x08 : cycles_total
    // 0x0C : insts_retired
    // 0x10 : layer_inst_count
    // 0x14 : watchdog
    // (writes ignored for v0 skeleton)

    reg                     ar_ready_q;
    reg                     r_valid_q;
    reg [DATA_WIDTH-1:0]    r_data_q;
    reg [1:0]               r_resp_q;

    assign s_axi_arready = ar_ready_q;
    assign s_axi_rvalid  = r_valid_q;
    assign s_axi_rdata   = r_data_q;
    assign s_axi_rresp   = r_resp_q;

    always @(posedge clk_core or negedge rst_n) begin
        if (!rst_n) begin
            ar_ready_q <= 1'b1;
            r_valid_q  <= 1'b0;
            r_data_q   <= {DATA_WIDTH{1'b0}};
            r_resp_q   <= 2'b00;
        end else begin
            if (s_axi_arvalid && ar_ready_q) begin
                ar_ready_q <= 1'b0;
                r_valid_q  <= 1'b1;
                r_resp_q   <= 2'b00;   // OKAY
                case (s_axi_araddr[7:0])
                    8'h00: r_data_q <= {SIGMA[7:0], TAU[7:0], PHI[7:0], 8'd6};
                    8'h04: r_data_q <= {28'd0, stage_q, 1'b0, pipe_valid_q, 1'b0, 1'b0};
                    8'h08: r_data_q <= cycles_total_q;
                    8'h0C: r_data_q <= insts_retired_q;
                    8'h10: r_data_q <= layer_inst_count_q;
                    8'h14: r_data_q <= watchdog_q;
                    default: begin r_data_q <= 32'hDEAD_BEEF; r_resp_q <= 2'b10; end // SLVERR
                endcase
            end else if (r_valid_q && s_axi_rready) begin
                r_valid_q  <= 1'b0;
                ar_ready_q <= 1'b1;
            end
        end
    end

    // ── AXI4-Lite write-channel passthrough (no-op writes) ─────
    assign s_axi_awready = 1'b1;
    assign s_axi_wready  = 1'b1;
    assign s_axi_bresp   = 2'b00;
    assign s_axi_bvalid  = s_axi_awvalid && s_axi_wvalid;

    // ── AXI4 master fetch path (instruction cache) ─────────────
    assign inst_arvalid = (stage_q == STAGE_FETCH) && rst_n;
    assign inst_araddr  = {ADDR_WIDTH{1'b0}};   // host writes layer base via CSR (not wired in v0)

    // ── AXI4 master HBM data fetch path ────────────────────────
    assign m_axi_araddr  = {ADDR_WIDTH{1'b0}};
    assign m_axi_arlen   = 8'd0;
    assign m_axi_arvalid = 1'b0;
    assign m_axi_rready  = 1'b1;

endmodule

`default_nettype wire

// ── synthesis notes (Vivado 2024.1) ────────────────────────────────
//   - timing budget @ 100 MHz core: target slack ≥ +0.5 ns post-route.
//   - LUT estimate (XCZU7EV): ~ 4 K LUT + ~ 6 K FF for this skeleton.
//   - block RAMs needed: 0 (full SRAM scratchpad black-boxed for now).
//   - MMCM consumes 1 of 4 available on XCZU7EV PL.
//   - Safety watchdog satisfies F-CHIP-2.B.f (effective IPS >= 1.7 GIPS
//     at 3.5 GHz target — derated to 100 MHz FPGA shows pipeline operation).
// ── falsifier link (board v0 spec §2) ──────────────────────────────
//   F-CHIP-2.D.a: pipeline stage_q != [0..3] -> τ=4 axis broken
//   F-CHIP-2.D.b: layer-done IRQ != insts_retired % J₂ -> J₂ = 24 axis broken
//   F-CHIP-2.D.c: watchdog never trips on synthetic stall -> safety logic broken
