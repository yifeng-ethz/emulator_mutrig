# Standalone timing sign-off for emulator_mutrig
# Target clock: 125.0 MHz (8.000 ns)
# Sign-off clock: 137.5 MHz (7.273 ns)

create_clock -name clk125 -period 7.273 [get_ports {clk125}]

set_false_path -from [get_ports {reset_n}]
set_false_path -from [remove_from_collection [all_inputs] [get_ports {clk125 reset_n}]]
set_false_path -to [all_outputs]
