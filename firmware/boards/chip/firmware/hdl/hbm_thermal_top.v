// hexa-chip/firmware/hdl/hbm_thermal_top.v — F-CHIP-3 Phase D iter 2.
//
// Top-level Verilog skeleton for HEXA-CHIP-FW-03 (HBM thermal controller
// board). Implements the 16-layer HBM4 in-stack thermal sensor bridge,
// τ=4 DVFS state machine, and CATTRIP latch — companion to
// firmware/sim/hbm_thermal_controller.hexa (cycle-level Jacobi model).
//
// Target FPGA      : Xilinx Kintex UltraScale (XCKU040 class)
// Synthesizer     : Vivado 2024.1+
// Simulator       : Verilator 5.x / Icarus 12.x compatible
// Companion sim   : firmware/sim/hbm_thermal_controller.hexa
// Companion spec  : firmware/doc/board_v0_spec.md §3 (HEXA-CHIP-FW-03)
//                   verify/numerics_hbm_solver.hexa (Jacobi 1-D Laplace)
//
// n=6 invariants enforced as Verilog parameters:
//   SIGMA = 12 (HBM σ-φ lattice baseline; here passthrough)
//   TAU   = 4  (DVFS lifecycle states — SAMPLE/CONVERT/FILTER/REPORT)
//   PHI   = 2  (digital control / analog sense dichotomy)
//   J2    = 24 (canon — not directly wired here, exposed for cross-board)
//
// Phase D scope: synthesizable RTL + interfaces + MMCM clocking +
// safety watchdog + DVFS FSM + CATTRIP latch. HBM4 wide bus
// (HBM_DQ[2047:0] + DQS) is paper-only black-box passthrough — full
// silicon implementation gated by SK Hynix HBM4 sample MOU per board v0
// spec §5 G2.

`timescale 1ns / 1ps
`default_nettype none

module hbm_thermal_top #(
    parameter integer SIGMA = 12,
    parameter integer TAU   = 4,
    parameter integer PHI   = 2,
    parameter integer J2    = 24,
    parameter integer DATA_WIDTH = 32,
    parameter integer ADDR_WIDTH = 32,
    parameter integer LAYERS    = 16,
    parameter integer T_DVFS_C  = 90,        // °C threshold (DVFS engage)
    parameter integer T_TRIP_C  = 105        // °C threshold (CATTRIP latch)
) (
    // ── Clocks / Reset ──────────────────────────────────────────
    input  wire                       clk_50mhz_in,    // board-level reference
    input  wire                       arst_n,          // async active-low reset

    // ── 16 thermal-sensor I²C bus mux (per-layer T sense) ───────
    input  wire [LAYERS-1:0]          tsense_sda_in,   // mux'd SDA per layer
    output wire [LAYERS-1:0]          tsense_sda_oe,   // open-drain enables
    output wire                       tsense_scl,      // shared clock

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

    // ── HBM4 wide-bus passthrough (PAPER-ONLY BLACK BOX) ────────
    //
    // The 2048-bit DQ + 32-bit DQS path is held off-board for this
    // RTL skeleton; pin order matches board v0 spec §3.1. Synth
    // ignores via tie-off until SK Hynix HBM4 sample lands.
    input  wire [2047:0]              hbm_dq_in,       // black-box rx
    output wire [2047:0]              hbm_dq_out,      // black-box tx
    output wire [31:0]                hbm_dqs,         // strobe
    output wire                       hbm_reset_n,

    // ── Outputs to host PMU ─────────────────────────────────────
    output wire [3:0]                 dvfs_state,      // τ=4 states
    output wire                       cattrip_latch,   // sticky thermal trip
    output wire                       irq_thermal,     // edge IRQ to host
    output wire                       safety_watchdog_trip
);

    // ── MMCM clock generation ──────────────────────────────────
    //
    // 50 MHz reference → 100 MHz core (CLKOUT0). Vivado-instantiable
    // MMCM_ADV; on simulation we expose a divider-based stand-in.
    wire clk_core;
    wire mmcm_locked;

