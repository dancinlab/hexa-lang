# router_d6 SDC — OpenSTA/OpenROAD compatible. Liberty time_unit = "1ns".
# 200 MHz target (5 ns period). See ../../../router_d6.sdc for bug history.
create_clock -name clk -period 5.0 [get_ports clk]
set_clock_uncertainty 0.25 [get_clocks clk]
set_input_delay  -clock clk 1.0 [all_inputs]
set_output_delay -clock clk 1.0 [all_outputs]
set_false_path -from [get_ports rst]
