# comb/rtl/pnr_run.tcl — OpenROAD P&R flow for hex/mesh router comparison
# 2026-05-18 · runs minimal RTL→placed flow. Routing skipped (heavy);
# placed layout + STA is enough for T3 design package.
#
# Usage (from comb/rtl/):
#   openroad -no_init pnr_run.tcl <design_name>
# where <design_name> ∈ {router_d4, router_d6}.
#
# Required inputs (in comb/rtl/):
#   pdk_files/sky130_fd_sc_hd.tech.tlef
#   pdk_files/sky130_fd_sc_hd.merged.lef
#   /tmp/sky130/.../sky130_fd_sc_hd__tt_025C_1v80.lib  (referenced via env)
#   synth_netlists/<design>.sky130.v
#   <design>.sdc

set design [lindex $argv 0]
if {$design eq ""} { set design router_d6 }

# === paths ===
set tech_lef pdk_files/sky130_fd_sc_hd.tech.tlef
set cells_lef pdk_files/sky130_fd_sc_hd.merged.lef
set liberty /tmp/sky130/skywater-pdk-libs-sky130_fd_sc_hd/timing/sky130_fd_sc_hd__tt_025C_1v80.lib
set netlist synth_netlists/${design}.sky130.v
set sdc ${design}.sdc
set out_dir pnr_out/${design}
exec mkdir -p $out_dir

# === load PDK + design ===
read_liberty $liberty
read_lef     $tech_lef
read_lef     $cells_lef
read_verilog $netlist
link_design  $design
read_sdc     $sdc

# === floorplan ===
# Generous die area (1000 x 1000 μm); core uses 95% of die.
# d6 needs ~94k μm² = ~0.094 mm² post-synth; 1mm² die is plenty.
initialize_floorplan \
    -die_area "0 0 1000 1000" \
    -core_area "10 10 990 990" \
    -site unithd

# === IO pin placement ===
place_pins -hor_layers met3 -ver_layers met2

# === global placement ===
global_placement -density 0.50 -init_density_penalty 0.001

# === detailed placement ===
detailed_placement

# === STA report (after place, no route) ===
report_design_area
report_checks -path_delay max -fields {slew cap input nets fanout} -group_path_count 5
report_worst_slack
report_tns
report_wns

# === outputs ===
write_def    $out_dir/${design}.placed.def
write_verilog -include_pwr_gnd $out_dir/${design}.placed.v
puts "DONE: P&R-place phase complete. outputs in $out_dir/"
puts "Next: detailed_route (heavy) + write GDSII (via klayout def→gds)"
