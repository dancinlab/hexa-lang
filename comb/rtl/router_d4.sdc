# SDC constraints — router_d4 (degree-4 mesh NoC router baseline)
# 2026-05-18 · target SKY130 hd, tt corner.

create_clock -name clk -period 1000.0 [get_ports clk]
set_clock_uncertainty 50.0 [get_clocks clk]
set_false_path -from [get_ports rst]
set io_delay 500.0
set io_ports [remove_from_collection [all_inputs] [get_ports {clk rst}]]
set_input_delay -clock clk $io_delay $io_ports
set_output_delay -clock clk $io_delay [all_outputs]
set_driving_cell -lib_cell sky130_fd_sc_hd__buf_2 -pin X $io_ports
set_load 0.1 [all_outputs]
