QUESTA_HOME ?= /data1/intelFPGA_pro/23.1/questa_fse
VLIB        = $(QUESTA_HOME)/bin/vlib
VMAP        = $(QUESTA_HOME)/bin/vmap
VCOM        = $(QUESTA_HOME)/bin/vcom
VLOG        = $(QUESTA_HOME)/bin/vlog
VSIM        = $(QUESTA_HOME)/bin/vsim
VCOVER      = $(QUESTA_HOME)/bin/vcover
LMUTIL      = $(QUESTA_HOME)/linux_x86_64/lmutil

QUESTA_LICENSE := $(QUESTA_HOME)/LR-287689_License.dat
ETH_LIC_SERVER := 8161@lic-mentor.ethz.ch

export LM_LICENSE_FILE   := $(ETH_LIC_SERVER):$(QUESTA_LICENSE)
export MGLS_LICENSE_FILE := $(LM_LICENSE_FILE)

UVM_DIR         := $(abspath .)
IP_ROOT         := $(abspath ../..)
WORKSPACE_ROOT  := $(abspath ../../..)
RTL_DIR         := $(IP_ROOT)/rtl
PARSER_DIR      := $(WORKSPACE_ROOT)/mutrig_frame_deassembly
WORK_DIR        := $(UVM_DIR)/work_uvm
LOG_DIR         := $(UVM_DIR)/logs
COV_DIR         := $(UVM_DIR)/cov
UVM_HOME        ?= $(abspath $(QUESTA_HOME)/verilog_src/uvm-1.2)
UVM_SRC         := $(UVM_HOME)/src
UVM_DPI_SO      := $(firstword $(wildcard $(QUESTA_HOME)/uvm-1.2/linux_x86_64/uvm_dpi.so $(QUESTA_HOME)/verilog_src/uvm-1.2/linux_x86_64/uvm_dpi.so))
UVM_DPI_LIB     := $(basename $(UVM_DPI_SO))
DPI_CPP         ?= /usr/bin/gcc

TEST      ?= emut_test_reset_defaults
SEED      ?= 1
SEEDS     ?= 8
VERBOSITY ?= UVM_MEDIUM
TB_TOP    := tb_top

VCOM_COV ?= -cover bcesft
VLOG_COV ?= +cover=bcesft

UVM_SRCS = \
	$(UVM_DIR)/emut_if.sv \
	$(UVM_DIR)/emut_env_pkg.sv \
	$(UVM_DIR)/emut_csr_driver.sv \
	$(UVM_DIR)/emut_ctrl_driver.sv \
	$(UVM_DIR)/emut_inject_driver.sv \
	$(UVM_DIR)/emut_tx_monitor.sv \
	$(UVM_DIR)/emut_parser_monitor.sv \
	$(UVM_DIR)/emut_scoreboard.sv \
	$(UVM_DIR)/emut_coverage.sv \
	$(UVM_DIR)/emut_env.sv \
	$(UVM_DIR)/emut_sequences.sv \
	$(UVM_DIR)/emut_base_test.sv \
	$(UVM_DIR)/sva/emut_avmm_sva.sv \
	$(UVM_DIR)/sva/emut_ctrl_avst_sva.sv \
	$(UVM_DIR)/sva/emut_tx8b1k_sva.sv \
	$(UVM_DIR)/sva/emut_internal_sva.sv \
	$(UVM_DIR)/tb_top.sv

DIRECTED_TESTS = \
	emut_test_reset_defaults \
	emut_test_idle_and_runctl \
	emut_test_long_inject_single \
	emut_test_short_inject_single \
	emut_test_long_burst_mode \
	emut_test_short_burst_mode \
	emut_test_noise_mode \
	emut_test_disable_and_status \
	emut_test_high_rate_fill \
	emut_test_mode_payload_sweep \
	emut_test_inject_matrix \
	emut_test_short_pack_extra_tail \
	emut_test_auto_low_center \
	emut_test_terminate_no_new_frame

