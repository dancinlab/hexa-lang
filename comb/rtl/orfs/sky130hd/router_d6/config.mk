# ORFS config — router_d6 (degree-6 hex NoC router) · sky130hd
# comb T3 P&R · run inside openroad/orfs container.
export DESIGN_NAME      = router_d6
export DESIGN_NICKNAME  = router_d6
export PLATFORM         = sky130hd

export VERILOG_FILES    = $(DESIGN_HOME)/sky130hd/router_d6/router_d6.v
export SDC_FILE         = $(DESIGN_HOME)/sky130hd/router_d6/constraint.sdc

# router_d6 post-synth SKY130 area ≈ 93,609 µm² → low utilization for the
# ~900-bit IO pin ring; pin-limited small block.
export CORE_UTILIZATION = 25
export PLACE_DENSITY     = 0.55
export TNS_END_PERCENT   = 100
