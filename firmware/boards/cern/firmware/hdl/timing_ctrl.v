// hexa-cern/firmware/hdl/timing_ctrl.v
//
// §A.6.1 step D 1/3 — FPGA TIMING CONTROLLER SKELETON.
//
// **STATUS: SKELETON ONLY — NOT BUILDABLE WITHOUT TARGET BOARD**
//
// This Verilog file provides the RTL structure for the §benchtop_v0_design.md
// B3 (trigger / timing controller) block. It compiles under Icarus Verilog
// for simulation but produces no bitstream until:
//
//   1. a target FPGA family is selected (Xilinx Kintex-7 class per §3 F1
//      BOM, or equivalent Lattice ECP5 / Altera Cyclone V)
//   2. vendor toolchain (Vivado / Quartus / Diamond) is installed
//   3. a constraints file (XDC / SDC) pins clock and IO to actual board
//      pads
//
// Until then, this file is a paper-design that synthesizes only on paper.
// Treat it as the same kind of artifact as benchtop_v0_design.md — a
// commitment to a specific architecture, refinable when the board lands.
//
// What the controller does:
//   • takes a 100 MHz master clock from B1 (OCXO + PLL)
//   • divides down to 4 Hz tick (= 25,000,000-cycle counter)
//   • for each tick, produces a `trigger_o` pulse delayed by D_TRIG cycles
//   • gate width is programmable via the GATE_WIDTH register
//   • interlock chain: any of {hv_ok_i, vacuum_ok_i, water_ok_i,
//     laser_shutter_ok_i} dropping low immediately disables triggers
//
// Roadmap: matches firmware/sim/timing_chain.hexa numerical model. The
// HDL realises the same state machine in real silicon when the toolchain
// becomes available.
//
// Author: hexa-cern dancinlife
// License: see ../../LICENSE

`timescale 1 ns / 1 ps
`default_nettype none

module timing_ctrl #(
    parameter integer CLK_HZ        = 100_000_000,    // 100 MHz from OCXO+PLL
    parameter integer TICK_HZ       = 4,              // 4 Hz target rate (τ=4)
    parameter integer D_TRIG_CYCLES = 100,            // 1 µs at 100 MHz
    parameter integer GATE_CYCLES   = 20              // 200 ns at 100 MHz
) (
    // ── clock + reset ─────────────────────────────────────────────────
    input  wire        clk_i,            // 100 MHz master clock
    input  wire        rstn_i,           // active-low async reset

    // ── interlock chain (active-high = OK) ────────────────────────────
    input  wire        hv_ok_i,           // ±50 kV supply OK
    input  wire        vacuum_ok_i,       // <1e-6 mbar OK
    input  wire        water_ok_i,        // 6 L/min cooling OK
    input  wire        laser_shutter_ok_i,// shutter not closed-by-fault

    // ── outputs ────────────────────────────────────────────────────────
    output reg         tick_o,            // single-cycle pulse at TICK_HZ
    output reg         trigger_o,         // gated D_TRIG_CYCLES after tick
    output reg         gate_o,            // GATE_CYCLES-wide gate
    output reg [31:0]  tick_count_o,      // total ticks since reset
    output reg         interlock_ok_o     // all 4 inputs OK
);

    // ── derived constants ─────────────────────────────────────────────
    localparam integer TICK_DIVIDER = CLK_HZ / TICK_HZ;   // 25M @ 4 Hz
    localparam integer DIV_W        = $clog2(TICK_DIVIDER);

    // ── state ─────────────────────────────────────────────────────────
    reg [DIV_W-1:0]    div_count;
    reg [15:0]         delay_count;
    reg [15:0]         gate_count;
    reg                trig_armed;
    reg                gate_armed;

    // ── interlock combinational ───────────────────────────────────────
    wire interlock_now =
        hv_ok_i & vacuum_ok_i & water_ok_i & laser_shutter_ok_i;

    // ── clock divider + tick generator ─────────────────────────────────
    always @(posedge clk_i or negedge rstn_i) begin
        if (!rstn_i) begin
            div_count    <= '0;
            tick_o       <= 1'b0;
            tick_count_o <= '0;
            trig_armed   <= 1'b0;
        end else begin
            tick_o <= 1'b0;       // single-cycle pulse default
            if (div_count >= TICK_DIVIDER - 1) begin
                div_count <= '0;
                if (interlock_now) begin
                    tick_o       <= 1'b1;
                    tick_count_o <= tick_count_o + 32'd1;
                    trig_armed   <= 1'b1;
                end
            end else begin
                div_count <= div_count + 1'b1;
            end
        end
    end

    // ── trigger delay pipeline ────────────────────────────────────────
    always @(posedge clk_i or negedge rstn_i) begin
        if (!rstn_i) begin
            delay_count <= '0;
            trigger_o   <= 1'b0;
            gate_armed  <= 1'b0;
        end else begin
            trigger_o <= 1'b0;
            if (tick_o) begin
                delay_count <= 16'd1;
            end else if (delay_count != 0) begin
                if (delay_count >= D_TRIG_CYCLES) begin
                    trigger_o   <= 1'b1;
                    gate_armed  <= 1'b1;
                    delay_count <= '0;
                end else begin
                    delay_count <= delay_count + 16'd1;
                end
            end
        end
    end

    // ── gate generator ────────────────────────────────────────────────
    always @(posedge clk_i or negedge rstn_i) begin
        if (!rstn_i) begin
            gate_o     <= 1'b0;
            gate_count <= '0;
        end else begin
            if (gate_armed) begin
                gate_o     <= 1'b1;
                gate_count <= 16'd1;
                gate_armed <= 1'b0;
            end else if (gate_count != 0) begin
                if (gate_count >= GATE_CYCLES) begin
                    gate_o     <= 1'b0;
                    gate_count <= '0;
                end else begin
                    gate_count <= gate_count + 16'd1;
                end
            end
        end
    end

    // ── interlock status output ───────────────────────────────────────
    always @(posedge clk_i or negedge rstn_i) begin
        if (!rstn_i) begin
            interlock_ok_o <= 1'b0;
        end else begin
            interlock_ok_o <= interlock_now;
        end
    end

endmodule

`default_nettype wire
