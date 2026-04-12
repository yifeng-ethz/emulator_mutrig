# emulator_mutrig_hw.tcl
# Platform Designer component for MuTRiG 3 ASIC Emulator
#
# Emulates the digital output of a single MuTRiG 3 ASIC, producing
# 8b/1k parallel data frames bit-compatible with the real ASIC serial
# output (after 8b10b decoding).  Feeds frame_rcv_ip directly.

package require -exact qsys 16.1

# ========================================================================
# Packaging constants
# ========================================================================
set SCRIPT_DIR [file dirname [file normalize [info script]]]

set CSR_ADDR_W_CONST            4
set TX8B1K_WIDTH_CONST          9
set RUN_CONTROL_WIDTH_CONST     9

# Identity defaults (no identity header in RTL — catalog tracking only)
set IP_UID_DEFAULT_CONST        1162696020 ;# ASCII "EMUT" = 0x454D5554
set VERSION_MAJOR_DEFAULT_CONST 26
set VERSION_MINOR_DEFAULT_CONST 0
set VERSION_PATCH_DEFAULT_CONST 1
set BUILD_DEFAULT_CONST         412
set VERSION_DATE_DEFAULT_CONST  20260412
set VERSION_GIT_DEFAULT_CONST   0
set VERSION_GIT_SHORT_DEFAULT_CONST "unknown"
set VERSION_GIT_DESCRIBE_DEFAULT_CONST "unknown"
if {![catch {set VERSION_GIT_SHORT_DEFAULT_CONST [string trim [exec git -C $SCRIPT_DIR rev-parse --short HEAD]]}]} {
    if {[regexp {^[0-9a-fA-F]+$} $VERSION_GIT_SHORT_DEFAULT_CONST]} {
        scan $VERSION_GIT_SHORT_DEFAULT_CONST %x VERSION_GIT_DEFAULT_CONST
    }
}
catch {
    set VERSION_GIT_DESCRIBE_DEFAULT_CONST [string trim [exec git -C $SCRIPT_DIR describe --always --dirty --tags]]
}
set VERSION_GIT_HEX_DEFAULT_CONST [format "0x%08X" $VERSION_GIT_DEFAULT_CONST]
set VERSION_STRING_DEFAULT_CONST  [format "%d.%d.%d.%04d" \
    $VERSION_MAJOR_DEFAULT_CONST \
    $VERSION_MINOR_DEFAULT_CONST \
    $VERSION_PATCH_DEFAULT_CONST \
    $BUILD_DEFAULT_CONST]
set INSTANCE_ID_DEFAULT_CONST     0

# ========================================================================
# Module properties
# ========================================================================
set_module_property NAME                    emulator_mutrig
set_module_property DISPLAY_NAME            "MuTRiG Emulator Mu3e IP"
set_module_property VERSION                 $VERSION_STRING_DEFAULT_CONST
set_module_property DESCRIPTION             "MuTRiG Emulator Mu3e IP Core"
set_module_property GROUP                   "Mu3e Emulators/Modules"
set_module_property AUTHOR                  "Yifeng Wang"
set_module_property ICON_PATH               ../quartus_system/logo/mu3e_logo.png
set_module_property INTERNAL                false
set_module_property OPAQUE_ADDRESS_MAP      true
set_module_property INSTANTIATE_IN_SYSTEM_MODULE true
set_module_property EDITABLE                true
set_module_property REPORT_TO_TALKBACK      false
set_module_property ALLOW_GREYBOX_GENERATION false
set_module_property REPORT_HIERARCHY        false
set_module_property ELABORATION_CALLBACK    elaborate
set_module_property VALIDATION_CALLBACK     validate

# ========================================================================
# Helper
# ========================================================================
proc add_html_text {group_name item_name html_text} {
    add_display_item $group_name $item_name TEXT ""
    set_display_item_property $item_name DISPLAY_HINT html
    set_display_item_property $item_name TEXT $html_text
}

