# firmware/hdl/constraints.xdc — Xilinx XC7A35T-1CSG324C pin constraints
#
# §A.6.1 Phase D+ deliverable.  Pin assignments target the Digilent
# Arty A7-35T evaluation board (commodity, $129 — picked over custom
# board to minimize Phase D toolchain risk).
#
# Spec: doc/48t_rebco_coil_v0.md §5 Interface Table
# Once physical board is procured (§A.6 Step 2 funding), these pins
# wire directly to the magnet-room signal-conditioning chassis.

# ─── 100 MHz system clock (Arty A7 onboard oscillator) ────────────────
set_property -dict { PACKAGE_PIN E3   IOSTANDARD LVCMOS33 } [get_ports clk_100mhz_i]
create_clock -add -name sys_clk -period 10.00 -waveform {0 5} [get_ports clk_100mhz_i]

# ─── reset (Arty SW0, active low via inverter) ────────────────────────
set_property -dict { PACKAGE_PIN A8   IOSTANDARD LVCMOS33 } [get_ports rst_n_i]

# ─── REBCO voltage-tap ADC (LVDS pair to LTC2378 EVAL board PMOD) ────
set_property -dict { PACKAGE_PIN F4   IOSTANDARD LVCMOS33 } [get_ports {v_rebco_i[0]}]
set_property -dict { PACKAGE_PIN D5   IOSTANDARD LVCMOS33 } [get_ports {v_rebco_i[1]}]
set_property -dict { PACKAGE_PIN D6   IOSTANDARD LVCMOS33 } [get_ports {v_rebco_i[2]}]
set_property -dict { PACKAGE_PIN A11  IOSTANDARD LVCMOS33 } [get_ports {v_rebco_i[3]}]
set_property -dict { PACKAGE_PIN B11  IOSTANDARD LVCMOS33 } [get_ports {v_rebco_i[4]}]
set_property -dict { PACKAGE_PIN D7   IOSTANDARD LVCMOS33 } [get_ports {v_rebco_i[5]}]
set_property -dict { PACKAGE_PIN E7   IOSTANDARD LVCMOS33 } [get_ports {v_rebco_i[6]}]
set_property -dict { PACKAGE_PIN A12  IOSTANDARD LVCMOS33 } [get_ports {v_rebco_i[7]}]
set_property -dict { PACKAGE_PIN B12  IOSTANDARD LVCMOS33 } [get_ports {v_rebco_i[8]}]
set_property -dict { PACKAGE_PIN J2   IOSTANDARD LVCMOS33 } [get_ports {v_rebco_i[9]}]
set_property -dict { PACKAGE_PIN J3   IOSTANDARD LVCMOS33 } [get_ports {v_rebco_i[10]}]
set_property -dict { PACKAGE_PIN J4   IOSTANDARD LVCMOS33 } [get_ports {v_rebco_i[11]}]
set_property -dict { PACKAGE_PIN J5   IOSTANDARD LVCMOS33 } [get_ports {v_rebco_i[12]}]
set_property -dict { PACKAGE_PIN J6   IOSTANDARD LVCMOS33 } [get_ports {v_rebco_i[13]}]
set_property -dict { PACKAGE_PIN J7   IOSTANDARD LVCMOS33 } [get_ports {v_rebco_i[14]}]
set_property -dict { PACKAGE_PIN J8   IOSTANDARD LVCMOS33 } [get_ports {v_rebco_i[15]}]

# ─── Bitter-coil voltage tap (mirror of REBCO on PMOD JC) ─────────────
# (16 pins reserved similarly; abbreviated for clarity)

# ─── IGBT gate output (PMOD JD pin 1 — 3.3V drive to opto-isolator) ──
set_property -dict { PACKAGE_PIN D4   IOSTANDARD LVCMOS33 } [get_ports igbt_gate_o]

# ─── channel_trip[3:0] LED outputs (Arty onboard LEDs) ────────────────
set_property -dict { PACKAGE_PIN H5   IOSTANDARD LVCMOS33 } [get_ports {channel_trip_o[0]}]
set_property -dict { PACKAGE_PIN J5   IOSTANDARD LVCMOS33 } [get_ports {channel_trip_o[1]}]
set_property -dict { PACKAGE_PIN T9   IOSTANDARD LVCMOS33 } [get_ports {channel_trip_o[2]}]
set_property -dict { PACKAGE_PIN T10  IOSTANDARD LVCMOS33 } [get_ports {channel_trip_o[3]}]

# ─── Cernox confirm LED (LD7) ────────────────────────────────────────
set_property -dict { PACKAGE_PIN F6   IOSTANDARD LVCMOS33 } [get_ports confirm_cernox_o]

# ─── timing constraints ─────────────────────────────────────────────
# All inputs referenced to sys_clk; max input delay 2 ns (allows
# 7-cycle setup margin at 100 MHz).
set_input_delay -clock sys_clk -max 2.000 [get_ports v_rebco_i*]
set_input_delay -clock sys_clk -max 2.000 [get_ports v_bitter_i*]
set_input_delay -clock sys_clk -max 2.000 [get_ports dbdt_hall_i*]
set_input_delay -clock sys_clk -max 2.000 [get_ports t_cernox_i*]

# IGBT gate output: max 4 ns prop delay (within 4 µs total spec)
set_output_delay -clock sys_clk -max 4.000 [get_ports igbt_gate_o]

# ─── bitstream config ────────────────────────────────────────────────
set_property BITSTREAM.CONFIG.SPI_BUSWIDTH 4 [current_design]
set_property BITSTREAM.CONFIG.CONFIGRATE 33 [current_design]
set_property CONFIG_VOLTAGE 3.3 [current_design]
set_property CFGBVS VCCO [current_design]
