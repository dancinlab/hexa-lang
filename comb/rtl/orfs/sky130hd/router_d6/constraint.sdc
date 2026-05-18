# SDC constraints — router_d6 (degree-6 hex NoC router)
# 2026-05-18 · target SKY130 hd, tt corner.
# Conservative 1 GHz target for 130nm — actual fmax determined by STA.

# 1 GHz clock (1000ps period)
create_clock -name clk -period 1000.0 [get_ports clk]
set_clock_uncertainty 50.0 [get_clocks clk]

# async reset (port name: rst); no timing path on reset
set_false_path -from [get_ports rst]

# IO delays (50% of clock period as conservative IO budget)
set io_delay 500.0
set io_ports [remove_from_collection [all_inputs] [get_ports {clk rst}]]
set_input_delay -clock clk $io_delay $io_ports
set_output_delay -clock clk $io_delay [all_outputs]

# drive strength / load assumption (typical std-cell IO)
set_driving_cell -lib_cell sky130_fd_sc_hd__buf_2 -pin X $io_ports
set_load 0.1 [all_outputs]
