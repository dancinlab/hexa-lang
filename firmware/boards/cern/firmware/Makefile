# hexa-cern/firmware/Makefile — §A.6.1 step D 3/3
#
# Build scaffolding for the firmware/* tree. Each target is annotated
# with its "buildable now?" status:
#
#   ✓ buildable        — runs against in-repo files only
#   ⚠  toolchain-needed — needs external tool (icarus-verilog / cargo / etc)
#   ✗ board-needed     — produces nothing useful without target hardware
#
# **Most targets are toolchain-needed or board-needed.** The default `help`
# target is always safe to run.

# ── platform discovery ────────────────────────────────────────────────────
HEXA_REAL ?= $(HOME)/.hx/packages/hexa/hexa.real
PETITE_CERN_ROOT ?= $(realpath $(CURDIR)/..)
ENV_RUN := HEXA_SHIM_NO_DARWIN_LANDING=1 RESOURCE_LOCAL_HEXA=1 PETITE_CERN_ROOT=$(PETITE_CERN_ROOT)

IVERILOG := $(shell command -v iverilog 2>/dev/null)
VVP      := $(shell command -v vvp      2>/dev/null)
CARGO    := $(shell command -v cargo    2>/dev/null)
NGSPICE  := $(shell command -v ngspice  2>/dev/null)

.DEFAULT_GOAL := help

# ── targets ───────────────────────────────────────────────────────────────

.PHONY: help
help:    ## list targets and their status
	@echo "hexa-cern firmware/  build scaffolding (§A.6.1 step D 3/3)"
	@echo
	@echo "Status legend:  ✓ buildable now    ⚠  needs toolchain    ✗ needs board"
	@echo
	@echo "  make sim-hexa            ✓  run all firmware/sim/*.hexa  (numerical)"
	@echo "  make sim-iverilog        ⚠  simulate firmware/hdl/*.v with Icarus"
	@echo "                              ($(if $(IVERILOG),iverilog OK,iverilog NOT FOUND))"
	@echo "  make cargo-check         ⚠  cargo check + build firmware/mcu/  ($(if $(CARGO),cargo OK,cargo NOT FOUND))"
	@echo "  make lint                ✓  basic syntax sweep (.hexa/.v/.rs)"
	@echo "  make sim-ngspice         ⚠  EMC pre-compliance ngspice run  ($(if $(NGSPICE),ngspice OK,ngspice NOT FOUND))"
	@echo "  make build-bitstream     ✗  Vivado/Quartus + board pinout (placeholder)"
	@echo "  make flash-mcu           ✗  probe-rs + dev-board (placeholder)"
	@echo
	@echo "Sim-only files: firmware/sim/*.hexa  (4 modules)"
	@echo "HDL skeleton:   firmware/hdl/timing_ctrl.v"
	@echo "MCU skeleton:   firmware/mcu/src/main.rs"

.PHONY: sim-hexa
sim-hexa:    ## run all firmware/sim/*.hexa scripts
	@echo "[sim-hexa] running 4 firmware/sim/* numerical models"
	@$(ENV_RUN) HEXA_CERN_OFFLINE=1 $(HEXA_REAL) run sim/timing_chain.hexa
	@$(ENV_RUN) HEXA_CERN_OFFLINE=1 $(HEXA_REAL) run sim/dac_chain.hexa
	@$(ENV_RUN) HEXA_CERN_OFFLINE=1 $(HEXA_REAL) run sim/adc_chain.hexa
	@$(ENV_RUN) HEXA_CERN_OFFLINE=1 $(HEXA_REAL) run sim/control_loop.hexa
	@echo "[sim-hexa] done"

.PHONY: sim-iverilog
sim-iverilog:    ## simulate timing_ctrl.v + regs with Icarus + run testbenches
ifeq ($(IVERILOG),)
	@echo "[sim-iverilog] iverilog NOT INSTALLED — install icarus-verilog (apt/brew)" >&2
	@exit 2
