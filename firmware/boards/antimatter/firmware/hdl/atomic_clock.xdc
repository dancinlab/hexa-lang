# firmware/hdl/atomic_clock.xdc — Vivado constraints for HEXA-FACTORY-FW-01.
#
# Phase D pin constraints for `firmware/hdl/atomic_clock.v`.  Target part:
# XCKU040-FFVA1156-1 (Kintex UltraScale+).
#
# Source: firmware/doc/board_v0_atomic_clock.md §2 (Pinout — XCKU040
# timing-critical signals).

# ── 10 MHz Cs reference (LVDS, Bank 64, AT7/AU7) ──────────────────────
set_property PACKAGE_PIN AT7 [get_ports cs_ref_10m_p]
set_property IOSTANDARD LVDS [get_ports cs_ref_10m_p]
set_property PACKAGE_PIN AU7 [get_ports cs_ref_10m_n]
set_property IOSTANDARD LVDS [get_ports cs_ref_10m_n]
create_clock -name cs_ref_10m -period 100.000 [get_ports cs_ref_10m_p]

# ── DDS phase output for ν_c counting (Bank 64) ──────────────────────
set_property PACKAGE_PIN AV7 [get_ports ocxo_dds_phase_out]
set_property IOSTANDARD LVCMOS18 [get_ports ocxo_dds_phase_out]

# ── TDC7201 SPI (Bank 65) ────────────────────────────────────────────
set_property PACKAGE_PIN AY9  [get_ports tdc7201_csb]
set_property PACKAGE_PIN AY10 [get_ports tdc7201_sclk]
set_property PACKAGE_PIN AY11 [get_ports tdc7201_din]
set_property PACKAGE_PIN AY12 [get_ports tdc7201_dout]
set_property PACKAGE_PIN AY13 [get_ports tdc7201_int]
set_property IOSTANDARD LVCMOS33 [get_ports {tdc7201_csb tdc7201_sclk tdc7201_din tdc7201_dout tdc7201_int}]

# ── TDC start/stop pulses (Bank 66, low-skew LVDS) ──────────────────
set_property PACKAGE_PIN BA15 [get_ports tdc_start_p]
set_property PACKAGE_PIN BB15 [get_ports tdc_start_n]
set_property PACKAGE_PIN BA16 [get_ports tdc_stop1_p]
set_property PACKAGE_PIN BB16 [get_ports tdc_stop1_n]
set_property PACKAGE_PIN BA17 [get_ports tdc_stop2_p]
set_property PACKAGE_PIN BB17 [get_ports tdc_stop2_n]
set_property IOSTANDARD LVDS [get_ports {tdc_start_p tdc_start_n tdc_stop1_p tdc_stop1_n tdc_stop2_p tdc_stop2_n}]

# 1 ps TDC bin → ≤ 1 ns total skew across stop1/stop2 pair
set_max_delay -from [get_ports tdc_start_p] -to [get_ports tdc_stop1_p] 1.000
set_max_delay -from [get_ports tdc_start_p] -to [get_ports tdc_stop2_p] 1.000

# ── LTC2387 24-bit ADC (Bank 67, LVDS) ────────────────────────────
set_property PACKAGE_PIN BB18 [get_ports ltc2387_sdo_p]
set_property PACKAGE_PIN BB19 [get_ports ltc2387_sdo_n]
set_property PACKAGE_PIN BB20 [get_ports ltc2387_cnv]
set_property PACKAGE_PIN BB21 [get_ports ltc2387_clkout_p]
set_property PACKAGE_PIN BB22 [get_ports ltc2387_clkout_n]
set_property IOSTANDARD LVDS [get_ports {ltc2387_sdo_p ltc2387_sdo_n ltc2387_clkout_p ltc2387_clkout_n}]
set_property IOSTANDARD LVCMOS33 [get_ports ltc2387_cnv]
create_clock -name adc_clkout -period 33.333 [get_ports ltc2387_clkout_p]   ;# 30 MHz

# ── ADF4356 LO synthesizer (Bank 68) ──────────────────────────────
set_property PACKAGE_PIN AY24 [get_ports adf4356_ce]
set_property PACKAGE_PIN AY25 [get_ports adf4356_data]
set_property PACKAGE_PIN AY26 [get_ports adf4356_le]
set_property PACKAGE_PIN AY27 [get_ports adf4356_muxout]
set_property IOSTANDARD LVCMOS33 [get_ports {adf4356_ce adf4356_data adf4356_le adf4356_muxout}]

# ── Laser-lock feedback DAC (Bank 69, SPI to off-FPGA) ───────────
set_property PACKAGE_PIN BA30 [get_ports laser_lock_dac_cs]
set_property PACKAGE_PIN BA31 [get_ports laser_lock_dac_sck]
set_property PACKAGE_PIN BA32 [get_ports laser_lock_dac_mosi]
set_property IOSTANDARD LVCMOS33 [get_ports {laser_lock_dac_cs laser_lock_dac_sck laser_lock_dac_mosi}]

# ── 1S-2S photodiode pulse (Bank 70, EXTI) ────────────────────────
set_property PACKAGE_PIN BB33 [get_ports photodiode_pulse]
set_property IOSTANDARD LVCMOS33 [get_ports photodiode_pulse]

# ── Host telemetry UART (Bank 70) ─────────────────────────────────
set_property PACKAGE_PIN BB34 [get_ports uart_host_tx]
set_property PACKAGE_PIN BB35 [get_ports uart_host_rx]
set_property IOSTANDARD LVCMOS33 [get_ports {uart_host_tx uart_host_rx}]

# ── Generated clocks (Cs ref → DDS, system clock) ────────────────
create_generated_clock -name dds_clk -source [get_ports cs_ref_10m_p] \
    -multiply_by 100 [get_pins -hier *dds_clk_int*]      ;# 1 GHz internal DDS
create_generated_clock -name sys_clk -source [get_ports cs_ref_10m_p] \
    -multiply_by 25 [get_pins -hier *sys_clk*]            ;# 250 MHz state machine

# ── Async crossings (UART, photodiode) ──────────────────────────
set_false_path -from [get_clocks sys_clk] -to [get_ports uart_host_tx]
set_false_path -from [get_ports uart_host_rx]    -to [get_clocks sys_clk]
set_false_path -from [get_ports photodiode_pulse] -to [get_clocks sys_clk]

set_property CONFIG_VOLTAGE 3.3 [current_design]
set_property CFGBVS VCCO     [current_design]
