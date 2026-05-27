# SDC constraints — router_d4 (degree-4 mesh NoC router baseline) · SKY130 hd, tt
# 2026-05-18 · OpenSTA/OpenROAD compatible. Liberty time_unit = "1ns".
# See router_d6.sdc for bug history. 200 MHz target.

create_clock -name clk -period 5.0 [get_ports clk]
set_clock_uncertainty 0.25 [get_clocks clk]
set_input_delay  -clock clk 1.0 [all_inputs]
set_output_delay -clock clk 1.0 [all_outputs]
set_false_path -from [get_ports rst]
