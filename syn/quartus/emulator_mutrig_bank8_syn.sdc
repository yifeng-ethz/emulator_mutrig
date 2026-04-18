# Standalone timing sign-off for emulator_mutrig_bank8
create_clock -name clk125 -period 7.273 [get_ports {clk125}]

set_false_path -from [get_ports {reset_n}]
set_false_path -from [get_ports {asi_ctrl_data[*]}]
set_false_path -from [get_ports {asi_ctrl_valid}]
set_false_path -from [get_ports {coe_inject_pulse}]
set_false_path -from [get_ports {coe_inject_masked_pulse}]