# ========================================================================
# CSR register map HTML
# ========================================================================
set CSR_TABLE_HTML {<html><table border="1" cellpadding="3" width="100%">
<tr><th>Word</th><th>Byte</th><th>Name</th><th>Access</th><th>Description</th></tr>
<tr><td>0x00</td><td>0x000</td><td>CONTROL</td><td>RW</td><td>[0] enable, [2:1] hit_mode, [3] short_mode</td></tr>
<tr><td>0x01</td><td>0x004</td><td>HIT_RATE</td><td>RW</td><td>[15:0] hit_rate (8.8 fixed-point), [31:16] noise_rate</td></tr>
<tr><td>0x02</td><td>0x008</td><td>BURST_CFG</td><td>RW</td><td>[4:0] burst_size, [12:8] burst_center</td></tr>
<tr><td>0x03</td><td>0x00C</td><td>PRNG_SEED</td><td>RW</td><td>[31:0] PRNG seed for hit generator</td></tr>
<tr><td>0x04</td><td>0x010</td><td>TX_MODE</td><td>RW</td><td>[2:0] tx_mode, [3] gen_idle, [7:4] asic_id</td></tr>
<tr><td>0x05</td><td>0x014</td><td>STATUS</td><td>RO</td><td>[15:0] frame_count, [25:16] last_event_count</td></tr>
</table></html>}

# ========================================================================
# Callbacks
# ========================================================================
proc compute_derived_values {} {
    set fifo_depth [get_parameter_value FIFO_DEPTH]
    set version_string [format "%d.%d.%d.%04d" \
        [get_parameter_value VERSION_MAJOR] \
        [get_parameter_value VERSION_MINOR] \
        [get_parameter_value VERSION_PATCH] \
        [get_parameter_value BUILD]]
    set version_git_hex [format "0x%08X" [get_parameter_value VERSION_GIT]]

    # Storage estimate: 48-bit hit words × depth
    set storage_bits [expr {48 * $fifo_depth}]

    catch {
        set_display_item_property overview_html TEXT "<html>\
<b>Function</b><br/>\
Single-lane MuTRiG&nbsp;3 digital-output emulator for FPGA-internal verification.\
The block synthesizes hit traffic, assembles MuTRiG-compatible frames, and drives\
the decoded 8b/1k byte stream expected by <b>frame_rcv_ip</b>.<br/><br/>\
<b>Data path</b><br/>\
run-control + inject pulse + CSR config &rarr; <b>hit_generator</b> &rarr; internal\
48-bit FIFO &rarr; <b>frame_assembler</b> &rarr; <b>tx8b1k</b><br/><br/>\
<b>Clocking</b><br/>\
Single synchronous <b>data_clock</b> domain. The emulator models the MuTRiG\
625&nbsp;MHz datapath at the Mu3e 125&nbsp;MHz byte-clock boundary.</html>"
    }
    catch {
        set_display_item_property hitgen_html TEXT "<html>\
<b>Hit FIFO</b><br/>\
Depth: <b>${fifo_depth}</b> entries &times; 48-bit hit words = <b>${storage_bits}</b> bits<br/><br/>\
<b>Hit modes</b><br/>\
<b>00</b> Poisson &mdash; i.i.d. per-channel with configurable rate<br/>\
<b>01</b> Burst &mdash; periodic cluster hits on neighbouring channels<br/>\
<b>10</b> Noise &mdash; random dark-count-like hits<br/>\
<b>11</b> Mixed &mdash; Poisson signal + burst clusters</html>"
    }
    catch {
        set_display_item_property frame_html TEXT "<html>\
<b>Frame format</b><br/>\
IDLE(K28.5) | K28.0(hdr) | frame_cnt[15:8] | frame_cnt[7:0] | flags_evt[15:8] | flags_evt[7:0] | hit_data&hellip; | CRC[15:8] | CRC[7:0] | K28.4(trailer)<br/><br/>\
<b>Frame interval</b><br/>\
Long mode: <b>1550</b> byte-clocks (~12.4 &micro;s at 125 MHz, datapath-matched)<br/>\
Short mode: <b>910</b> byte-clocks (~7.3 &micro;s at 125 MHz, datapath-matched)<br/><br/>\
<b>Hit word size</b><br/>\
Long: <b>48</b> bits (6 bytes per event)<br/>\
Short: <b>28</b> bits (3.5 bytes, alternating 3/4 byte packing)</html>"
    }
    catch {
        set_display_item_property profile_html TEXT [format {<html><b>Catalog revision</b><br/>This release is packaged as <b>%s</b>.<br/><br/><b>Catalog provenance</b><br/>Packaged git stamp default <b>%s</b> (<b>%s</b>).<br/>Git describe: <b>%s</b>.<br/><br/><b>Runtime identity</b><br/>This revision still uses catalog-only identity tracking. The common UID + META header is not yet implemented in the RTL CSR window.</html>} \
            $version_string \
            $version_git_hex \
            $::VERSION_GIT_SHORT_DEFAULT_CONST \
            $::VERSION_GIT_DESCRIBE_DEFAULT_CONST]
    }
    catch {
        set_display_item_property versioning_html TEXT [format {<html><b>VERSION encoding</b><br/>VERSION[31:24] = MAJOR, VERSION[23:16] = MINOR, VERSION[15:12] = PATCH, VERSION[11:0] = BUILD.<br/><br/><b>Catalog identity</b><br/>UID default is <b>EMUT</b> (0x454D5554).<br/>Default <b>VERSION_GIT</b> = <b>%s</b> (%s).<br/>Git describe = <b>%s</b>.<br/>Enable <b>Override Git Stamp</b> to enter a custom value.</html>} \
            $version_git_hex \
            $::VERSION_GIT_SHORT_DEFAULT_CONST \
            $::VERSION_GIT_DESCRIBE_DEFAULT_CONST]
    }
}

