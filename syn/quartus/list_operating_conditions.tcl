project_open emulator_mutrig_syn -revision emulator_mutrig_syn
create_timing_netlist
puts "Available operating conditions:"
foreach_in_collection op [get_available_operating_conditions] {
    puts $op
}
delete_timing_netlist
project_close