`ifndef SIMULATION
    // synthesis-only MMCM (Kintex UltraScale primitive)
    MMCME3_ADV #(
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
    assign clk_core    = clk_50mhz_in;
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

    // ── τ=4 lifecycle FSM: SAMPLE → CONVERT → FILTER → REPORT ──
    localparam STATE_SAMPLE  = 2'd0;
    localparam STATE_CONVERT = 2'd1;
    localparam STATE_FILTER  = 2'd2;
    localparam STATE_REPORT  = 2'd3;

    reg [1:0]                fsm_q;
    reg [3:0]                layer_idx_q;          // 0..15 sampler index
    reg [15:0]               temp_raw_q;           // raw I²C readout
    reg [15:0]               temp_c_q  [0:LAYERS-1]; // per-layer °C × 1
    reg [15:0]               max_temp_c_q;
    reg [31:0]               sample_count_q;

    // ── DVFS state encoder (mirrors numerics_power_thermal τ=4) ─
    //
    // 0x0 NOMINAL : all layers < 80 °C
    // 0x1 WARM    : any layer ≥ 80 °C
    // 0x2 HOT     : any layer ≥ T_DVFS_C (90 °C) — DVFS engage
    // 0x3 TRIP    : any layer ≥ T_TRIP_C (105 °C) — CATTRIP fires
    function [3:0] encode_dvfs(input [15:0] tmax);
        if      (tmax >= T_TRIP_C) encode_dvfs = 4'h3;
        else if (tmax >= T_DVFS_C) encode_dvfs = 4'h2;
        else if (tmax >= 16'd80)   encode_dvfs = 4'h1;
        else                       encode_dvfs = 4'h0;
    endfunction

    reg [3:0] dvfs_state_q;
    reg       cattrip_latch_q;
    reg       irq_thermal_q;

    // ── per-layer max scan helper ──────────────────────────────
    integer ii;
    reg [15:0] tmax_comb;
    always @(*) begin
        tmax_comb = 16'd0;
        for (ii = 0; ii < LAYERS; ii = ii + 1) begin
            if (temp_c_q[ii] > tmax_comb) tmax_comb = temp_c_q[ii];
        end
    end

    // ── lifecycle FSM advance ──────────────────────────────────
    always @(posedge clk_core or negedge rst_n) begin
        if (!rst_n) begin
            fsm_q           <= STATE_SAMPLE;
            layer_idx_q     <= 4'd0;
            temp_raw_q      <= 16'd0;
            max_temp_c_q    <= 16'd0;
            sample_count_q  <= 32'd0;
            dvfs_state_q    <= 4'h0;
            cattrip_latch_q <= 1'b0;
            irq_thermal_q   <= 1'b0;
            for (ii = 0; ii < LAYERS; ii = ii + 1)
                temp_c_q[ii] <= 16'd25;   // boot prior = 25 °C
        end else begin
            irq_thermal_q <= 1'b0;        // pulsed default
            case (fsm_q)
                STATE_SAMPLE: begin
                    // I²C SAMPLE phase: snapshot tsense_sda for layer_idx_q.
                    // (Real I²C engine TBD post-foundry-MOU; here we fake
                    //  the readout from the line state per the falsifier.)
                    temp_raw_q <= {12'd0, tsense_sda_in[layer_idx_q],
                                   3'b000} + 16'd25;
                    fsm_q      <= STATE_CONVERT;
                end
                STATE_CONVERT: begin
                    // Convert raw → °C (scale already applied above).
                    temp_c_q[layer_idx_q] <= temp_raw_q;
                    fsm_q                 <= STATE_FILTER;
                end
                STATE_FILTER: begin
                    // Update running max (Jacobi-style stencil hook).
                    if (temp_raw_q > max_temp_c_q)
                        max_temp_c_q <= temp_raw_q;
                    fsm_q <= STATE_REPORT;
                end
                STATE_REPORT: begin
                    // Compute DVFS state, latch CATTRIP, fire IRQ.
                    dvfs_state_q   <= encode_dvfs(tmax_comb);
                    if (tmax_comb >= T_TRIP_C) cattrip_latch_q <= 1'b1;
                    irq_thermal_q  <= 1'b1;
                    sample_count_q <= sample_count_q + 32'd1;
                    layer_idx_q    <= (layer_idx_q == LAYERS-1) ?
                                      4'd0 : layer_idx_q + 4'd1;
                    fsm_q          <= STATE_SAMPLE;
                end
            endcase
        end
    end

    assign dvfs_state    = dvfs_state_q;
    assign cattrip_latch = cattrip_latch_q;
    assign irq_thermal   = irq_thermal_q;

    // ── safety watchdog (~1 s @ 100 MHz core) ──────────────────
    //
    // Trip if no thermal sample in 100 M cycles. Counter resets on
    // each REPORT-stage retire. Sticky on assert.
    localparam integer WATCHDOG_LIMIT = 100_000_000;
    reg [31:0] watchdog_q;
    reg        watchdog_trip_q;

    always @(posedge clk_core or negedge rst_n) begin
        if (!rst_n) begin
            watchdog_q      <= 32'd0;
            watchdog_trip_q <= 1'b0;
        end else if (irq_thermal_q) begin
            watchdog_q      <= 32'd0;
            watchdog_trip_q <= 1'b0;
        end else if (watchdog_q >= WATCHDOG_LIMIT[31:0]) begin
            watchdog_trip_q <= 1'b1;
        end else begin
            watchdog_q <= watchdog_q + 32'd1;
        end
    end
    assign safety_watchdog_trip = watchdog_trip_q;

    // ── I²C bus tie-offs (read-only sample skeleton) ───────────
    assign tsense_scl    = clk_core;                    // skeleton: SCL = core clk
    assign tsense_sda_oe = {LAYERS{1'b0}};              // never drive (read-only)

    // ── HBM4 wide-bus tie-offs (BLACK BOX — paper only) ────────
    assign hbm_dq_out  = {2048{1'b0}};
    assign hbm_dqs     = 32'd0;
    assign hbm_reset_n = rst_n;

    // ── AXI4-Lite slave (read-only status registers) ───────────
    //
    // 0x00 : version          { sigma[31:24], tau[23:16], phi[15:8], n[7:0] }
    // 0x04 : fsm_state        { 0x000000, 0x0, fsm_q[3:0] }
    // 0x08 : max_temp_c
    // 0x0C : dvfs_state       { 0x0000_000, dvfs_state[3:0] }
    // 0x10 : cattrip_latch    { 0x0000_000, 0x0, cattrip_latch[0] }
    // 0x14 : sample_count
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
                    8'h04: r_data_q <= {28'd0, 2'b00, fsm_q};
                    8'h08: r_data_q <= {16'd0, max_temp_c_q};
                    8'h0C: r_data_q <= {28'd0, dvfs_state_q};
                    8'h10: r_data_q <= {31'd0, cattrip_latch_q};
                    8'h14: r_data_q <= sample_count_q;
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

endmodule

`default_nettype wire

// ── synthesis notes (Vivado 2024.1, XCKU040) ───────────────────────
//   - timing budget @ 100 MHz core: target slack ≥ +0.5 ns post-route.
//   - LUT estimate (XCKU040): ~ 2.5 K LUT + ~ 4 K FF for this skeleton.
//   - block RAMs: 0 (per-layer T regs synthesize to flops at LAYERS=16).
//   - MMCM consumes 1 of 6 available on XCKU040 PL.
//   - I²C engine left for Phase D iter 3+ (foundry MOU gated).
//   - HBM4 wide-bus paths held black-box; full PHY post SK Hynix MOU.
// ── falsifier link (board v0 spec §3) ──────────────────────────────
//   F-CHIP-3.D.a: dvfs_state != encode_dvfs(max_temp_c) → control loop drift
//   F-CHIP-3.D.b: cattrip_latch deasserts after T < 105 °C → not sticky
//   F-CHIP-3.D.c: watchdog never trips on synthetic stall → safety logic broken
//   F-CHIP-3.D.d: fsm_q outside [0..3] → τ=4 lifecycle axis broken