proc validate {} {
    compute_derived_values

    set fifo_depth   [get_parameter_value FIFO_DEPTH]
    set ip_uid       [get_parameter_value IP_UID]
    set build_value  [get_parameter_value BUILD]
    set ver_major    [get_parameter_value VERSION_MAJOR]
    set ver_minor    [get_parameter_value VERSION_MINOR]
    set ver_patch    [get_parameter_value VERSION_PATCH]
    set ver_date     [get_parameter_value VERSION_DATE]
    set ver_git      [get_parameter_value VERSION_GIT]
    set instance_id  [get_parameter_value INSTANCE_ID]
    set debug_level  [get_parameter_value DEBUG]

    if {$fifo_depth < 16 || $fifo_depth > 256} {
        send_message error "FIFO_DEPTH must be in the range 16..256."
    }
    if {$ip_uid < 0 || $ip_uid > 2147483647} {
        send_message error "IP_UID must stay in the signed 31-bit range."
    }
    if {$build_value < 0 || $build_value > 4095} {
        send_message error "BUILD must stay in the range 0..4095."
    }
    if {$ver_major < 0 || $ver_major > 255} {
        send_message error "VERSION_MAJOR must stay in the range 0..255."
    }
    if {$ver_minor < 0 || $ver_minor > 255} {
        send_message error "VERSION_MINOR must stay in the range 0..255."
    }
    if {$ver_patch < 0 || $ver_patch > 15} {
        send_message error "VERSION_PATCH must stay in the range 0..15."
    }
    if {$ver_date < 0 || $ver_date > 2147483647} {
        send_message error "VERSION_DATE must stay in the signed 31-bit range."
    }
    if {$ver_git < 0 || $ver_git > 2147483647} {
        send_message error "VERSION_GIT must stay in the signed 31-bit range."
    }
    if {$instance_id < 0 || $instance_id > 2147483647} {
        send_message error "INSTANCE_ID must stay in the signed 31-bit range."
    }
    if {$debug_level < 0 || $debug_level > 2} {
        send_message error "DEBUG must stay in the range 0..2."
    }
}

proc elaborate {} {
    compute_derived_values
    set_parameter_property FIFO_DEPTH ALLOWED_RANGES {16 32 64 128 256}
    set_parameter_property DEBUG ENABLED false
    set_parameter_property VERSION_MAJOR ENABLED false
    set_parameter_property VERSION_MINOR ENABLED false
    set_parameter_property VERSION_PATCH ENABLED false
    set_parameter_property BUILD ENABLED false
    set_parameter_property VERSION_DATE ENABLED false
    catch {set_parameter_property VERSION_GIT ENABLED [get_parameter_value GIT_STAMP_OVERRIDE]}
}

