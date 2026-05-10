// hexa-cern/firmware/asic/timing_ctrl_sky130/sky130_top.v
//
// §A.6.1 step E4.1 — top-level wrapper for SKY130 IO pad ring.
// Wraps timing_ctrl_top with the SKY130 standard-cell IO pads
// (sky130_fd_io__top_*) for tape-out submission.
//
// The pad ring is intentionally minimal — sky130_fd_io has a richer
// set (analog, ESD-protected, level-shifter) that becomes relevant
// when the actual analog peripherals are migrated to silicon. For
// the digital-only timing_ctrl, the gpio_v2 pad covers all signals.
//
// **Skeleton**: this file references SKY130 black-box modules that
// land via OpenLane's PDK environment. It compiles *with PDK in
// scope*. Without PDK, treat as documentation of the intended
// chip-level IO topology.

`timescale 1 ns / 1 ps
`default_nettype none

module timing_ctrl_top_sky130 (
    // ── core supplies ─────────────────────────────────────────────────
    input  wire        VPWR,
    input  wire        VGND,
    input  wire        VPB,
    input  wire        VNB,

    // ── primary IO (one pad per signal) ──────────────────────────────
    input  wire        clk_i,
    input  wire        rstn_i,
    input  wire        hv_ok_i,
    input  wire        vacuum_ok_i,
    input  wire        water_ok_i,
    input  wire        laser_shutter_ok_i,

    // Wishbone — full 32-bit (use parallel pads + cycle/strobe/we/sel)
    input  wire        wb_cyc_i,
    input  wire        wb_stb_i,
    input  wire        wb_we_i,
    input  wire [31:0] wb_adr_i,
    input  wire [31:0] wb_dat_i,
    input  wire [3:0]  wb_sel_i,
    output wire        wb_ack_o,
    output wire        wb_err_o,
    output wire [31:0] wb_dat_o,

    output wire        tick_o,
    output wire        trigger_o,
    output wire        gate_o,
    output wire [31:0] tick_count_o,
    output wire        interlock_ok_o,
    output wire        irq_o
);

    // ── core instance ────────────────────────────────────────────────
    timing_ctrl_top u_core (
        .clk_i             (clk_i),
        .rstn_i            (rstn_i),
        .hv_ok_i           (hv_ok_i),
        .vacuum_ok_i       (vacuum_ok_i),
        .water_ok_i        (water_ok_i),
        .laser_shutter_ok_i(laser_shutter_ok_i),
        .wb_cyc_i          (wb_cyc_i),
        .wb_stb_i          (wb_stb_i),
        .wb_we_i           (wb_we_i),
        .wb_adr_i          (wb_adr_i),
        .wb_dat_i          (wb_dat_i),
        .wb_sel_i          (wb_sel_i),
        .wb_ack_o          (wb_ack_o),
        .wb_err_o          (wb_err_o),
        .wb_dat_o          (wb_dat_o),
        .tick_o            (tick_o),
        .trigger_o         (trigger_o),
        .gate_o            (gate_o),
        .tick_count_o      (tick_count_o),
        .interlock_ok_o    (interlock_ok_o),
        .irq_o             (irq_o)
    );

    // ── pad ring (placeholder for SKY130 sky130_fd_io__gpio_v2) ─────
    //
    // Real instantiation lands when OpenLane's PDK env is loaded.
    // The following comment shows the structure that synthesis sees.
    //
    //   sky130_fd_io__gpio_v2 pad_clk_i (
    //       .PAD       (pad_clk_i_pad),
    //       .OUT       (clk_i_int),
    //       .HLD_H_N   (1'b1), .ENABLE_H (1'b0), ... (full IO config)
    //   );
    //
    // For each input/output pin above, one pad_v2 instance lands here.
    // Pin order is determined by `pin_order.cfg`.

endmodule

`default_nettype wire
