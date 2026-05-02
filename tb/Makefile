include ../../scripts/questa_one.mk

IP_SRC     = $(realpath ../rtl)
PARSER_SRC = $(realpath ../../mutrig_frame_deassembly)
WORK       = work_emu_mutrig
CENTRAL_WORK = work_emu_mutrig_central
TB_TOP     = tb_emulator_mutrig

TEST ?= B01_lfsr
SEED ?= 42

.PHONY: license_check compile central_compile central_smoke run run_all clean

license_check:
	@echo "═══ Checking Mentor floating license at $(QUESTA_LICENSE_SERVER) ═══"
	@$(LMUTIL) lmstat -f mtiverification -c $(QUESTA_LICENSE_SERVER) >/dev/null 2>&1 || \
	  { echo "ERROR: mtiverification feature not visible via $(QUESTA_LICENSE_SERVER)"; exit 1; }

compile: license_check $(WORK)/_vmake

central_compile: license_check
	@echo "═══ Compiling emulator_mutrig central-trigger RTL ═══"
	rm -rf $(CENTRAL_WORK)
	$(VLIB) $(CENTRAL_WORK)
	$(VMAP) $(CENTRAL_WORK) $(CENTRAL_WORK)
	cd ../rtl && $(VLOG) -work ../tb/$(CENTRAL_WORK) -sv -f emulator_mutrig_central_trigger.f

central_smoke: central_compile
	@echo "═══ Elaborating emulator_mutrig central-trigger RTL smoke ═══"
	$(VSIM) -c -do "run 0; quit -f" \
	  -work $(CENTRAL_WORK) -t ps \
	  -G LANE_COUNT=8 -G BYTE_STREAM_ENABLE=0 \
	  emulator_mutrig

central_run_short: central_compile
	@echo "═══ Running short stim on central-trigger top (no UVM, just clock + reset) ═══"
	$(VSIM) -c -do "force -freeze i_clk 0 0, 1 {4 ns} -repeat 8 ns; force -freeze i_rst 1 0; force -freeze i_rst 0 100 ns; force -freeze asi_ctrl_data 9'b000000001 0; force -freeze asi_ctrl_valid 1 0; force -freeze coe_inject_pulse 0 0; force -freeze avs_csr_address 0 0; force -freeze avs_csr_read 0 0; force -freeze avs_csr_write 0 0; force -freeze avs_csr_writedata 0 0; run 1 us; quit -f" \
	  -work $(CENTRAL_WORK) -t ps \
	  -G LANE_COUNT=8 -G BYTE_STREAM_ENABLE=0 \
	  emulator_mutrig

central_basic: central_compile
	@echo "═══ Compiling tb_central_top BASIC bucket ═══"
	cd uvm && $(VLOG) -work ../$(CENTRAL_WORK) -sv tb_central_top.sv
	@echo "═══ Running tb_central_top (full 512-case bucket) ═══"
	$(VSIM) -c -do "run -all; quit -f" \
	  -work $(CENTRAL_WORK) -t ps \
	  tb_central_top

# Coverage-enabled compile: pass +cover to vlog to instrument the DUT.
central_compile_cov: license_check
	@echo "═══ Compiling emulator_mutrig RTL with coverage (statement, branch, condition, expression, fsm, toggle) ═══"
	rm -rf $(CENTRAL_WORK)
	$(VLIB) $(CENTRAL_WORK)
	$(VMAP) $(CENTRAL_WORK) $(CENTRAL_WORK)
	cd ../rtl && $(VLOG) -work ../tb/$(CENTRAL_WORK) -sv +cover=sbcetf -f emulator_mutrig_central_trigger.f
	cd uvm && $(VLOG) -work ../$(CENTRAL_WORK) -sv tb_central_top.sv