# ========================================================================
# File sets
# ========================================================================
add_fileset QUARTUS_SYNTH QUARTUS_SYNTH "" ""
set_fileset_property QUARTUS_SYNTH TOP_LEVEL emulator_mutrig
set_fileset_property QUARTUS_SYNTH ENABLE_RELATIVE_INCLUDE_PATHS false
set_fileset_property QUARTUS_SYNTH ENABLE_FILE_OVERWRITE_MODE false
add_fileset_file emulator_mutrig_pkg.sv SYSTEM_VERILOG PATH rtl/emulator_mutrig_pkg.sv
add_fileset_file prbs15_lfsr.sv         SYSTEM_VERILOG PATH rtl/prbs15_lfsr.sv
add_fileset_file crc16_8.sv             SYSTEM_VERILOG PATH rtl/crc16_8.sv
add_fileset_file hit_generator.sv       SYSTEM_VERILOG PATH rtl/hit_generator.sv
add_fileset_file frame_assembler.sv     SYSTEM_VERILOG PATH rtl/frame_assembler.sv
add_fileset_file emulator_mutrig.sv     SYSTEM_VERILOG PATH rtl/emulator_mutrig.sv TOP_LEVEL_FILE

add_fileset SIM_VERILOG SIM_VERILOG "" ""
set_fileset_property SIM_VERILOG TOP_LEVEL emulator_mutrig
set_fileset_property SIM_VERILOG ENABLE_RELATIVE_INCLUDE_PATHS false
set_fileset_property SIM_VERILOG ENABLE_FILE_OVERWRITE_MODE false
add_fileset_file emulator_mutrig_pkg.sv SYSTEM_VERILOG PATH rtl/emulator_mutrig_pkg.sv
add_fileset_file prbs15_lfsr.sv         SYSTEM_VERILOG PATH rtl/prbs15_lfsr.sv
add_fileset_file crc16_8.sv             SYSTEM_VERILOG PATH rtl/crc16_8.sv
add_fileset_file hit_generator.sv       SYSTEM_VERILOG PATH rtl/hit_generator.sv
add_fileset_file frame_assembler.sv     SYSTEM_VERILOG PATH rtl/frame_assembler.sv
add_fileset_file emulator_mutrig.sv     SYSTEM_VERILOG PATH rtl/emulator_mutrig.sv TOP_LEVEL_FILE

# ========================================================================
# Parameters — HDL
# ========================================================================
add_parameter FIFO_DEPTH INTEGER 64
set_parameter_property FIFO_DEPTH DISPLAY_NAME "Hit FIFO Depth"
set_parameter_property FIFO_DEPTH ALLOWED_RANGES {16 32 64 128 256}
set_parameter_property FIFO_DEPTH HDL_PARAMETER true
set_parameter_property FIFO_DEPTH DESCRIPTION "Depth of the internal hit FIFO between the hit generator and frame assembler."

add_parameter CSR_ADDR_WIDTH INTEGER $CSR_ADDR_W_CONST
set_parameter_property CSR_ADDR_WIDTH DISPLAY_NAME "CSR Address Width"
set_parameter_property CSR_ADDR_WIDTH HDL_PARAMETER true
set_parameter_property CSR_ADDR_WIDTH VISIBLE false

add_parameter DEBUG NATURAL 0
set_parameter_property DEBUG DISPLAY_NAME "Debug Level"
set_parameter_property DEBUG UNITS None
set_parameter_property DEBUG ALLOWED_RANGES 0:2
set_parameter_property DEBUG HDL_PARAMETER false
set_parameter_property DEBUG ENABLED false
set_parameter_property DEBUG DESCRIPTION "Current packaged revision has no optional debug RTL. The field is kept to preserve the standard Mu3e Configuration/Debug GUI contract."

# ========================================================================
# Parameters — Identity (catalog tracking; no identity header in RTL)
# ========================================================================
add_parameter IP_UID NATURAL $IP_UID_DEFAULT_CONST
set_parameter_property IP_UID DISPLAY_NAME "UID"
set_parameter_property IP_UID UNITS None
set_parameter_property IP_UID ALLOWED_RANGES 0:2147483647
set_parameter_property IP_UID HDL_PARAMETER false
set_parameter_property IP_UID DISPLAY_HINT hexadecimal
set_parameter_property IP_UID DESCRIPTION {Software-visible IP identifier. Default corresponds to ASCII "EMUT".}

