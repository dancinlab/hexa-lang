# firmware/hdl/build.tcl — Vivado batch build entry (Phase D placeholder).
# Usage:  vivado -mode batch -source build.tcl
#
# Each project sets target FPGA + sources + constraints.  Real bitstream
# requires board-specific .xdc constraints which depend on the actual
# PCB pinout — to be generated from firmware/doc/board_v0_*.md.

set BOARDS {
    {penning_rf      xczu9eg-ffvc900-1}
    {atomic_clock    xcku040-ffva1156-1}
    {thrust_acq      xcvu13p-flga2577-1}
}

foreach b $BOARDS {
    set name [lindex $b 0]
    set part [lindex $b 1]
    puts "\n=== Building: $name (part: $part) ==="

    create_project -force ${name} ./build/${name} -part $part
    add_files -norecurse ${name}.v
    # add_files -norecurse -fileset constrs_1 ${name}.xdc      # generated from board_v0_*.md
    update_compile_order -fileset sources_1

    # synth_design -top ${name}_top
    # opt_design
    # place_design
    # route_design
    # write_bitstream -force ./build/${name}/${name}.bit

    puts "(skeleton — no bitstream until .xdc constraints generated)"
    close_project
}

puts "\n=== Done. ==="
