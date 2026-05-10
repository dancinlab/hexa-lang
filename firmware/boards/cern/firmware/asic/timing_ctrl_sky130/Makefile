# hexa-cern/firmware/asic/timing_ctrl_sky130/Makefile
#
# §A.6.1 step E4.1 — ASIC flow harness. Status-aware: each target
# checks for required tooling and prints a clear blocking message
# if not installed.

YOSYS    := $(shell command -v yosys    2>/dev/null)
OPENROAD := $(shell command -v openroad 2>/dev/null)
KLAYOUT  := $(shell command -v klayout  2>/dev/null)
MAGIC    := $(shell command -v magic    2>/dev/null)
NETGEN   := $(shell command -v netgen   2>/dev/null)

PDK_ROOT ?= /opt/pdks
SKY130A  := $(PDK_ROOT)/sky130A

.DEFAULT_GOAL := help

.PHONY: help
help:    ## list targets and tooling status
	@echo "hexa-cern/firmware/asic/ — SkyWater 130nm flow"
	@echo
	@echo "Tooling status:"
	@echo "  yosys     $(if $(YOSYS),OK,NOT FOUND)"
	@echo "  openroad  $(if $(OPENROAD),OK,NOT FOUND)"
	@echo "  klayout   $(if $(KLAYOUT),OK,NOT FOUND)"
	@echo "  magic     $(if $(MAGIC),OK,NOT FOUND)"
	@echo "  netgen    $(if $(NETGEN),OK,NOT FOUND)"
	@echo "  PDK root  $(SKY130A) $(if $(wildcard $(SKY130A)/.),OK,MISSING)"
	@echo
	@echo "Targets:"
	@echo "  make synth           ⚠  Yosys synthesis     (needs yosys + sky130A)"
	@echo "  make floorplan       ⚠  OpenROAD floorplan  (needs openroad)"
	@echo "  make place-route     ⚠  PnR + CTS + global routing"
	@echo "  make sta             ⚠  Static timing analysis"
	@echo "  make drc             ⚠  Magic DRC clean check"
	@echo "  make lvs             ⚠  Netgen LVS check"
	@echo "  make gds             ⚠  Final GDS export"
	@echo "  make all             ⚠  Full flow (= submission-ready GDS)"
	@echo
	@echo "Estimated time on 8-core x86_64 + 32 GB RAM:"
	@echo "  synth       ~5 min     gds       ~3 min"
	@echo "  floorplan   ~2 min     ──── total: ~6 hours full flow"
	@echo "  place+rt    ~3 hours    ────"
	@echo "  CTS         ~30 min"
	@echo "  STA         ~10 min"
	@echo "  DRC + LVS   ~2 hours"

.PHONY: synth
synth:    ## Yosys synthesis only
ifeq ($(YOSYS),)
	@echo "[synth] BLOCKED — yosys not installed (apt install yosys-suite)" >&2
	@exit 2
else
	$(YOSYS) -c synth.tcl
endif

.PHONY: floorplan place-route sta drc lvs gds all
floorplan place-route sta drc lvs gds all:
	@echo "[$@] BLOCKED — full OpenLane flow not implemented in skeleton"
	@echo "             see README.md 'Path to GDS (when funded)'"
	@exit 3