add_parameter VERSION_MAJOR NATURAL $VERSION_MAJOR_DEFAULT_CONST
set_parameter_property VERSION_MAJOR DISPLAY_NAME "Version Major"
set_parameter_property VERSION_MAJOR UNITS None
set_parameter_property VERSION_MAJOR ALLOWED_RANGES 0:255
set_parameter_property VERSION_MAJOR HDL_PARAMETER false
set_parameter_property VERSION_MAJOR ENABLED false

add_parameter VERSION_MINOR NATURAL $VERSION_MINOR_DEFAULT_CONST
set_parameter_property VERSION_MINOR DISPLAY_NAME "Version Minor"
set_parameter_property VERSION_MINOR UNITS None
set_parameter_property VERSION_MINOR ALLOWED_RANGES 0:255
set_parameter_property VERSION_MINOR HDL_PARAMETER false
set_parameter_property VERSION_MINOR ENABLED false

add_parameter VERSION_PATCH NATURAL $VERSION_PATCH_DEFAULT_CONST
set_parameter_property VERSION_PATCH DISPLAY_NAME "Version Patch"
set_parameter_property VERSION_PATCH UNITS None
set_parameter_property VERSION_PATCH ALLOWED_RANGES 0:15
set_parameter_property VERSION_PATCH HDL_PARAMETER false
set_parameter_property VERSION_PATCH ENABLED false

add_parameter BUILD NATURAL $BUILD_DEFAULT_CONST
set_parameter_property BUILD DISPLAY_NAME "Build Stamp"
set_parameter_property BUILD UNITS None
set_parameter_property BUILD ALLOWED_RANGES 0:4095
set_parameter_property BUILD HDL_PARAMETER false
set_parameter_property BUILD ENABLED false
set_parameter_property BUILD DESCRIPTION {12-bit build stamp (MMDD of packaging date).}

add_parameter VERSION_DATE NATURAL $VERSION_DATE_DEFAULT_CONST
set_parameter_property VERSION_DATE DISPLAY_NAME "Version Date"
set_parameter_property VERSION_DATE UNITS None
set_parameter_property VERSION_DATE ALLOWED_RANGES 0:2147483647
set_parameter_property VERSION_DATE HDL_PARAMETER false
set_parameter_property VERSION_DATE ENABLED false
set_parameter_property VERSION_DATE DESCRIPTION {YYYYMMDD provenance word.}

add_parameter VERSION_GIT NATURAL $VERSION_GIT_DEFAULT_CONST
set_parameter_property VERSION_GIT DISPLAY_NAME "Git Stamp"
set_parameter_property VERSION_GIT UNITS None
set_parameter_property VERSION_GIT ALLOWED_RANGES 0:2147483647
set_parameter_property VERSION_GIT HDL_PARAMETER false
set_parameter_property VERSION_GIT DISPLAY_HINT hexadecimal
set_parameter_property VERSION_GIT ENABLED false
set_parameter_property VERSION_GIT DESCRIPTION {Truncated git commit hash captured at packaging time. This revision is catalog-only and is not exported to HDL.}

add_parameter GIT_STAMP_OVERRIDE BOOLEAN false
set_parameter_property GIT_STAMP_OVERRIDE DISPLAY_NAME "Override Git Stamp"
set_parameter_property GIT_STAMP_OVERRIDE UNITS None
set_parameter_property GIT_STAMP_OVERRIDE HDL_PARAMETER false
set_parameter_property GIT_STAMP_OVERRIDE DESCRIPTION "When enabled, allows manual entry of VERSION_GIT. When disabled, the packaged git stamp remains read-only."

add_parameter INSTANCE_ID NATURAL $INSTANCE_ID_DEFAULT_CONST
set_parameter_property INSTANCE_ID DISPLAY_NAME "Instance ID"
set_parameter_property INSTANCE_ID UNITS None
set_parameter_property INSTANCE_ID ALLOWED_RANGES 0:2147483647
set_parameter_property INSTANCE_ID HDL_PARAMETER false
set_parameter_property INSTANCE_ID DESCRIPTION {Integration-time instance identifier.}

# ========================================================================
# GUI — Tab 1: Configuration
# ========================================================================
set TAB_CONFIGURATION "Configuration"
set TAB_IDENTITY      "Identity"
set TAB_INTERFACES    "Interfaces"
set TAB_REGMAP        "Register Map"

