set THIS_DIR     [pwd]
set RAW_ROOT     /home/yifeng/kbriggl-mutrig3-c3cce8d41dcb/units
set SUPPORT_ROOT [file join $THIS_DIR raw_support]
set WORKLIB      mutrig_raw_contract

if {[file exists $WORKLIB]} {
    vdel -lib $WORKLIB -all
}
vlib $WORKLIB
vmap work $WORKLIB

vcom -work work -2008 $RAW_ROOT/datapath_defs/source/rtl/vhdl/datapath_helpers.vhd
vcom -work work -2008 $RAW_ROOT/datapath_defs/source/rtl/vhdl/datapath_types.vhd
vcom -work work -2008 $RAW_ROOT/datapath_defs/source/rtl/vhdl/serial_comm_defs.vhd
vcom -work work -2008 $RAW_ROOT/datapath_defs/source/rtl/vhdl/txt_util.vhd

vcom -work work -2008 $RAW_ROOT/SRAM/source/rtl/vhdl/generic_dp_ram.vhd

vcom -work work -2008 $SUPPORT_ROOT/hdlcore_lib/generic_arbitration/units/arb_selection/source/rtl/vhdl/arb_selection_alter.vhd
vcom -work work -2008 $SUPPORT_ROOT/hdlcore_lib/generic_arbitration/units/arb_selection/source/rtl/vhdl/arb_selection.vhd
vcom -work work -2008 $SUPPORT_ROOT/hdlcore_lib/generic_arbitration/units/arb_selection/source/rtl/vhdl/roundrobin_sel.vhd
vcom -work work -2008 $SUPPORT_ROOT/hdlcore_lib/generic_arbitration/units/arb_selection/source/rtl/vhdl/roundrobin_sel_alternant.vhd
vcom -work work -2008 $SUPPORT_ROOT/hdlcore_lib/generic_arbitration/units/generic_mux_chnumappend/source/rtl/vhdl/generic_mux.vhd
vcom -work work -2008 $SUPPORT_ROOT/hdlcore_lib/generic_memory/fifo_wtrig/source/rtl/vhdl/fifo_wtrig_entity.vhd
vcom -work work -2008 $SUPPORT_ROOT/hdlcore_lib/generic_memory/fifo_wtrig/source/rtl/vhdl/fifo_wtrig_arch_generic_ram.vhd
vcom -work work -2008 $SUPPORT_ROOT/hdlcore_lib/generic_memory/generic_dp_fifo/source/rtl/vhdl/generic_dp_fifo.vhd

vcom -work work -2008 $RAW_ROOT/clock_divider/source/rtl/vhdl/clock_divider_sreg_counter_longedge.vhd
vcom -work work -2008 $RAW_ROOT/reset_generator/source/rtl/vhdl/reset_generator.vhdl
vcom -work work -2008 $RAW_ROOT/synchronizer/source/rtl/vhdl/synchronizer.vhd

vcom -work work -2008 $RAW_ROOT/pll_lol_detector/source/rtl/vhdl/pll_lol_detector.vhd
vcom -work work -2008 $RAW_ROOT/coincidence_logic/source/rtl/vhdl/coincidence_crossbar.vhd
vcom -work work -2008 $RAW_ROOT/coincidence_logic/source/rtl/vhdl/coincidence_matrix.vhd
vcom -work work -2008 $RAW_ROOT/ch_event_counter/source/rtl/vhdl/ch_event_counter.vhd
vcom -work work -2008 $RAW_ROOT/therm_decode/source/rtl/vhdl/therm_decode.vhd
vcom -work work -2008 $RAW_ROOT/ch_hit_receiver/source/rtl/vhdl/ch_hit_receiver.vhdl
vcom -work work -2008 $RAW_ROOT/L1_arbitration/source/rtl/vhdl/L1_arbitration.vhd
vcom -work work -2008 $RAW_ROOT/group_buffer/source/rtl/vhdl/group_buffer.vhd

vcom -work work -2008 $RAW_ROOT/MS_select/source/rtl/vhdl/MS_select.vhd
vcom -work work -2008 $RAW_ROOT/group_select/source/rtl/vhdl/group_select.vhd
vcom -work work -2008 $RAW_ROOT/GroupMasterSelect/source/rtl/vhdl/GroupMasterSelect.vhd

vcom -work work -2008 $RAW_ROOT/frame_generator/source/rtl/vhdl/crc16_8.vhd
vcom -work work -2008 $RAW_ROOT/frame_generator/source/rtl/vhdl/frame_generator.vhd
vcom -work work -2008 $RAW_ROOT/8b10b_encoder/source/rtl/vhdl/8b10_enc.vhd
vcom -work work -2008 $RAW_ROOT/8b10b_encoder/source/rtl/vhdl/encoder_module.vhd
vcom -work work -2008 $RAW_ROOT/dual_edge_flipflop/source/rtl/vhdl/dual_edge_flipflop.vhd
vcom -work work -2008 $RAW_ROOT/dual_edge_serializer/source/rtl/vhdl/dual_edge_serializer.vhd
vcom -work work -2008 $RAW_ROOT/init_transmission/source/rtl/vhdl/init_transmission.vhd
vcom -work work -2008 $RAW_ROOT/prbs_gen/source/rtl/vhdl/prbs_gen48.vhd
vcom -work work -2008 $RAW_ROOT/block_frame_gen_ser/source/rtl/vhdl/block_frame_gen_ser.vhd

vcom -work work -2008 $RAW_ROOT/spi_slave/source/rtl/vhdl/spi_slave.vhdl
vcom -work work -2008 $RAW_ROOT/spi_master_ch_ent_cnt/source/rtl/vhdl/spi_master_ch_ent_cnt.vhd
vcom -work work -2008 $RAW_ROOT/digital_all/source/rtl/vhdl/digital_all.vhdl

vcom -work work -2008 $RAW_ROOT/analog_macro_emu/source/rtl/vhdl/LVDS_RX_top.vhd
vcom -work work -2008 $RAW_ROOT/analog_macro_emu/source/rtl/vhdl/LVDS_TX_top.vhd
vcom -work work -2008 $RAW_ROOT/analog_macro_emu/source/rtl/vhdl/TDC_Channel.vhd
vcom -work work -2008 $RAW_ROOT/analog_macro_emu/source/rtl/vhdl/TimeBase.vhd
vcom -work work -2008 $RAW_ROOT/analog_macro_emu/source/rtl/vhdl/ANALOG_CHANNEL_ISOLATED.vhd
vcom -work work -2008 $RAW_ROOT/stic3_top/source/rtl/vhdl/stic3_top.vhd

puts "Compiled raw MuTRiG contract sources into library '$WORKLIB'."
