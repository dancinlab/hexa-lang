// hexa-cern/firmware/hdl/timing_ctrl_regs.v
//
// §A.6.1 step E1.1 — register file + address decoder for the timing
// controller. Wishbone-classic 32-bit slave interface so an external
// MCU (firmware/mcu/) can read tick counters / interlock status and
// program D_TRIG / GATE_WIDTH at runtime.
//
// Address map (byte addresses, 4-byte aligned, 32-bit registers):
//
//   0x00  CTRL          [RW]  bit0=enable, bit1=soft_reset, bit2=force_tick
//   0x04  STATUS        [R]   bit0=interlock_ok, bit1=gate_active,
//                              bit2=trig_pending, bit3..7=reserved
//   0x08  TICK_COUNT    [R]   32-bit total tick count since reset
//   0x0C  D_TRIG        [RW]  trigger delay in cycles (default 100)
//   0x10  GATE_WIDTH    [RW]  gate width in cycles  (default 20)
//   0x14  TICK_DIVIDER  [RW]  divider value (default CLK_HZ/TICK_HZ)
//   0x18  INTERLOCK_RAW [R]   bit0=hv_ok, bit1=vacuum_ok, bit2=water_ok,
//                              bit3=shutter_ok
//   0x1C  IRQ_MASK      [RW]  bit0=interlock_drop, bit1=tick, bit2=fault
//   0x20  IRQ_PENDING   [R/W1C] same bit layout as IRQ_MASK
//   0x24  SCRATCH       [RW]  software scratch for boot-up self-test
//   0x28  N_TIER_LOCK   [R]   constant n=6 lattice (σ·φ=12·2=24 = J₂)
//   0x2C..0x3C reserved (read-as-zero)
//
// Addresses 0x40+ are decoded but ack-with-error (DAT_O = 0xDEAD_BEEF,
// ERR_O asserted).
//
// Skeleton-tag: this file is part of the §A.6.1 step E1 HDL completion.
// Compiles under Icarus Verilog and Vivado xsim, but does NOT bind to
// real silicon until §A.6 step 1+2 land a target FPGA.
//
// @see firmware/sim/timing_chain.hexa  (numerical model)
// @see firmware/hdl/timing_ctrl.v       (datapath this register file fronts)

`timescale 1 ns / 1 ps
`default_nettype none

