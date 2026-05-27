# firmware/hdl/penning_rf.xdc — Vivado constraints for HEXA-TABLETOP-FW-01.
#
# Phase D pin constraints for `firmware/hdl/penning_rf.v`.  Target part:
# XCZU9EG-FFVC900-1 (Xilinx Zynq UltraScale+ MPSoC, FFVC900 package).
#
# Source: firmware/doc/board_v0_tabletop_penning.md §2 (Pinout).
# Status: paper PCB — pins reflect board doc spec; Vivado will check
# legality at synth/impl time once a real board with these net names
# is fabricated.
#
# Compile guard: this file is referenced by `firmware/hdl/build.tcl`
# only after `add_files -fileset constrs_1 ...` is uncommented.

# ── 100 MHz Wenzel OCXO reference (LVDS pair, Bank 224, AT3/AU3) ────────
set_property PACKAGE_PIN AT3 [get_ports ref_clk_100m_p]
set_property IOSTANDARD LVDS [get_ports ref_clk_100m_p]
set_property PACKAGE_PIN AU3 [get_ports ref_clk_100m_n]
set_property IOSTANDARD LVDS [get_ports ref_clk_100m_n]
create_clock -name ref_clk_100m -period 10.000 [get_ports ref_clk_100m_p]

# ── DAC parallel data → AD9162 (Bank 224, 16 LVDS pairs) ───────────────
set_property PACKAGE_PIN AT5 [get_ports {dac_data_p[0]}]
set_property PACKAGE_PIN AU5 [get_ports {dac_data_n[0]}]
set_property PACKAGE_PIN AT4 [get_ports {dac_data_p[1]}]
set_property PACKAGE_PIN AU4 [get_ports {dac_data_n[1]}]
# (DAC_DATA[2..15] follow same pattern in Bank 224 — KiCad bus expansion;
# elided here for paper-design size.  Phase D real PCB regenerates this
# block from board_v0_tabletop_penning.md.)
set_property IOSTANDARD LVDS [get_ports {dac_data_p[*] dac_data_n[*]}]

set_property PACKAGE_PIN AV3 [get_ports dac_clk_p]
set_property PACKAGE_PIN AW3 [get_ports dac_clk_n]
set_property IOSTANDARD LVDS [get_ports {dac_clk_p dac_clk_n}]

# ── ADC parallel data ← AD9208 (Bank 225, 14 LVDS pairs) ───────────────
set_property PACKAGE_PIN AY8 [get_ports {adc_data_p[0]}]
set_property PACKAGE_PIN BA8 [get_ports {adc_data_n[0]}]
# (ADC_DATA[1..13] elided same as DAC_DATA above.)
set_property IOSTANDARD LVDS [get_ports {adc_data_p[*] adc_data_n[*]}]

set_property PACKAGE_PIN AY11 [get_ports adc_clk_p]
set_property PACKAGE_PIN BA11 [get_ports adc_clk_n]
set_property IOSTANDARD LVDS [get_ports {adc_clk_p adc_clk_n}]

# ── Trap HV bias DAC (Bank 226, slow SPI to off-FPGA DAC) ─────────────
set_property PACKAGE_PIN AY18 [get_ports hv_dac_csb]
set_property PACKAGE_PIN AY19 [get_ports hv_dac_sck]
set_property PACKAGE_PIN AY20 [get_ports hv_dac_mosi]
set_property IOSTANDARD LVCMOS33 [get_ports {hv_dac_csb hv_dac_sck hv_dac_mosi}]

# ── Safety interlocks (Bank 227, single-ended LVCMOS33) ──────────────
set_property PACKAGE_PIN AY24 [get_ports lhe_level_sense_n]
set_property PACKAGE_PIN AY25 [get_ports magnet_quench_detect_n]
set_property IOSTANDARD LVCMOS33 [get_ports {lhe_level_sense_n magnet_quench_detect_n}]
set_property PULLUP true [get_ports {lhe_level_sense_n magnet_quench_detect_n}]

# ── CERN AD beam-injection handshake (Bank 228, RS-485 differential) ──
set_property PACKAGE_PIN AY29 [get_ports ad_handshake_tx_p]
set_property PACKAGE_PIN AY30 [get_ports ad_handshake_tx_n]
set_property PACKAGE_PIN BA29 [get_ports ad_handshake_rx_p]
set_property PACKAGE_PIN BA30 [get_ports ad_handshake_rx_n]
set_property IOSTANDARD LVDS [get_ports {ad_handshake_tx_p ad_handshake_tx_n ad_handshake_rx_p ad_handshake_rx_n}]

# ── Host telemetry UART (Bank 229) ────────────────────────────────────
set_property PACKAGE_PIN BA34 [get_ports uart_host_tx]
set_property PACKAGE_PIN BA35 [get_ports uart_host_rx]
set_property IOSTANDARD LVCMOS33 [get_ports {uart_host_tx uart_host_rx}]

# ── Status LEDs (Bank 64, single-ended) ──────────────────────────────
set_property PACKAGE_PIN BB1 [get_ports {led_status[0]}]
set_property PACKAGE_PIN BB2 [get_ports {led_status[1]}]
set_property PACKAGE_PIN BB3 [get_ports {led_status[2]}]
set_property PACKAGE_PIN BB4 [get_ports {led_status[3]}]
set_property IOSTANDARD LVCMOS33 [get_ports {led_status[*]}]

# ── Timing constraints ───────────────────────────────────────────────
# DAC sample clock from PLL (156.25 MHz)
create_generated_clock -name dac_clk_int -source [get_ports ref_clk_100m_p] \
    -multiply_by 25 -divide_by 16 [get_pins -hier *dac_clk_int*]

# System clock (312.5 MHz) for state machine
create_generated_clock -name sys_clk -source [get_ports ref_clk_100m_p] \
    -multiply_by 25 -divide_by 8 [get_pins -hier *sys_clk*]

# False paths between async clocks (UART vs sys_clk)
set_false_path -from [get_clocks sys_clk] -to [get_ports uart_host_tx]
set_false_path -from [get_ports uart_host_rx] -to [get_clocks sys_clk]

# Safety interlock signals — must propagate to S_IDLE within 10 ms
# (=3.125e6 sys_clk cycles).  Vivado max_delay constraint:
set_max_delay -from [get_ports {lhe_level_sense_n magnet_quench_detect_n}] \
              -to [get_clocks sys_clk] 5.000

# Bitstream config
set_property CONFIG_VOLTAGE 3.3 [current_design]
set_property CFGBVS VCCO     [current_design]
set_property BITSTREAM.GENERAL.COMPRESS TRUE [current_design]