add_display_item "" $TAB_CONFIGURATION GROUP tab
add_display_item $TAB_CONFIGURATION "Overview" GROUP
add_display_item $TAB_CONFIGURATION "Hit Generation" GROUP
add_display_item $TAB_CONFIGURATION "Frame Assembly" GROUP
add_display_item $TAB_CONFIGURATION "Debug" GROUP

add_html_text "Overview" overview_html {<html><i>Overview text will appear after elaboration.</i></html>}

add_display_item "Hit Generation" FIFO_DEPTH parameter
add_html_text "Hit Generation" hitgen_html "<html><b>Hit FIFO</b><br/>Updated by the validation callback.</html>"

add_html_text "Frame Assembly" frame_html "<html><b>Frame format</b><br/>Updated by the validation callback.</html>"
add_display_item "Debug" DEBUG parameter
add_html_text "Debug" debug_html {<html><b>Debug control</b><br/>This packaged revision does not expose optional debug RTL knobs. The fixed <b>DEBUG=0</b> entry is kept so the GUI layout matches the standard Mu3e IP packaging contract used by the upgraded wrappers.</html>}

# ========================================================================
# GUI — Tab 2: Identity
# ========================================================================
add_display_item "" $TAB_IDENTITY GROUP tab
add_display_item $TAB_IDENTITY "Delivered Profile" GROUP
add_display_item $TAB_IDENTITY "Versioning" GROUP

add_html_text "Delivered Profile" profile_html {<html><i>Delivered profile text will appear after elaboration.</i></html>}
add_html_text "Versioning" versioning_html {<html><i>Versioning text will appear after elaboration.</i></html>}
add_display_item "Versioning" IP_UID parameter
add_display_item "Versioning" VERSION_MAJOR parameter
add_display_item "Versioning" VERSION_MINOR parameter
add_display_item "Versioning" VERSION_PATCH parameter
add_display_item "Versioning" BUILD parameter
add_display_item "Versioning" VERSION_DATE parameter
add_display_item "Versioning" GIT_STAMP_OVERRIDE parameter
add_display_item "Versioning" VERSION_GIT parameter
add_display_item "Versioning" INSTANCE_ID parameter

# ========================================================================
# GUI — Tab 3: Interfaces
# ========================================================================
add_display_item "" $TAB_INTERFACES GROUP tab
add_display_item $TAB_INTERFACES "Clock / Reset" GROUP
add_display_item $TAB_INTERFACES "Data Path" GROUP
add_display_item $TAB_INTERFACES "Control Path" GROUP
add_display_item $TAB_INTERFACES "Injection" GROUP

add_html_text "Clock / Reset" clock_html {<html>
<b>data_clock</b> and <b>data_reset</b><br/>
Single synchronous clock/reset domain for the full emulator datapath
and CSR logic.
</html>}

add_html_text "Data Path" datapath_html {<html>
<b>tx8b1k</b> &mdash; 9-bit Avalon-ST source<br/>
<table border="1" cellpadding="3" width="100%">
<tr><th>Bits</th><th>Field</th><th>Description</th></tr>
<tr><td>8</td><td>is_k</td><td>K-character flag (1 for K28.0/K28.4/K28.5)</td></tr>
<tr><td>7:0</td><td>data</td><td>8-bit data byte</td></tr>
</table><br/>
Channel: 4-bit ASIC ID (from CSR register 4, bits [7:4]).<br/>
Error: 3-bit &mdash; {loss_sync_pattern, parity_error, decode_error}; always 0 for emulator.<br/>
Connects directly to <b>frame_rcv_ip</b> asi_rx8b1k sink.
</html>}

add_html_text "Control Path" control_html {<html>
<b>ctrl</b> &mdash; 9-bit Avalon-ST sink (run control)<br/>
<table border="1" cellpadding="3" width="100%">
<tr><th>Bit</th><th>State</th></tr>
<tr><td>0</td><td>IDLE</td></tr>
<tr><td>1</td><td>RUN_PREPARE</td></tr>
<tr><td>2</td><td>SYNC</td></tr>
<tr><td>3</td><td>RUNNING</td></tr>
<tr><td>4</td><td>TERMINATING</td></tr>
<tr><td>5</td><td>LINK_TEST</td></tr>
<tr><td>6</td><td>SYNC_TEST</td></tr>
<tr><td>7</td><td>RESET</td></tr>
<tr><td>8</td><td>OUT_OF_DAQ</td></tr>
</table><br/>
The emulator only responds to bit&nbsp;3 (<b>RUNNING</b>); ready is always asserted.<br/><br/>
<b>csr</b> &mdash; Avalon-MM slave<br/>
Word-addressed, 4-bit address, 32-bit data.  Read wait = 1 cycle, write wait = 0 cycles.
</html>}

