# ORFS config — router_d4 (degree-4 mesh NoC router baseline) · sky130hd
# comb T3 P&R · run inside openroad/orfs container.
export DESIGN_NAME      = router_d4
export DESIGN_NICKNAME  = router_d4
export PLATFORM         = sky130hd

export VERILOG_FILES    = $(DESIGN_HOME)/sky130hd/router_d4/router_d4.v
export SDC_FILE         = $(DESIGN_HOME)/sky130hd/router_d4/constraint.sdc

# router_d4 post-synth SKY130 area ≈ 61,763 µm²; ~640-bit IO pin ring.
export CORE_UTILIZATION = 25
export PLACE_DENSITY     = 0.55
export TNS_END_PERCENT   = 100
