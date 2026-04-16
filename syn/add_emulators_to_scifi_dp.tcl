# add_emulators_to_scifi_dp.tcl
# Platform Designer / qsys-script to add 8 MuTRiG emulators to scifi_datapath_v2_system
#
# Usage with qsys-script:
#   qsys-script --system-file=scifi_datapath_v2_system.qsys \
#     --script=add_emulators_to_scifi_dp.tcl \
#     --search-path=<ip_search_paths>
#
# This script:
#   1. Removes the LVDS decoded0..7 → mutrig_datapath_subsystem_N.decoded_din connections
#   2. Adds 8 emulator_mutrig instances
#   3. Connects each emulator's tx8b1k output to mutrig_datapath_subsystem_N.decoded_din
#   4. Expands run_control_splitter from 16 to 24 outputs
#   5. Connects each emulator's ctrl to run_control_splitter out16..23
#   6. Connects each emulator's csr to master_datapath
#   7. Assigns clock/reset connections
#   8. Saves the modified system

# ── Step 1: Remove existing LVDS → mutrig_datapath_subsystem connections ──
for {set i 0} {$i < 8} {incr i} {
    puts "Removing lvds_rx_controller_pro_0.decoded${i} -> mutrig_datapath_subsystem_${i}.decoded_din"
    remove_connection lvds_rx_controller_pro_0.decoded${i}/mutrig_datapath_subsystem_${i}.decoded_din
}

# ── Step 2: Expand run_control_splitter from 16 to 24 outputs ──
puts "Expanding run_control_splitter to 24 outputs..."
set_instance_parameter_value run_control_splitter NUMBER_OF_OUTPUTS 24

# ── Step 3: Add emulator instances and wire them up ──
set EMU_CSR_BASE_ADDR 0x2000
set EMU_CSR_SPAN     0x40

for {set i 0} {$i < 8} {incr i} {
    set inst "emulator_mutrig_$i"
    set splitter_out [expr {16 + $i}]

    puts "Adding $inst..."

    # Add instance
    add_instance $inst emulator_mutrig 1.0
    set_instance_parameter_value $inst FIFO_DEPTH 256
    set_instance_parameter_value $inst ASIC_ID_DEFAULT $i
    set_instance_parameter_value $inst CLUSTER_CROSS_ASIC_DEFAULT 1
    set_instance_parameter_value $inst CLUSTER_CENTER_GLOBAL_DEFAULT 127
    set_instance_parameter_value $inst CLUSTER_LANE_INDEX_DEFAULT $i
    set_instance_parameter_value $inst CLUSTER_LANE_COUNT_DEFAULT 8

    # Clock: lvds_rx_28nm_0.outclock (~125 MHz, same as datapath)
    add_connection lvds_rx_28nm_0.outclock/${inst}.data_clock

    # Reset: from master_datapath (same reset domain as other datapath components)
    add_connection master_datapath.master_reset/${inst}.data_reset

    # Data: emulator tx8b1k → mutrig_datapath_subsystem_N.decoded_din
    add_connection ${inst}.tx8b1k/mutrig_datapath_subsystem_${i}.decoded_din

    # Run control: run_control_splitter.out${splitter_out} → emulator ctrl
    add_connection run_control_splitter.out${splitter_out}/${inst}.ctrl

    # CSR: master_datapath → emulator CSR
    set csr_addr [expr {$EMU_CSR_BASE_ADDR + $i * $EMU_CSR_SPAN}]
    add_connection master_datapath.master/${inst}.csr
    set_connection_parameter_value master_datapath.master/${inst}.csr baseAddress $csr_addr

    puts "  $inst: CSR base 0x[format %04X $csr_addr], ctrl=splitter.out${splitter_out}, asic_id=$i, cluster_lane=$i/8"
}

# ── Step 4: Save ──
save_system

puts ""
puts "=== MuTRiG Emulator Integration Complete ==="
puts ""
puts "Changes:"
puts "  - Removed 8 lvds_rx_controller_pro_0.decoded → mutrig_datapath_subsystem connections"
puts "  - Added 8 emulator_mutrig instances (emulator_mutrig_0..7)"
puts "  - Expanded run_control_splitter to 24 outputs (16..23 for emulators)"
puts ""
puts "CSR Address Map (via master_datapath):"
for {set i 0} {$i < 8} {incr i} {
    set addr [expr {$EMU_CSR_BASE_ADDR + $i * $EMU_CSR_SPAN}]
    puts "  emulator_mutrig_$i: 0x[format %04X $addr]"
}
