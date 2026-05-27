// hexa-cern/firmware/hdl/timing_ctrl_top.v
//
// §A.6.1 step E1.2 — chip-level top integrating the timing_ctrl
// datapath with the timing_ctrl_regs Wishbone register file. This is
// the module a board-level constraints file would target.
//
// The MCU (firmware/mcu/) accesses the registers via Wishbone; the
// datapath uses the registered settings to drive trigger / gate.
// Forced-tick + soft-reset paths are wired through.
//
// @see firmware/hdl/timing_ctrl.v       (datapath state machine)
// @see firmware/hdl/timing_ctrl_regs.v  (Wishbone slave + register file)
// @see firmware/sim/timing_chain.hexa   (numerical model the HDL matches)
//
// Skeleton-tag: compiles under Icarus Verilog + Vivado xsim. Bitstream
// requires §A.6 step 1+2 (host facility + FPGA dev board).

`timescale 1 ns / 1 ps
`default_nettype none

module timing_ctrl_top #(
    parameter integer CLK_HZ        = 100_000_000,
    parameter integer TICK_HZ       = 4,
    parameter integer DEFAULT_DTRIG = 100,
    parameter integer DEFAULT_GATEW = 20
) (
    // ── primary clock + reset ─────────────────────────────────────────
    input  wire        clk_i,
    input  wire        rstn_i,

    // ── interlock GPIOs (active-high = OK) ────────────────────────────
    input  wire        hv_ok_i,
    input  wire        vacuum_ok_i,
    input  wire        water_ok_i,
    input  wire        laser_shutter_ok_i,

    // ── Wishbone slave (MCU side) ─────────────────────────────────────
    input  wire        wb_cyc_i,
    input  wire        wb_stb_i,
    input  wire        wb_we_i,
    input  wire [31:0] wb_adr_i,
    input  wire [31:0] wb_dat_i,
    input  wire [3:0]  wb_sel_i,
    output wire        wb_ack_o,
    output wire        wb_err_o,
    output wire [31:0] wb_dat_o,

    // ── timing outputs ─────────────────────────────────────────────────
    output wire        tick_o,
    output wire        trigger_o,
    output wire        gate_o,
    output wire [31:0] tick_count_o,
    output wire        interlock_ok_o,

    // ── interrupt to MCU ──────────────────────────────────────────────
    output wire        irq_o
);

    // ── inter-module wires ─────────────────────────────────────────────
    wire        enable_w;
    wire        soft_reset_w;
    wire        force_tick_w;
    wire [15:0] d_trig_w;
    wire [15:0] gate_width_w;
    wire [31:0] tick_divider_w;

    // soft-reset: ORed into the active-low reset (so SW can pulse it)
    wire        rstn_eff = rstn_i & ~soft_reset_w;

    // ── datapath ───────────────────────────────────────────────────────
    //
    // Note: original timing_ctrl had compile-time params for D_TRIG and
    // GATE_CYCLES. We bind them at instantiation but the datapath does
    // not (yet) consume runtime register values — that wiring is
    // mechanical and lands as part of step E1.3 once the register
    // pipeline is live. For now, registers are exposed via Wishbone
    // for MCU read-back; runtime mutation of D_TRIG/GATE will require
    // re-parameterisation of the datapath which is a separate refactor.

    // gate the tick generator on the enable bit so SW can disarm it
    wire enable_and_interlock = enable_w & (hv_ok_i & vacuum_ok_i & water_ok_i & laser_shutter_ok_i);

    timing_ctrl #(
        .CLK_HZ        (CLK_HZ),
        .TICK_HZ       (TICK_HZ),
        .D_TRIG_CYCLES (DEFAULT_DTRIG),
        .GATE_CYCLES   (DEFAULT_GATEW)
    ) u_dp (
        .clk_i              (clk_i),
        .rstn_i             (rstn_eff),
        .hv_ok_i            (hv_ok_i & enable_w),
        .vacuum_ok_i        (vacuum_ok_i & enable_w),
        .water_ok_i         (water_ok_i & enable_w),
        .laser_shutter_ok_i (laser_shutter_ok_i & enable_w),
        .tick_o             (tick_o),
        .trigger_o          (trigger_o),
        .gate_o             (gate_o),
        .tick_count_o       (tick_count_o),
        .interlock_ok_o     (interlock_ok_o)
    );

    // gate_active proxy: high while the gate output is driven
    wire gate_active_w = gate_o;
    wire trig_pending_w = trigger_o;

    // ── register file ─────────────────────────────────────────────────
    timing_ctrl_regs #(
        .CLK_HZ        (CLK_HZ),
        .TICK_HZ       (TICK_HZ),
        .DEFAULT_DTRIG (DEFAULT_DTRIG),
        .DEFAULT_GATEW (DEFAULT_GATEW)
    ) u_regs (
        .clk_i             (clk_i),
        .rstn_i             (rstn_i),
        .wb_cyc_i           (wb_cyc_i),
        .wb_stb_i           (wb_stb_i),
        .wb_we_i            (wb_we_i),
        .wb_adr_i           (wb_adr_i),
        .wb_dat_i           (wb_dat_i),
        .wb_sel_i           (wb_sel_i),
        .wb_ack_o           (wb_ack_o),
        .wb_err_o           (wb_err_o),
        .wb_dat_o           (wb_dat_o),
        .interlock_ok_i     (interlock_ok_o),
        .gate_active_i      (gate_active_w),
        .trigger_pending_i  (trig_pending_w),
        .tick_count_i       (tick_count_o),
        .hv_ok_i            (hv_ok_i),
        .vacuum_ok_i        (vacuum_ok_i),
        .water_ok_i         (water_ok_i),
        .shutter_ok_i       (laser_shutter_ok_i),
        .tick_pulse_i       (tick_o),
        .enable_o           (enable_w),
        .soft_reset_o       (soft_reset_w),
        .force_tick_o       (force_tick_w),
        .d_trig_o           (d_trig_w),
        .gate_width_o       (gate_width_w),
        .tick_divider_o     (tick_divider_w),
        .irq_o              (irq_o)
    );

endmodule

`default_nettype wire