RANDOM_TESTS = \
	emut_test_mixed_random

.PHONY: license_check compile run run_isolated run_bucket_frame_basic run_all_buckets_frame regress merge_cov report closure clean

license_check:
	@echo "═══ Checking Mentor floating license at $(ETH_LIC_SERVER) ═══"
	@$(LMUTIL) lmstat -f mtiverification -c $(ETH_LIC_SERVER) >/dev/null 2>&1 || \
	  { echo "ERROR: mtiverification feature not visible via $(ETH_LIC_SERVER)"; exit 1; }

compile: license_check $(WORK_DIR)/.compiled

$(WORK_DIR)/.compiled: $(RTL_DIR)/emulator_mutrig_pkg.sv \
                       $(RTL_DIR)/prbs15_lfsr.sv \
                       $(RTL_DIR)/crc16_8.sv \
                       $(RTL_DIR)/hit_generator.sv \
                       $(RTL_DIR)/frame_assembler.sv \
                       $(RTL_DIR)/emulator_mutrig.sv \
                       $(PARSER_DIR)/crc16_calc.vhd \
                       $(PARSER_DIR)/frame_rcv_ip.vhd \
                       $(UVM_SRCS)
	@echo "═══ Compiling emulator_mutrig UVM bench ═══"
	@rm -rf $(WORK_DIR)
	@mkdir -p $(WORK_DIR) $(LOG_DIR) $(COV_DIR)
	@cd $(WORK_DIR) && $(VLIB) work
	@cd $(WORK_DIR) && $(VMAP) -c > /dev/null
	@cd $(WORK_DIR) && $(VMAP) -modelsimini modelsim.ini work work > /dev/null
	@cd $(WORK_DIR) && $(VCOM) -2008 $(VCOM_COV) -modelsimini modelsim.ini -work work $(PARSER_DIR)/crc16_calc.vhd
	@cd $(WORK_DIR) && $(VCOM) -2008 $(VCOM_COV) -modelsimini modelsim.ini -work work $(PARSER_DIR)/frame_rcv_ip.vhd
	@cd $(WORK_DIR) && $(VLOG) -modelsimini modelsim.ini -work work $(VLOG_COV) -sv $(RTL_DIR)/emulator_mutrig_pkg.sv
	@cd $(WORK_DIR) && $(VLOG) -modelsimini modelsim.ini -work work $(VLOG_COV) -sv $(RTL_DIR)/prbs15_lfsr.sv
	@cd $(WORK_DIR) && $(VLOG) -modelsimini modelsim.ini -work work $(VLOG_COV) -sv $(RTL_DIR)/crc16_8.sv
	@cd $(WORK_DIR) && $(VLOG) -modelsimini modelsim.ini -work work $(VLOG_COV) -sv $(RTL_DIR)/hit_generator.sv
	@cd $(WORK_DIR) && $(VLOG) -modelsimini modelsim.ini -work work $(VLOG_COV) -sv $(RTL_DIR)/frame_assembler.sv
	@cd $(WORK_DIR) && $(VLOG) -modelsimini modelsim.ini -work work $(VLOG_COV) -sv $(RTL_DIR)/emulator_mutrig.sv
	@cd $(WORK_DIR) && $(VLOG) -modelsimini modelsim.ini -work work $(VLOG_COV) -sv $(UVM_DIR)/emut_if.sv
	@cd $(WORK_DIR) && $(VLOG) -modelsimini modelsim.ini -work work $(VLOG_COV) -mfcu \
	  +incdir+$(UVM_SRC) +incdir+$(UVM_DIR) -sv \
	  $(UVM_SRC)/uvm_pkg.sv \
	  $(UVM_DIR)/emut_env_pkg.sv \
	  $(UVM_DIR)/sva/emut_avmm_sva.sv \
	  $(UVM_DIR)/sva/emut_ctrl_avst_sva.sv \
	  $(UVM_DIR)/sva/emut_tx8b1k_sva.sv \
	  $(UVM_DIR)/sva/emut_internal_sva.sv \
	  $(UVM_DIR)/tb_top.sv
	@touch $@

