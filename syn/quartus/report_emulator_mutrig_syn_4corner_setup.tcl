project_open emulator_mutrig_syn -revision emulator_mutrig_syn
create_timing_netlist
read_sdc

set report_dir "sta_reports"
file mkdir $report_dir

set corners {
    slow_1100mv_85c 5_H4_slow_1100mv_85c
    slow_1100mv_0c  5_H4_slow_1100mv_0c
    fast_1100mv_85c MIN_fast_1100mv_85c
    fast_1100mv_0c  MIN_fast_1100mv_0c
}

set summary_path [file join $report_dir "emulator_mutrig_syn_20260511_4corner_setup_summary.txt"]
set summary_fh [open $summary_path w]
puts $summary_fh "emulator_mutrig_syn 4-corner setup report"
puts $summary_fh "Generated: [clock format [clock seconds] -format {%Y-%m-%d %H:%M:%S %Z}]"
puts $summary_fh "Project: emulator_mutrig_syn"
puts $summary_fh "Revision: emulator_mutrig_syn"
puts $summary_fh "Clock: clk125, period 7.273 ns, signoff frequency 137.5 MHz"
puts $summary_fh ""

foreach {label op} $corners {
    puts "Analyzing $label ($op)"
    set_operating_conditions $op
    update_timing_netlist
    set detail_path [file join $report_dir "emulator_mutrig_syn_20260511_${label}_setup.rpt"]
    puts $summary_fh "## $label ($op)"
    report_timing -setup -from_clock clk125 -to_clock clk125 -npaths 5 -detail full_path -file $detail_path
    puts $summary_fh "detail_report: $detail_path"
    puts $summary_fh ""
}

close $summary_fh
delete_timing_netlist
project_close
