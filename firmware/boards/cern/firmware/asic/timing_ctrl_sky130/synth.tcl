# hexa-cern/firmware/asic/timing_ctrl_sky130/synth.tcl
#
# §A.6.1 step E4.1 — Yosys synthesis-only entry. Standalone use:
#   yosys -c synth.tcl
# Produces target/synth.v (gate-level netlist) + target/synth_stats.txt.
# Runs in ~5 min on commodity hardware.

# Source files (read in dependency order — leaves first)
read_verilog -sv ../../hdl/timing_ctrl.v
read_verilog -sv ../../hdl/timing_ctrl_regs.v
read_verilog -sv ../../hdl/timing_ctrl_top.v
read_verilog -sv sky130_top.v

# Synthesis to a generic gate-level netlist (no SKY130 mapping yet).
# OpenLane's `flow.tcl` does the ABC technology mapping in a separate
# pass with the SKY130 stdcell library.
synth -top timing_ctrl_top_sky130

# Estimate gate count (this is the only metric we can produce without
# the full PDK flow).
stat -tech sky130 -liberty $::env(LIB_FILE_PATH)

# Write generic gate-level netlist.
write_verilog -noattr -nohex -nodec target/synth.v

# Stats summary
tee -o target/synth_stats.txt stat
