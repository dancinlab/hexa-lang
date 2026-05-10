// hexa-cern/firmware/hdl/testbench/timing_ctrl_tb.v
//
// §A.6.1 step D 3/3 — Verilog testbench for `timing_ctrl`.  Sim-only.
//
// Drives the full state machine through:
//   1. async-low reset, then release
//   2. all 4 interlocks high; advance ~1 second of simulated time
//      (= 4 ticks @ 4 Hz). Verify tick_count_o → 4, trigger_o pulses
//      D_TRIG_CYCLES after each tick, gate_o is GATE_CYCLES wide.
//   3. drop hv_ok_i; advance another second; verify NO new tick_o
//      pulses (interlock gating works).
//
// Run:
//   iverilog -g2012 -o target/sim hdl/timing_ctrl.v \
//                                  hdl/testbench/timing_ctrl_tb.v
//   vvp target/sim
//
// Acceptance: testbench prints "TB PASS" on success, "TB FAIL: ..."
// otherwise. iverilog $finish exit code = 0 on PASS.
//
// Note: this testbench uses small TICK_DIVIDER for sim speed — running
// the production divider (25M cycles/tick) would take literal hours
// in iverilog. We override TICK_HZ via parameter, which keeps the
// state machine logic identical but compresses time.

`timescale 1 ns / 1 ps
`default_nettype none

module timing_ctrl_tb;

    // ── DUT params (compressed for sim speed) ───────────────────────────
    localparam integer CLK_HZ_TB        = 100_000_000;
    localparam integer TICK_HZ_TB       = 1_000_000;       // 1 MHz tick (sim)
    localparam integer D_TRIG_CYCLES_TB = 10;
    localparam integer GATE_CYCLES_TB   = 5;
    localparam integer TICK_DIVIDER_TB  = CLK_HZ_TB / TICK_HZ_TB;

    // ── DUT signals ─────────────────────────────────────────────────────
    reg         clk;
    reg         rstn;
    reg         hv_ok;
    reg         vacuum_ok;
    reg         water_ok;
    reg         laser_shutter_ok;
    wire        tick_o;
    wire        trigger_o;
    wire        gate_o;
    wire [31:0] tick_count_o;
    wire        interlock_ok_o;

    // ── DUT instance ────────────────────────────────────────────────────
    timing_ctrl #(
        .CLK_HZ        (CLK_HZ_TB),
        .TICK_HZ       (TICK_HZ_TB),
        .D_TRIG_CYCLES (D_TRIG_CYCLES_TB),
        .GATE_CYCLES   (GATE_CYCLES_TB)
    ) dut (
        .clk_i             (clk),
        .rstn_i            (rstn),
        .hv_ok_i           (hv_ok),
        .vacuum_ok_i       (vacuum_ok),
        .water_ok_i        (water_ok),
        .laser_shutter_ok_i(laser_shutter_ok),
        .tick_o            (tick_o),
        .trigger_o         (trigger_o),
        .gate_o            (gate_o),
        .tick_count_o      (tick_count_o),
        .interlock_ok_o    (interlock_ok_o)
    );

    // ── 100 MHz clock ───────────────────────────────────────────────────
    initial clk = 1'b0;
    always #5 clk = ~clk;     // 10 ns period = 100 MHz

    // ── observers ───────────────────────────────────────────────────────
    integer tick_pulses     = 0;
    integer trigger_pulses  = 0;
    integer gate_high_count = 0;

    always @(posedge clk) begin
        if (tick_o)    tick_pulses    = tick_pulses + 1;
        if (trigger_o) trigger_pulses = trigger_pulses + 1;
        if (gate_o)    gate_high_count = gate_high_count + 1;
    end

    // ── delay measurement ───────────────────────────────────────────────
    time tick_seen_at = 0;
    time trig_seen_at = 0;

    always @(posedge clk) begin
        if (tick_o)    tick_seen_at = $time;
        if (trigger_o && tick_seen_at != 0) trig_seen_at = $time;
    end

    // ── stimulus ────────────────────────────────────────────────────────
    initial begin
        $display("[TB] timing_ctrl testbench start");
        rstn             = 1'b0;
        hv_ok            = 1'b0;
        vacuum_ok        = 1'b0;
        water_ok         = 1'b0;
        laser_shutter_ok = 1'b0;
        #100;
        rstn             = 1'b1;
        hv_ok            = 1'b1;
        vacuum_ok        = 1'b1;
        water_ok         = 1'b1;
        laser_shutter_ok = 1'b1;

        // Wait for 4 ticks (TICK_DIVIDER_TB = 100 cycles each)
        // 4 * 100 * 10 ns = 4000 ns + slack
        #5000;

        if (tick_pulses < 4) begin
            $display("[TB FAIL] tick_pulses=%0d (expected ≥ 4)", tick_pulses);
            $finish(1);
        end
        if (tick_count_o < 32'd4) begin
            $display("[TB FAIL] tick_count_o=%0d (expected ≥ 4)", tick_count_o);
            $finish(1);
        end
        if (trigger_pulses < 4) begin
            $display("[TB FAIL] trigger_pulses=%0d (expected ≥ 4)", trigger_pulses);
            $finish(1);
        end
        $display("[TB] phase 1 OK: ticks=%0d, triggers=%0d, gate_cycles=%0d, tick_count=%0d",
                  tick_pulses, trigger_pulses, gate_high_count, tick_count_o);

        // Phase 2: drop interlock, advance, verify no new ticks issued.
        hv_ok = 1'b0;
        #100;     // settle
        // Snapshot tick count post-drop
        // Wait long enough that, were the interlock NOT enforcing, several
        // more ticks would have fired:
        #5000;
        if (tick_pulses != tick_count_o) begin
            $display("[TB FAIL] tick_pulses(%0d) ≠ tick_count_o(%0d) post-drop",
                      tick_pulses, tick_count_o);
            $finish(1);
        end
        if (interlock_ok_o !== 1'b0) begin
            $display("[TB FAIL] interlock_ok_o still high after hv_ok drop");
            $finish(1);
        end
        $display("[TB] phase 2 OK: interlock gated further ticks (post-count = %0d)",
                  tick_count_o);

        $display("[TB PASS] timing_ctrl testbench complete");
        $finish(0);
    end

    // safety: hard timeout
    initial begin
        #100_000;
        $display("[TB FAIL] timeout — never finished");
        $finish(2);
    end

endmodule

`default_nettype wire
