# firmware/hdl/thrust_acq.xdc — Vivado constraints for HEXA-PROPULSION-FW-01.
#
# Phase D pin constraints for `firmware/hdl/thrust_acq.v`.  Target part:
# XCVU13P-FLGA2577-1 (Virtex UltraScale+, 128 GTYE4 SerDes lanes).
#
# Source: firmware/doc/board_v0_thrust_acquisition.md §2 (Pinout —
# XCVU13P capture-side highlights).

# ── 10 MHz Cs reference IN (BNC daisy-chain from atomic_clock board) ──
set_property PACKAGE_PIN A3 [get_ports cs_ref_10m_p]
set_property IOSTANDARD LVDS [get_ports cs_ref_10m_p]
set_property PACKAGE_PIN A4 [get_ports cs_ref_10m_n]
set_property IOSTANDARD LVDS [get_ports cs_ref_10m_n]
create_clock -name cs_ref_10m -period 100.000 [get_ports cs_ref_10m_p]

# ── ADC×16 over JESD204C / GTYE4 (32 Gbps each lane, Bank 224..230) ──
# Each ADC uses 4 lanes → 16 ADCs × 4 = 64 GTYE4 lanes used.
# Pin assignment is package-wide; here we show ADC0 only.
set_property PACKAGE_PIN A1 [get_ports {adc_lane_p[0]}]   ;# ADC0_LANE0
set_property PACKAGE_PIN A2 [get_ports {adc_lane_n[0]}]
# (ADC0_LANE[1..3] + ADC[1..15]_LANE[0..3] = 63 more — KiCad expansion;
# elided here for paper-design size.  Phase D real PCB regenerates from
# board_v0_thrust_acquisition.md.)

# JESD204C SYSREF for multi-ADC alignment
set_property PACKAGE_PIN B5 [get_ports adc_sysref_p]
set_property PACKAGE_PIN B6 [get_ports adc_sysref_n]
set_property IOSTANDARD LVDS [get_ports {adc_sysref_p adc_sysref_n}]

# ── Trigger fan-out (Bank 226, 16-way LVDS, 1 ns max skew) ───────
set_property PACKAGE_PIN C9  [get_ports {trigger_fanout_p[0]}]
set_property PACKAGE_PIN C10 [get_ports {trigger_fanout_n[0]}]
# (FANOUT[1..15] elided.)
set_property IOSTANDARD LVDS [get_ports {trigger_fanout_p[*] trigger_fanout_n[*]}]
# Critical: fan-out skew must be ≤ 1 ns (TRIGGER_FANOUT_NS budget)
set_max_delay -from [get_pins -hier *trigger_gen*] \
              -to   [get_ports {trigger_fanout_p[*]}] 1.000

# ── Watt-balance ADC (Bank 227, LTC2387 24-bit) ──────────────────
set_property PACKAGE_PIN D14 [get_ports watt_balance_sdo_p]
set_property PACKAGE_PIN D15 [get_ports watt_balance_sdo_n]
set_property PACKAGE_PIN D16 [get_ports watt_balance_cnv]
set_property IOSTANDARD LVDS    [get_ports {watt_balance_sdo_p watt_balance_sdo_n}]
set_property IOSTANDARD LVCMOS33 [get_ports watt_balance_cnv]

# ── BGO + ToF triggers (Bank 228, low-skew LVDS) ─────────────────
set_property PACKAGE_PIN E20 [get_ports bgo_trigger_in_p]
set_property PACKAGE_PIN E21 [get_ports bgo_trigger_in_n]
set_property PACKAGE_PIN E22 [get_ports tof_trigger_in_p]
set_property PACKAGE_PIN E23 [get_ports tof_trigger_in_n]
set_property IOSTANDARD LVDS [get_ports {bgo_trigger_in_p bgo_trigger_in_n tof_trigger_in_p tof_trigger_in_n}]
# Coincidence window: BGO ↔ ToF Δt ≤ TOF_WINDOW_NS = 50 ns
set_max_delay -from [get_ports bgo_trigger_in_p] \
              -to   [get_pins -hier *coincidence_check*] 50.000
set_max_delay -from [get_ports tof_trigger_in_p] \
              -to   [get_pins -hier *coincidence_check*] 50.000

# Global trigger out
set_property PACKAGE_PIN E24 [get_ports coincidence_out]
set_property IOSTANDARD LVCMOS33 [get_ports coincidence_out]

# ── NIM/CAMAC trigger inputs (Bank 229, 8 channels) ──────────────
set_property PACKAGE_PIN F25 [get_ports {nim_in[0]}]
# (nim_in[1..7] elided.)
set_property IOSTANDARD LVCMOS33 [get_ports {nim_in[*]}]

# ── DDR4 burst-capture buffer (Bank 230, 64-bit) ─────────────────
set_property PACKAGE_PIN G30 [get_ports {ddr4_dq[0]}]
# (DQ[1..63] elided.)
set_property IOSTANDARD POD12_DCI [get_ports {ddr4_dq[*]}]

# ── PCIe Gen4 ×16 to host (Bank 231, GTYE4 SerDes) ───────────────
set_property PACKAGE_PIN H35 [get_ports {pcie_tx_p[0]}]
set_property PACKAGE_PIN H36 [get_ports {pcie_tx_n[0]}]
# (LANE[1..15] elided.)

# ── Host telemetry (Bank 232) ─────────────────────────────────
set_property PACKAGE_PIN J40 [get_ports uart_host_tx]
set_property PACKAGE_PIN J41 [get_ports uart_host_rx]
set_property IOSTANDARD LVCMOS33 [get_ports {uart_host_tx uart_host_rx}]

# ── Generated clocks ─────────────────────────────────────────
create_generated_clock -name sys_clk -source [get_ports cs_ref_10m_p] \
    -multiply_by 100 [get_pins -hier *sys_clk*]              ;# 1 GHz capture
create_generated_clock -name adc_jesd_clk -source [get_ports cs_ref_10m_p] \
    -multiply_by 320 -divide_by 1 [get_pins -hier *adc_jesd_clk*]    ;# 32 Gbps lane rate

# ── Async crossings ──────────────────────────────────────────
set_false_path -from [get_clocks sys_clk] -to [get_ports uart_host_tx]
set_false_path -from [get_ports uart_host_rx]    -to [get_clocks sys_clk]
set_false_path -from [get_ports {nim_in[*]}]    -to [get_clocks sys_clk]

set_property CONFIG_VOLTAGE 3.3 [current_design]
set_property CFGBVS VCCO     [current_design]
set_property BITSTREAM.GENERAL.COMPRESS TRUE [current_design]
