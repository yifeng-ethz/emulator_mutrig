# add_emulators_mixed_to_scifi_dp.tcl
#
# Insert 8 emulator_mutrig lanes and per-lane source muxes into
# scifi_datapath_system_v2 so each lane can independently keep the real
# MuTRiG decoded stream or switch to the emulator stream.
#
# Edit EMULATOR_ENABLE_MASK below before running the script.

set EMULATOR_ENABLE_MASK {1 1 1 1 1 1 1 1}
set EMU_CSR_BASE_ADDR    0x2000
set EMU_CSR_SPAN         0x40

if {[llength $EMULATOR_ENABLE_MASK] != 8} {
    error "EMULATOR_ENABLE_MASK must contain exactly 8 entries."
}

puts "Expanding run_control_splitter to 24 outputs..."
set_instance_parameter_value run_control_splitter NUMBER_OF_OUTPUTS 24

for {set i 0} {$i < 8} {incr i} {
    set use_emu      [lindex $EMULATOR_ENABLE_MASK $i]
    set emu_inst     "emulator_mutrig_$i"
    set mux_inst     "mutrig_lane_source_mux_$i"
    set splitter_out [expr {16 + $i}]
    set csr_addr     [expr {$EMU_CSR_BASE_ADDR + $i * $EMU_CSR_SPAN}]

    puts "Configuring lane $i (use_emulator=$use_emu)..."

    catch {remove_connection lvds_rx_controller_pro_0.decoded${i}/mutrig_datapath_subsystem_${i}.decoded_din}

    add_instance $emu_inst emulator_mutrig 1.0
    set_instance_parameter_value $emu_inst FIFO_DEPTH 256
    set_instance_parameter_value $emu_inst ASIC_ID_DEFAULT $i
    set_instance_parameter_value $emu_inst CLUSTER_CROSS_ASIC_DEFAULT 0
    set_instance_parameter_value $emu_inst CLUSTER_CENTER_GLOBAL_DEFAULT 127
    set_instance_parameter_value $emu_inst CLUSTER_LANE_INDEX_DEFAULT $i
    set_instance_parameter_value $emu_inst CLUSTER_LANE_COUNT_DEFAULT 8

    add_instance $mux_inst mutrig_lane_source_mux 1.0
    set_instance_parameter_value $mux_inst SELECT_EMULATOR $use_emu

    add_connection lvds_rx_28nm_0.outclock/${emu_inst}.data_clock
    add_connection lvds_rx_28nm_0.outclock/${mux_inst}.clk

    add_connection master_datapath.master_reset/${emu_inst}.data_reset
    add_connection master_datapath.master_reset/${mux_inst}.rst

    add_connection lvds_rx_controller_pro_0.decoded${i}/${mux_inst}.real_in
    add_connection ${emu_inst}.tx8b1k/${mux_inst}.emu_in
    add_connection ${mux_inst}.selected_out/mutrig_datapath_subsystem_${i}.decoded_din

    add_connection run_control_splitter.out${splitter_out}/${emu_inst}.ctrl

    add_connection master_datapath.master/${emu_inst}.csr
    set_connection_parameter_value master_datapath.master/${emu_inst}.csr baseAddress $csr_addr

    puts "  emulator csr=0x[format %04X $csr_addr], default_asic_id=$i, mux_select=$use_emu, cluster_lane=$i/8"
}

save_system

puts ""
puts "=== Mixed MuTRiG / Emulator Integration Complete ==="
puts "Edit EMULATOR_ENABLE_MASK to choose which of the 8 lanes use emulator traffic."
puts "Each emulator instance is parameterized with a shared 8-lane cluster domain (lane index set per instance). Mixed systems keep cross-ASIC cluster replay disabled by default because real/emulated masks may be sparse."
puts "The emulator inject conduit remains available per instance; fan out the board inject pulse at the system top level if you want the same external pulse to drive both real-lane injection logic and emulator lanes."