# Per-bucket coverage capture: vsim with -coverage, save bucket-level UCDBs
# inside the simulation, then vcover-merge them into a single all-buckets
# UCDB plus a text report. UCDBs land under tb/uvm/log/ucdb/.
UCDB_DIR := uvm/log/ucdb
central_basic_cov: central_compile_cov
	@echo "═══ Running tb_central_top with coverage on (BASIC+EDGE+PROF+ERROR+EXTRA+LONG, exclusions per FEATURE_AXES.md) ═══"
	mkdir -p $(UCDB_DIR)
	$(VSIM) -c -coverage -do "do uvm/cov_excludes.do; coverage save -onexit $(UCDB_DIR)/all_buckets.ucdb; run -all; quit -f" \
	  -work $(CENTRAL_WORK) -t ps \
	  +EXTRA=1 +LONG=1 \
	  tb_central_top
	@echo "═══ Generating coverage report ═══"
	/data1/questaone_sim/questasim/bin/vcover report -details $(UCDB_DIR)/all_buckets.ucdb \
	  -output $(UCDB_DIR)/all_buckets.cov.rpt
	/data1/questaone_sim/questasim/bin/vcover report -summary $(UCDB_DIR)/all_buckets.ucdb \
	  -output $(UCDB_DIR)/all_buckets.summary
	@echo "═══ Coverage summary ═══"
	@cat $(UCDB_DIR)/all_buckets.summary | head -60

# Quick non-coverage compile + extended-case run for fast iteration
central_basic_extra: central_compile
	@echo "═══ Compiling tb_central_top with extra cases ═══"
	cd uvm && $(VLOG) -work ../$(CENTRAL_WORK) -sv tb_central_top.sv
	@echo "═══ Running with extra cases ═══"
	$(VSIM) -c -do "run -all; quit -f" \
	  -work $(CENTRAL_WORK) -t ps \
	  +EXTRA=1 \
	  tb_central_top

$(WORK)/_vmake: $(IP_SRC)/emulator_mutrig_pkg.sv \
                $(IP_SRC)/prbs15_lfsr.sv \
                $(IP_SRC)/crc16_8.sv \
                $(IP_SRC)/hit_generator.sv \
                $(IP_SRC)/frame_assembler.sv \
                $(IP_SRC)/emulator_mutrig.sv \
                $(PARSER_SRC)/crc16_calc.vhd \
                $(PARSER_SRC)/frame_rcv_ip.vhd \
                tb_emulator_mutrig.sv
	@echo "═══ Compiling emulator_mutrig testbench ═══"
	rm -rf $(WORK)
	$(VLIB) $(WORK)
	$(VMAP) $(WORK) $(WORK)
	$(VCOM) -2008 -work $(WORK) $(PARSER_SRC)/crc16_calc.vhd
	$(VCOM) -2008 -work $(WORK) $(PARSER_SRC)/frame_rcv_ip.vhd
	$(VLOG) -work $(WORK) -sv $(IP_SRC)/emulator_mutrig_pkg.sv
	$(VLOG) -work $(WORK) -sv $(IP_SRC)/prbs15_lfsr.sv
	$(VLOG) -work $(WORK) -sv $(IP_SRC)/crc16_8.sv
	$(VLOG) -work $(WORK) -sv $(IP_SRC)/hit_generator.sv
	$(VLOG) -work $(WORK) -sv $(IP_SRC)/frame_assembler.sv
	$(VLOG) -work $(WORK) -sv $(IP_SRC)/emulator_mutrig.sv
	$(VLOG) -work $(WORK) -sv tb_emulator_mutrig.sv
	@touch $@

run: compile
	@echo "═══ Running TEST=$(TEST) SEED=$(SEED) ═══"
	$(VSIM) -c -do "quietly set NumericStdNoWarnings 1; quietly set StdArithNoWarnings 1; run -all; quit -f" \
	  -work $(WORK) -t ps -voptargs=+acc \
	  -suppress 19 -suppress 3009 -suppress 3473 \
	  +TEST=$(TEST) +SEED=$(SEED) \
	  $(TB_TOP)

run_all: compile
	@echo "═══ Running ALL tests ═══"
	$(VSIM) -c -do "quietly set NumericStdNoWarnings 1; quietly set StdArithNoWarnings 1; run -all; quit -f" \
	  -work $(WORK) -t ps -voptargs=+acc \
	  -suppress 19 -suppress 3009 -suppress 3473 \
	  +TEST=ALL +SEED=$(SEED) \
	  $(TB_TOP)

clean:
	rm -rf $(WORK) $(CENTRAL_WORK) transcript vsim.wlf