module timing_ctrl_regs #(
    parameter integer CLK_HZ      = 100_000_000,
    parameter integer TICK_HZ     = 4,
    parameter integer DEFAULT_DTRIG = 100,
    parameter integer DEFAULT_GATEW = 20
) (
    // ── Wishbone classic slave ─────────────────────────────────────────
    input  wire         clk_i,
    input  wire         rstn_i,
    input  wire         wb_cyc_i,
    input  wire         wb_stb_i,
    input  wire         wb_we_i,
    input  wire [31:0]  wb_adr_i,
    input  wire [31:0]  wb_dat_i,
    input  wire [3:0]   wb_sel_i,           // byte enables (unused — full word)
    output reg          wb_ack_o,
    output reg          wb_err_o,
    output reg  [31:0]  wb_dat_o,

    // ── live status from datapath ──────────────────────────────────────
    input  wire         interlock_ok_i,
    input  wire         gate_active_i,
    input  wire         trigger_pending_i,
    input  wire [31:0]  tick_count_i,
    input  wire         hv_ok_i,
    input  wire         vacuum_ok_i,
    input  wire         water_ok_i,
    input  wire         shutter_ok_i,
    input  wire         tick_pulse_i,        // 1-cycle pulse on each tick

    // ── control to datapath ────────────────────────────────────────────
    output reg          enable_o,
    output reg          soft_reset_o,
    output reg          force_tick_o,
    output reg  [15:0]  d_trig_o,
    output reg  [15:0]  gate_width_o,
    output reg  [31:0]  tick_divider_o,

    // ── interrupt to MCU ───────────────────────────────────────────────
    output wire         irq_o
);

    // ── address constants ──────────────────────────────────────────────
    localparam [7:0] ADDR_CTRL        = 8'h00;
    localparam [7:0] ADDR_STATUS      = 8'h04;
    localparam [7:0] ADDR_TICK_COUNT  = 8'h08;
    localparam [7:0] ADDR_D_TRIG      = 8'h0C;
    localparam [7:0] ADDR_GATE_WIDTH  = 8'h10;
    localparam [7:0] ADDR_TICK_DIVIDER= 8'h14;
    localparam [7:0] ADDR_INTERLOCK_RAW = 8'h18;
    localparam [7:0] ADDR_IRQ_MASK    = 8'h1C;
    localparam [7:0] ADDR_IRQ_PENDING = 8'h20;
    localparam [7:0] ADDR_SCRATCH     = 8'h24;
    localparam [7:0] ADDR_N_TIER_LOCK = 8'h28;

    localparam [31:0] ERR_PATTERN     = 32'hDEAD_BEEF;
    localparam [31:0] N_TIER_LOCK_VAL = 32'h0000_0018;   // J₂ = 24 = 0x18

    // ── registers (writable) ───────────────────────────────────────────
    reg [31:0] ctrl_r;
    reg [15:0] d_trig_r;
    reg [15:0] gate_w_r;
    reg [31:0] tick_div_r;
    reg [2:0]  irq_mask_r;
    reg [2:0]  irq_pending_r;
    reg [31:0] scratch_r;
    reg        interlock_ok_d1;

    // soft_reset is auto-clearing (one-shot)
    reg        force_tick_oneshot;

    // ── decode + bus state machine ─────────────────────────────────────
    wire [7:0] addr8 = wb_adr_i[7:0];
    wire       sel   = wb_cyc_i & wb_stb_i;

    always @(posedge clk_i or negedge rstn_i) begin
        if (!rstn_i) begin
            ctrl_r            <= 32'd0;
            d_trig_r          <= DEFAULT_DTRIG[15:0];
            gate_w_r          <= DEFAULT_GATEW[15:0];
            tick_div_r        <= (CLK_HZ / TICK_HZ);
            irq_mask_r        <= 3'b000;
            irq_pending_r     <= 3'b000;
            interlock_ok_d1   <= 1'b1;     // assume OK at reset to avoid spurious edge
            scratch_r         <= 32'h0;
            wb_ack_o          <= 1'b0;
            wb_err_o          <= 1'b0;
            wb_dat_o          <= 32'd0;
            force_tick_oneshot <= 1'b0;
            enable_o          <= 1'b0;
            soft_reset_o      <= 1'b0;
            force_tick_o      <= 1'b0;
            d_trig_o          <= DEFAULT_DTRIG[15:0];
            gate_width_o      <= DEFAULT_GATEW[15:0];
            tick_divider_o    <= (CLK_HZ / TICK_HZ);
        end else begin
            // soft-reset auto-clears each cycle
            soft_reset_o <= 1'b0;
            force_tick_o <= force_tick_oneshot;
            force_tick_oneshot <= 1'b0;

            // forward CTRL bits to outputs
            enable_o       <= ctrl_r[0];
            d_trig_o       <= d_trig_r;
            gate_width_o   <= gate_w_r;
            tick_divider_o <= tick_div_r;

            // capture interrupts: edge-detect the relevant signals so the
            // pending bit can be cleared by W1C even if the underlying
            // condition persists (e.g. interlock stays down).
            interlock_ok_d1 <= interlock_ok_i;
            if (tick_pulse_i)                                  irq_pending_r[1] <= 1'b1;
            if (interlock_ok_d1 == 1'b1 && interlock_ok_i == 1'b0) irq_pending_r[0] <= 1'b1;
            // bit 2 (fault) reserved for future use

            // default Wishbone response
            wb_ack_o <= 1'b0;
            wb_err_o <= 1'b0;

            if (sel) begin
                wb_ack_o <= 1'b1;       // we always ACK in 1 cycle (no wait states)

                if (wb_we_i) begin
                    // write transactions
                    case (addr8)
                        ADDR_CTRL: begin
                            ctrl_r <= wb_dat_i;
                            if (wb_dat_i[1]) soft_reset_o <= 1'b1;
                            if (wb_dat_i[2]) force_tick_oneshot <= 1'b1;
                        end
                        ADDR_D_TRIG:        d_trig_r <= wb_dat_i[15:0];
                        ADDR_GATE_WIDTH:    gate_w_r <= wb_dat_i[15:0];
                        ADDR_TICK_DIVIDER:  tick_div_r <= wb_dat_i;
                        ADDR_IRQ_MASK:      irq_mask_r <= wb_dat_i[2:0];
                        ADDR_IRQ_PENDING:   irq_pending_r <= irq_pending_r & ~wb_dat_i[2:0]; // W1C
                        ADDR_SCRATCH:       scratch_r <= wb_dat_i;
                        default: begin
                            // out-of-range or read-only register
                            wb_err_o <= 1'b1;
                        end
                    endcase
                end else begin
                    // read transactions
                    case (addr8)
                        ADDR_CTRL:        wb_dat_o <= ctrl_r;
                        ADDR_STATUS:      wb_dat_o <= {29'd0, trigger_pending_i, gate_active_i, interlock_ok_i};
                        ADDR_TICK_COUNT:  wb_dat_o <= tick_count_i;
                        ADDR_D_TRIG:      wb_dat_o <= {16'd0, d_trig_r};
                        ADDR_GATE_WIDTH:  wb_dat_o <= {16'd0, gate_w_r};
                        ADDR_TICK_DIVIDER:wb_dat_o <= tick_div_r;
                        ADDR_INTERLOCK_RAW: wb_dat_o <= {28'd0, shutter_ok_i, water_ok_i, vacuum_ok_i, hv_ok_i};
                        ADDR_IRQ_MASK:    wb_dat_o <= {29'd0, irq_mask_r};
                        ADDR_IRQ_PENDING: wb_dat_o <= {29'd0, irq_pending_r};
                        ADDR_SCRATCH:     wb_dat_o <= scratch_r;
                        ADDR_N_TIER_LOCK: wb_dat_o <= N_TIER_LOCK_VAL;
                        default: begin
                            wb_dat_o <= ERR_PATTERN;
                            wb_err_o <= 1'b1;
                        end
                    endcase
                end
            end
        end
    end

    // IRQ aggregation: pending & mask
    assign irq_o = |(irq_pending_r & irq_mask_r);

endmodule

`default_nettype wire