run: compile
	@echo "=== Running $(TEST) seed=$(SEED) ==="
	@mkdir -p $(COV_DIR)
	@rm -f $(COV_DIR)/$(TEST)_s$(SEED).ucdb
	@cd $(WORK_DIR) && $(VSIM) -modelsimini modelsim.ini -c -coverage \
	  -dpicpppath $(DPI_CPP) -sv_lib $(UVM_DPI_LIB) \
	  -sv_seed $(SEED) \
	  +UVM_TESTNAME=$(TEST) +UVM_VERBOSITY=$(VERBOSITY) \
	  -suppress 19 -suppress 3009 -suppress 3473 -voptargs="+acc" \
	  work.$(TB_TOP) \
	  -do "quietly set NumericStdNoWarnings 1; quietly set StdArithNoWarnings 1; coverage save -onexit $(COV_DIR)/$(TEST)_s$(SEED).ucdb; run -all; quit -f" \
	  | tee $(LOG_DIR)/$(TEST)_s$(SEED).log
	@if grep -qE '\*\* Fatal:|\*\* Error:' $(LOG_DIR)/$(TEST)_s$(SEED).log; then \
	  echo "FAIL: $(TEST) seed=$(SEED)"; exit 1; \
	elif ! grep -q '\*\*\* TEST PASSED \*\*\*' $(LOG_DIR)/$(TEST)_s$(SEED).log; then \
	  echo "FAIL: $(TEST) seed=$(SEED)"; exit 1; \
	else \
	  echo "PASS: $(TEST) seed=$(SEED)"; \
	fi

run_isolated:
	@$(MAKE) -s run TEST=$(TEST) SEED=$(SEED)

run_bucket_frame_basic:
	@$(MAKE) -s run TEST=emut_test_bucket_frame_basic SEED=$(SEED)

run_all_buckets_frame:
	@$(MAKE) -s run TEST=emut_test_all_buckets_frame SEED=$(SEED)

regress: compile
	@echo "=== emulator_mutrig UVM regression ==="
	@pass=0; fail=0; total=0; \
	for t in $(DIRECTED_TESTS); do \
	  total=$$((total+1)); \
	  echo "--- [$$total] $$t ---"; \
	  if $(MAKE) -s run TEST=$$t SEED=1 >/dev/null 2>&1; then \
	    pass=$$((pass+1)); echo "  PASS"; \
	  else \
	    fail=$$((fail+1)); echo "  FAIL"; \
	  fi; \
	done; \
	for t in $(RANDOM_TESTS); do \
	  for s in $$(seq 1 $(SEEDS)); do \
	    total=$$((total+1)); \
	    echo "--- [$$total] $$t seed=$$s ---"; \
	    if $(MAKE) -s run TEST=$$t SEED=$$s >/dev/null 2>&1; then \
	      pass=$$((pass+1)); echo "  PASS"; \
	    else \
	      fail=$$((fail+1)); echo "  FAIL"; \
	    fi; \
	  done; \
	done; \
	echo ""; \
	echo "=== REGRESSION SUMMARY: $$pass/$$total passed, $$fail failed ==="; \
	if [ $$fail -gt 0 ]; then exit 1; fi

merge_cov:
	@rm -f $(COV_DIR)/merged.ucdb
	@$(VCOVER) merge $(COV_DIR)/merged.ucdb $(COV_DIR)/*.ucdb

report: merge_cov
	@$(VCOVER) report -details -code bcesft $(COV_DIR)/merged.ucdb | tee $(COV_DIR)/merged.txt

closure: regress report

clean:
	rm -rf $(WORK_DIR) $(LOG_DIR) $(COV_DIR) transcript vsim.wlf
