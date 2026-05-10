# firmware/hdl/build.tcl — Vivado batch build script
#
# §A.6.1 Phase D+ deliverable.  Verified-compile only — no flash.
# Run:
#   cd firmware/hdl
#   vivado -mode batch -source build.tcl
#
# Output: build/{project}/{project}.runs/impl_1/{module}.bit
# (will fail to flash without physical XC7A35T board — by design,
#  per .roadmap §A.6 Step 4 "real-hardware flash + cold-test deferred")

set proj_name "hexa_rtsc_firmware"
set proj_dir  "./build"
set part      "xc7a35tcsg324-1"   ;# Artix-7 XC7A35T-1CSG324C

# Clean previous build
file delete -force $proj_dir

# Create project
create_project $proj_name $proj_dir -part $part -force

# Add HDL sources
set hdl_sources [list \
    "quench_detect.v" \
    "calorimetry_daq.v" \
]

foreach src $hdl_sources {
    if {[file exists $src]} {
        add_files $src
        puts "  [INFO] added source: $src"
    } else {
        puts "  [WARN] source not found: $src"
    }
}

# Add testbench (sim-only)
set sim_sources [list \
    "tb_quench_detect.v" \
]

foreach src $sim_sources {
    if {[file exists $src]} {
        add_files -fileset sim_1 $src
        puts "  [INFO] added sim source: $src"
    }
}

# Add constraint file
if {[file exists "constraints.xdc"]} {
    add_files -fileset constrs_1 "constraints.xdc"
    puts "  [INFO] added constraints"
}

# Set top module (default = quench_detect; override per build)
set_property top quench_detect [current_fileset]

# Synthesis
update_compile_order -fileset sources_1
launch_runs synth_1 -jobs 4
wait_on_run synth_1

if {[get_property PROGRESS [get_runs synth_1]] != "100%"} {
    puts "ERROR: synthesis failed"
    exit 1
}
puts "  [INFO] synthesis complete"

# Implementation
launch_runs impl_1 -jobs 4
wait_on_run impl_1

if {[get_property PROGRESS [get_runs impl_1]] != "100%"} {
    puts "ERROR: implementation failed"
    exit 1
}
puts "  [INFO] implementation complete"

# Generate bitstream
launch_runs impl_1 -to_step write_bitstream -jobs 4
wait_on_run impl_1

if {[file exists "$proj_dir/$proj_name.runs/impl_1/quench_detect.bit"]} {
    puts ""
    puts "  __HEXA_RTSC_HDL_BUILD__ PASS"
    puts "  bitstream: $proj_dir/$proj_name.runs/impl_1/quench_detect.bit"
    puts "  (NOT flashed — Stage D contract: verified-compile only)"
} else {
    puts "ERROR: bitstream not generated"
    exit 1
}