add_html_text "Injection" inject_html {<html>
<b>inject</b> &mdash; 1-bit conduit sink<br/>
External pulse input used to trigger an immediate burst around the configured
<b>burst_center</b> channel. The pulse is sampled in the <b>data_clock</b>
domain and feeds the same burst path used by the normal hit modes.
</html>}

# ========================================================================
# GUI — Tab 4: Register Map
# ========================================================================
add_display_item "" $TAB_REGMAP GROUP tab
add_display_item $TAB_REGMAP "CSR Window" GROUP
add_html_text "CSR Window" csr_table_html $CSR_TABLE_HTML

add_display_item $TAB_REGMAP "CONTROL Fields (0x00)" GROUP
add_html_text "CONTROL Fields (0x00)" control_fields_html {<html>
<table border="1" cellpadding="3" width="100%">
<tr><th>Bit</th><th>Name</th><th>Access</th><th>Reset</th><th>Description</th></tr>
<tr><td>0</td><td>enable</td><td>RW</td><td>1</td><td>Emulator enable (1=active)</td></tr>
<tr><td>2:1</td><td>hit_mode</td><td>RW</td><td>00</td><td>00=Poisson, 01=Burst, 10=Noise, 11=Mixed</td></tr>
<tr><td>3</td><td>short_mode</td><td>RW</td><td>0</td><td>1=short hit format, 0=long</td></tr>
<tr><td>31:4</td><td>reserved</td><td>RO</td><td>0</td><td>Reserved, read as zero</td></tr>
</table></html>}

add_display_item $TAB_REGMAP "HIT_RATE Fields (0x01)" GROUP
add_html_text "HIT_RATE Fields (0x01)" hitrate_fields_html {<html>
<table border="1" cellpadding="3" width="100%">
<tr><th>Bit</th><th>Name</th><th>Access</th><th>Reset</th><th>Description</th></tr>
<tr><td>15:0</td><td>hit_rate</td><td>RW</td><td>0x0800</td><td>Per-cycle hit probability threshold (8.8 fixed-point; ~8 hits/frame)</td></tr>
<tr><td>31:16</td><td>noise_rate</td><td>RW</td><td>0x0100</td><td>Noise hit probability threshold (~1 noise/frame)</td></tr>
</table></html>}

add_display_item $TAB_REGMAP "BURST_CFG Fields (0x02)" GROUP
add_html_text "BURST_CFG Fields (0x02)" burst_fields_html {<html>
<table border="1" cellpadding="3" width="100%">
<tr><th>Bit</th><th>Name</th><th>Access</th><th>Reset</th><th>Description</th></tr>
<tr><td>4:0</td><td>burst_size</td><td>RW</td><td>4</td><td>Number of hits per burst cluster</td></tr>
<tr><td>7:5</td><td>reserved</td><td>RO</td><td>0</td><td>Reserved</td></tr>
<tr><td>12:8</td><td>burst_center</td><td>RW</td><td>16</td><td>Center channel for burst cluster</td></tr>
<tr><td>31:13</td><td>reserved</td><td>RO</td><td>0</td><td>Reserved</td></tr>
</table></html>}

add_display_item $TAB_REGMAP "TX_MODE Fields (0x04)" GROUP
add_html_text "TX_MODE Fields (0x04)" txmode_fields_html {<html>
<table border="1" cellpadding="3" width="100%">
<tr><th>Bit</th><th>Name</th><th>Access</th><th>Reset</th><th>Description</th></tr>
<tr><td>2:0</td><td>tx_mode</td><td>RW</td><td>000</td><td>000=Long, 001=PRBS single, 010=PRBS sat, 100=Short</td></tr>
<tr><td>3</td><td>gen_idle</td><td>RW</td><td>1</td><td>Generate K28.5 idle comma between frames</td></tr>
<tr><td>7:4</td><td>asic_id</td><td>RW</td><td>0</td><td>ASIC ID tag on AVST channel output</td></tr>
<tr><td>31:8</td><td>reserved</td><td>RO</td><td>0</td><td>Reserved</td></tr>
</table></html>}

