# SDC constraints — router_d6 (degree-6 hex NoC router) · SKY130 hd, tt
# 2026-05-18 · OpenSTA/OpenROAD compatible. Liberty time_unit = "1ns".
#
# Bug history (kept honest):
#   prior version had `-period 1000.0` intending "1000 ps" (1 GHz) but
#   liberty unit is ns → became 1 MHz; `set_clock_uncertainty 50.0`
#   became 50 ns → -48 ns hold violations everywhere → ORFS CTS
#   hold-repair exhausted max buffer count. Also used
#   `remove_from_collection` which OpenSTA does not support.
#   Fixed: ns-correct values + OpenSTA-compatible commands.

create_clock -name clk -period 5.0 [get_ports clk]
set_clock_uncertainty 0.25 [get_clocks clk]
set_input_delay  -clock clk 1.0 [all_inputs]
set_output_delay -clock clk 1.0 [all_outputs]
set_false_path -from [get_ports rst]
