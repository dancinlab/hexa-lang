# firmware/hdl/Makefile — open-source build (iverilog) + Vivado wrapper
#
# §A.6.1 Phase D+ deliverable.  Verified-compile only.
#
# Targets:
#   make sim              — iverilog testbench (open-source, runs today)
#   make synth            — Vivado synthesis (requires Vivado install)
#   make impl             — Vivado place-and-route + bitstream
#   make flash            — REFUSE (no board; per honesty contract)
#   make clean            — remove build artifacts

IVERILOG := iverilog
VVP      := vvp
VIVADO   := vivado

HDL_SRCS := quench_detect.v calorimetry_daq.v
SIM_SRCS := tb_quench_detect.v
TOP      := quench_detect

.PHONY: sim synth impl flash clean

sim: tb_quench
	$(VVP) tb_quench

tb_quench: $(SIM_SRCS) $(HDL_SRCS)
	$(IVERILOG) -o tb_quench $(SIM_SRCS) $(HDL_SRCS)

synth: build.tcl $(HDL_SRCS) constraints.xdc
	$(VIVADO) -mode batch -source build.tcl -tclargs synth

impl: build.tcl $(HDL_SRCS) constraints.xdc
	$(VIVADO) -mode batch -source build.tcl

flash:
	@echo "REFUSE: per .roadmap §A.6 Step 4 honesty contract,"
	@echo "       no physical board exists.  Skeleton only."
	@false

clean:
	rm -rf tb_quench build/
