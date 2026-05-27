# hexa-cern/firmware/asic/timing_ctrl_sky130/config.tcl
#
# §A.6.1 step E4.1 — OpenLane configuration for the timing_ctrl ASIC.
# Run from this directory:  flow.tcl -design timing_ctrl_sky130
# Requires: OpenLane installed; SKY130 PDK at $PDK_ROOT/sky130A.

# ── design identification ─────────────────────────────────────────────
set ::env(DESIGN_NAME) "timing_ctrl_top"
set ::env(VERILOG_FILES) [list \
    "$::env(DESIGN_DIR)/../../../hdl/timing_ctrl.v" \
    "$::env(DESIGN_DIR)/../../../hdl/timing_ctrl_regs.v" \
    "$::env(DESIGN_DIR)/../../../hdl/timing_ctrl_top.v" \
    "$::env(DESIGN_DIR)/sky130_top.v" \
]

# ── clock + reset ────────────────────────────────────────────────────
set ::env(CLOCK_PORT)   "clk_i"
set ::env(CLOCK_PERIOD) "10.0"            ; # 100 MHz target
set ::env(CLOCK_NET)    "clk_i"

# ── floor-plan ───────────────────────────────────────────────────────
# Generous 75% utilization for skeleton; shrink later post-timing.
set ::env(FP_CORE_UTIL)            "30"
set ::env(FP_ASPECT_RATIO)         "1.0"
set ::env(FP_PDN_VPITCH)           "70"
set ::env(FP_PDN_HPITCH)           "70"

# ── synthesis ────────────────────────────────────────────────────────
set ::env(SYNTH_STRATEGY)          "AREA 0"   ; # area-optimised first pass
set ::env(SYNTH_MAX_FANOUT)        "5"

# ── place + route ────────────────────────────────────────────────────
set ::env(PL_TARGET_DENSITY)       "0.5"
set ::env(GLB_RT_ADJUSTMENT)       "0.10"

# ── clock tree synthesis ─────────────────────────────────────────────
set ::env(CTS_TARGET_SKEW)         "200"     ; # 200 ps target
set ::env(CTS_BUF_SIZE)            "8"

# ── DRC / LVS / STA / fill ───────────────────────────────────────────
set ::env(RUN_KLAYOUT_DRC)         "1"
set ::env(RUN_LVS)                 "1"
set ::env(RUN_FILL_INSERTION)      "1"
set ::env(RUN_TAPCELL)             "1"
set ::env(RUN_DIODE_INSERTION)     "1"

# ── pin order — match sky130_top.v order ─────────────────────────────
set ::env(FP_PIN_ORDER_CFG) "$::env(DESIGN_DIR)/pin_order.cfg"

# ── area target — keep this small (this is a controller, not an SoC) ─
# Estimated ~2 mm² post place-and-route based on Yosys cell-count
# projection: ~12 K standard cells × 1 µm² avg = 12k µm² + routing.
# Full chip including pad ring: ~3 mm × 3 mm = 9 mm².

# ── reports root ─────────────────────────────────────────────────────
set ::env(RUN_TAG) "v0.1.0-skeleton"