else
	@mkdir -p target
	@echo "[sim-iverilog] timing_ctrl_tb.v"
	$(IVERILOG) -g2012 -o target/timing_ctrl_sim \
	    hdl/timing_ctrl.v hdl/testbench/timing_ctrl_tb.v
	$(VVP) target/timing_ctrl_sim
	@echo "[sim-iverilog] timing_ctrl_regs_tb.v"
	$(IVERILOG) -g2012 -o target/regs_sim \
	    hdl/timing_ctrl_regs.v hdl/testbench/timing_ctrl_regs_tb.v
	$(VVP) target/regs_sim
	@echo "[sim-iverilog] timing_ctrl_top_tb.v"
	$(IVERILOG) -g2012 -o target/top_sim \
	    hdl/timing_ctrl.v hdl/timing_ctrl_regs.v hdl/timing_ctrl_top.v \
	    hdl/testbench/timing_ctrl_top_tb.v
	$(VVP) target/top_sim
endif

.PHONY: cargo-check
cargo-check:    ## cargo check + build the MCU firmware (binary in target/)
ifeq ($(CARGO),)
	@echo "[cargo-check] cargo NOT INSTALLED — install rustup" >&2
	@exit 2
else
	@cd mcu && $(CARGO) check --target thumbv7em-none-eabihf
	@echo "[cargo-check] check OK — running release build to produce binary"
	@cd mcu && $(CARGO) build --release --target thumbv7em-none-eabihf
	@echo "[cargo-check] binary at firmware/mcu/target/thumbv7em-none-eabihf/release/hexa-cern-laser-mcu"
	@ls -la mcu/target/thumbv7em-none-eabihf/release/hexa-cern-laser-mcu
	@file mcu/target/thumbv7em-none-eabihf/release/hexa-cern-laser-mcu
endif

.PHONY: lint
lint:    ## basic syntax sweep (always available)
	@echo "[lint] checking firmware/sim/*.hexa for sentinel + use math_pure"
	@for f in sim/*.hexa; do \
	    grep -q "use \"self/runtime/math_pure\"" $$f || { echo "  ✗ $$f missing math_pure import"; exit 1; }; \
	    grep -q "__HEXA_CERN_FW_" $$f                || { echo "  ✗ $$f missing __HEXA_CERN_FW_ sentinel"; exit 1; }; \
	    echo "  ✓ $$f"; \
	done
	@echo "[lint] checking firmware/hdl/*.v module names + skeleton-tag"
	@for f in hdl/*.v; do \
	    grep -q "module " $$f                       || { echo "  ✗ $$f no module decl"; exit 1; }; \
	    grep -q "SKELETON ONLY" $$f                  || { echo "  ✗ $$f missing skeleton tag"; exit 1; }; \
	    echo "  ✓ $$f"; \
	done
	@echo "[lint] checking firmware/mcu/src/main.rs no_std + skeleton-tag"
	@grep -q '#!\[no_std\]' mcu/src/main.rs && \
	    grep -q '#!\[no_main\]' mcu/src/main.rs && \
	    grep -q 'SKELETON ONLY' mcu/src/main.rs && \
	    echo "  ✓ mcu/src/main.rs" || { echo "  ✗ mcu/src/main.rs missing markers"; exit 1; }
	@echo "[lint] all firmware files conform"

.PHONY: sim-ngspice
sim-ngspice:    ## EMC pre-compliance ngspice — decoupling impedance sweep
ifeq ($(NGSPICE),)
	@echo "[sim-ngspice] ngspice NOT INSTALLED — install ngspice (apt/brew)" >&2
	@exit 2
else
	cd ../docs/safety/emc_sim && $(NGSPICE) -b decoupling_psrr.cir
endif

.PHONY: build-bitstream
build-bitstream:    ## ✗ blocked on board choice + Vivado/Quartus install
	@echo "[build-bitstream] BLOCKED — see firmware/hdl/README.md path-to-bitstream" >&2
	@echo "                   needs §A.6 step 1 (host facility) + step 2 (toolchain $$$$$$$$)" >&2
	@exit 3

.PHONY: flash-mcu
flash-mcu:    ## ✗ blocked on dev-board acquisition + probe-rs setup
	@echo "[flash-mcu] BLOCKED — see firmware/mcu/README.md path-to-running-silicon" >&2
	@echo "             needs §A.6 step 1 (board choice) + step 2 (board purchase)" >&2
	@exit 3

.PHONY: clean
clean:    ## remove target/ build artifacts
	@rm -rf target mcu/target
	@echo "[clean] target dirs removed"