add_display_item $TAB_REGMAP "STATUS Fields (0x05)" GROUP
add_html_text "STATUS Fields (0x05)" status_fields_html {<html>
<table border="1" cellpadding="3" width="100%">
<tr><th>Bit</th><th>Name</th><th>Access</th><th>Reset</th><th>Description</th></tr>
<tr><td>15:0</td><td>frame_count</td><td>RO</td><td>0</td><td>Running count of assembled frames</td></tr>
<tr><td>25:16</td><td>last_event_count</td><td>RO</td><td>0</td><td>Hit count in the most recently assembled frame</td></tr>
<tr><td>31:26</td><td>reserved</td><td>RO</td><td>0</td><td>Reserved</td></tr>
</table></html>}

# ========================================================================
# Interfaces
# ========================================================================

# Clock and reset
add_interface data_clock clock end
set_interface_property data_clock clockRate 0
set_interface_property data_clock ENABLED true
add_interface_port data_clock i_clk clk Input 1

add_interface data_reset reset end
set_interface_property data_reset associatedClock data_clock
set_interface_property data_reset synchronousEdges DEASSERT
set_interface_property data_reset ENABLED true
add_interface_port data_reset i_rst reset Input 1

# Avalon-ST source [tx8b1k] — 8b/1k output to frame_rcv_ip
add_interface tx8b1k avalon_streaming source
set_interface_property tx8b1k associatedClock data_clock
set_interface_property tx8b1k associatedReset data_reset
set_interface_property tx8b1k dataBitsPerSymbol $TX8B1K_WIDTH_CONST
set_interface_property tx8b1k firstSymbolInHighOrderBits true
set_interface_property tx8b1k maxChannel 15
set_interface_property tx8b1k symbolsPerBeat 1
set_interface_property tx8b1k readyLatency 0
set_interface_property tx8b1k errorDescriptor "loss_sync_pattern parity_error decode_error"
set_interface_property tx8b1k ENABLED true
add_interface_port tx8b1k aso_tx8b1k_data    data    Output $TX8B1K_WIDTH_CONST
add_interface_port tx8b1k aso_tx8b1k_valid   valid   Output 1
add_interface_port tx8b1k aso_tx8b1k_channel channel Output 4
add_interface_port tx8b1k aso_tx8b1k_error   error   Output 3

# Avalon-ST sink [ctrl] — run control timing
add_interface ctrl avalon_streaming sink
set_interface_property ctrl associatedClock data_clock
set_interface_property ctrl associatedReset data_reset
set_interface_property ctrl dataBitsPerSymbol $RUN_CONTROL_WIDTH_CONST
set_interface_property ctrl symbolsPerBeat 1
set_interface_property ctrl maxChannel 0
set_interface_property ctrl readyLatency 0
set_interface_property ctrl errorDescriptor ""
set_interface_property ctrl ENABLED true
add_interface_port ctrl asi_ctrl_data  data  Input  $RUN_CONTROL_WIDTH_CONST
add_interface_port ctrl asi_ctrl_valid valid Input  1
add_interface_port ctrl asi_ctrl_ready ready Output 1

# Conduit [inject] — datapath charge-injection pulse
add_interface inject conduit end
set_interface_property inject associatedClock data_clock
set_interface_property inject associatedReset data_reset
set_interface_property inject ENABLED true
add_interface_port inject coe_inject_pulse pulse Input 1

# Avalon-MM slave [csr] — configuration registers
add_interface csr avalon end
set_interface_property csr associatedClock data_clock
set_interface_property csr associatedReset data_reset
set_interface_property csr addressUnits WORDS
set_interface_property csr readLatency 0
set_interface_property csr readWaitTime 1
set_interface_property csr writeWaitTime 0
set_interface_property csr ENABLED true
add_interface_port csr avs_csr_address     address     Input  $CSR_ADDR_W_CONST
add_interface_port csr avs_csr_read        read        Input  1
add_interface_port csr avs_csr_write       write       Input  1
add_interface_port csr avs_csr_writedata   writedata   Input  32
add_interface_port csr avs_csr_readdata    readdata    Output 32
add_interface_port csr avs_csr_waitrequest waitrequest Output 1
