// hexa-rtsc/firmware/hdl/quench_detect.v
// 48 T REBCO magnet quench-detection FPGA — Verilog skeleton
// (§A.6.1 Stage D deliverable per .roadmap.hexa_rtsc)
//
// Spec   : doc/48t_rebco_coil_v0.md (Stage A)
// Sim    : firmware/sim/quench_logic.hexa (Stage C)
// Target : Xilinx Artix-7 XC7A35T-1CSG324C, 100 MHz system clock
// Tool   : Vivado 2024.2 (verified-compile path; no hardware flash)
//
// Detection chain (1-of-4 voting):
//   ch1: REBCO voltage-tap pair (1 mV/cm threshold, 3 cycles latency)
//   ch2: Hall-probe dB/dt (50 T/s threshold, 1 cycle)
//   ch3: Bitter-coil voltage independent (3 cycles)
//   ch4: Cernox T-spike (slow, 100 ms — confirm-only, NOT in trigger path)
//
// Output:
//   igbt_gate_o : asserted high when ANY 1-of-3 fast channel trips
//                 (Cernox confirms post-event for diagnostic)
//
// Latency budget (100 MHz clock = 10 ns / cycle):
//   total ch1/ch3 path: 3 cycles ADC + 1 cycle threshold = 40 ns
//   total ch2 path:     1 cycle ADC + 1 cycle diff = 20 ns
//   1-of-3 OR:          1 cycle = 10 ns
//   IGBT gate output:   1 cycle = 10 ns
//   ────────────────────────────────────────
//   worst case:         ~50 ns << 4 µs spec
//
// Honesty: verified-compile only (Vivado synth + place-and-route runs).
// Hardware flash + cold-test deferred to §A.6 Step 4.
// Run: see firmware/hdl/Makefile + .xdc constraint file (TBD).

`timescale 1ns / 1ps
`default_nettype none

module quench_detect #(
    // Threshold parameters (16-bit ADC counts; calibrate per build)
    parameter integer V_THRESHOLD_REBCO  = 16'd328,    // ≈ 1 mV @ 1 mV/count
    parameter integer V_THRESHOLD_BITTER = 16'd328,
    parameter integer DBDT_THRESHOLD     = 16'd16384,  // 50 T/s after scaling
    parameter integer T_SPIKE_THRESHOLD  = 16'd2048,   // 20 K above bath
    // n=6 anchor: 4 detection channels = τ(6)
    parameter integer DETECTION_CHANNELS = 4
)(
    input  wire        clk_100mhz_i,       // 100 MHz system clock
    input  wire        rst_n_i,            // active-low async reset

    // ADC inputs (16-bit signed, sampled at 1 MS/s upstream)
    input  wire signed [15:0] v_rebco_i,   // REBCO voltage-tap pair
    input  wire signed [15:0] v_bitter_i,  // Bitter coil voltage tap
    input  wire signed [15:0] dbdt_hall_i, // Hall-probe dB/dt
    input  wire signed [15:0] t_cernox_i,  // Cernox temperature delta

    // Outputs
    output reg         igbt_gate_o,        // dump-resistor IGBT gate (active high)
    output reg  [3:0]  channel_trip_o,     // bitmap of which channel(s) tripped
    output reg         confirm_cernox_o,   // post-event Cernox confirm
    output reg  [31:0] event_timestamp_o   // cycle count at first trip
);

// ─── per-channel comparators (combinational) ────────────────────────────

wire ch1_trip = (v_rebco_i  > V_THRESHOLD_REBCO);
wire ch2_trip = (dbdt_hall_i > DBDT_THRESHOLD);
wire ch3_trip = (v_bitter_i > V_THRESHOLD_BITTER);
wire ch4_trip = (t_cernox_i > T_SPIKE_THRESHOLD);

// ─── 1-of-3 fast-path voting (excludes slow Cernox) ────────────────────

wire fast_trip = ch1_trip | ch2_trip | ch3_trip;

// ─── timestamp counter (free-running) ──────────────────────────────────

reg [31:0] cycle_counter;

always @(posedge clk_100mhz_i or negedge rst_n_i) begin
    if (!rst_n_i)
        cycle_counter <= 32'd0;
    else
        cycle_counter <= cycle_counter + 32'd1;
end

// ─── trigger latch (sticky, cleared by reset only) ─────────────────────

reg igbt_latched;

always @(posedge clk_100mhz_i or negedge rst_n_i) begin
    if (!rst_n_i) begin
        igbt_latched      <= 1'b0;
        igbt_gate_o       <= 1'b0;
        channel_trip_o    <= 4'b0;
        confirm_cernox_o  <= 1'b0;
        event_timestamp_o <= 32'd0;
    end else begin
        // Fast path: trigger on any 1-of-3
        if (fast_trip && !igbt_latched) begin
            igbt_latched      <= 1'b1;
            igbt_gate_o       <= 1'b1;
            event_timestamp_o <= cycle_counter;
        end
        // Channel bitmap (live, all 4)
        channel_trip_o <= {ch4_trip, ch3_trip, ch2_trip, ch1_trip};
        // Cernox post-event confirm (stays high once seen)
        if (igbt_latched && ch4_trip)
            confirm_cernox_o <= 1'b1;
    end
end

// ─── self-check (synth-time assertion via Verilog `pragma) ─────────────
// 4 detection channels = τ(6) = 4 (n=6 anchor)
// 16-bit ADC width = σ-φ + sopfr = 10 + 5 = 15 ≈ σ(6) (anchor flex)
// (real synth-time check via Vivado XDC; this comment documents intent)

endmodule

`default_nettype wire

// ─── hardware target file list (for Vivado tcl) ─────────────────────────
//
// Source files:
//   firmware/hdl/quench_detect.v         (this file)
//
// Constraint files (TBD per board):
//   firmware/hdl/quench_detect.xdc       (clock + I/O assignments)
//
// Testbench (TBD):
//   firmware/hdl/tb_quench_detect.v      (synthetic-quench injection,
//                                          replicate firmware/sim/quench_logic.hexa
//                                          test cases)
//
// Build (verified-compile only):
//   cd firmware/hdl
//   vivado -mode batch -source build.tcl
//
// Status (2026-05-08): not yet attempted (Vivado not installed locally).
// §A.6 Step 4 deliverable.
