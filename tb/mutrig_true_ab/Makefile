QUESTA_HOME      ?= /data1/intelFPGA_pro/23.1/questa_fse
VLIB             = $(QUESTA_HOME)/bin/vlib
VMAP             = $(QUESTA_HOME)/bin/vmap
VCOM             = $(QUESTA_HOME)/bin/vcom
VLOG             = $(QUESTA_HOME)/bin/vlog
VSIM             = $(QUESTA_HOME)/bin/vsim
LMUTIL           = $(QUESTA_HOME)/linux_x86_64/lmutil
QUESTA_LICENSE   := $(QUESTA_HOME)/LR-287689_License.dat
ETH_LIC_SERVER   := 8161@lic-mentor.ethz.ch

export LM_LICENSE_FILE   := $(ETH_LIC_SERVER):$(QUESTA_LICENSE)
export MGLS_LICENSE_FILE := $(LM_LICENSE_FILE)

TOP              ?= tb_mutrig_true_ab
WORK             ?= work_mutrig_true_ab
EMU_WORK         ?= emuwork_mutrig_true_ab
BUILD_DIR        ?= build
RESULTS_DIR      ?= results
RATE_CFG         ?= 0
SHORT_MODE       ?= 1
SEED             ?= 1
WARMUP_CYCLES    ?= 50000
MEASURE_CYCLES   ?= 200000
DRAIN_TIMEOUT_CYCLES ?= 400000
ASIC_ID          ?= 3
TRACE_TX         ?= 0
OUT_TAG          ?= $(if $(filter 1,$(SHORT_MODE)),short,long)_r$(RATE_CFG)_s$(SEED)
OUT_CSV          ?= $(abspath $(RESULTS_DIR))/$(OUT_TAG).csv
OUT_SUMMARY      ?= $(abspath $(RESULTS_DIR))/$(OUT_TAG).summary

REPO_ROOT        := $(abspath ../..)
RAW_ROOT         := /home/yifeng/kbriggl-mutrig3-c3cce8d41dcb/units
SUPPORT_ROOT     := $(REPO_ROOT)/tlm/raw_support
PARSER_ROOT      := $(REPO_ROOT)/../mutrig_frame_deassembly/rtl

SV_LIB           := $(abspath $(BUILD_DIR))/libemut_ab_dpi

.PHONY: all license_check compile run clean

all: run

$(BUILD_DIR):
	mkdir -p $(BUILD_DIR)

$(RESULTS_DIR):
	mkdir -p $(RESULTS_DIR)

$(SV_LIB).so: dpi/emut_ab_dpi.c | $(BUILD_DIR)
	gcc -O2 -fPIC -shared -o $@ $<

compile: $(SV_LIB).so | $(RESULTS_DIR)
license_check:
	@echo "═══ Checking Mentor floating license at $(ETH_LIC_SERVER) ═══"
	@$(LMUTIL) lmstat -f mtiverification -c $(ETH_LIC_SERVER) >/dev/null 2>&1 || \
	  { echo "ERROR: mtiverification feature not visible via $(ETH_LIC_SERVER)"; exit 1; }

compile: license_check $(SV_LIB).so | $(RESULTS_DIR)
	$(VLIB) $(WORK)
	$(VMAP) work $(WORK)
	$(VLIB) $(EMU_WORK)
	$(VMAP) emuwork $(EMU_WORK)
	$(VCOM) -work work -2008 $(RAW_ROOT)/datapath_defs/source/rtl/vhdl/datapath_helpers.vhd
	$(VCOM) -work work -2008 $(RAW_ROOT)/datapath_defs/source/rtl/vhdl/datapath_types.vhd
	$(VCOM) -work work -2008 $(RAW_ROOT)/datapath_defs/source/rtl/vhdl/serial_comm_defs.vhd
	$(VCOM) -work work -2008 $(RAW_ROOT)/datapath_defs/source/rtl/vhdl/txt_util.vhd
	$(VCOM) -work work -2008 $(SUPPORT_ROOT)/hdlcore_lib/generic_memory/generic_dp_fifo/source/rtl/vhdl/generic_dp_fifo.vhd
	$(VCOM) -work work -2008 $(RAW_ROOT)/frame_generator/source/rtl/vhdl/crc16_8.vhd
	$(VCOM) -work work -2008 $(RAW_ROOT)/frame_generator/source/rtl/vhdl/frame_generator.vhd
	$(VCOM) -work work -2008 $(PARSER_ROOT)/crc16_calc.vhd
	$(VCOM) -work work -2008 $(PARSER_ROOT)/frame_rcv_ip.vhd
	$(VCOM) -work work -2008 raw_mutrig_frame_top.vhd
	$(VLOG) -work work -sv $(REPO_ROOT)/rtl/emulator_mutrig_pkg.sv
	$(VLOG) -work emuwork -sv $(REPO_ROOT)/rtl/emulator_mutrig_pkg.sv
	$(VLOG) -work emuwork -sv $(REPO_ROOT)/rtl/crc16_8.sv
	$(VLOG) -work emuwork -sv $(REPO_ROOT)/rtl/hit_generator.sv
	$(VLOG) -work emuwork -sv $(REPO_ROOT)/rtl/frame_assembler.sv
	$(VLOG) -work emuwork -sv emut_frame_top_direct.sv
	$(VLOG) -work work -L emuwork -sv tb_mutrig_true_ab.sv

run: compile
	$(VSIM) -c -L emuwork -sv_lib $(SV_LIB) -work $(WORK) -t ps \
		-suppress 19 -suppress 3009 -suppress 3473 \
		work.$(TOP) \
		+RATE_CFG=$(RATE_CFG) \
		+SHORT_MODE=$(SHORT_MODE) \
		+SEED=$(SEED) \
		+WARMUP_CYCLES=$(WARMUP_CYCLES) \
		+MEASURE_CYCLES=$(MEASURE_CYCLES) \
		+DRAIN_TIMEOUT_CYCLES=$(DRAIN_TIMEOUT_CYCLES) \
		+ASIC_ID=$(ASIC_ID) \
		+TRACE_TX=$(TRACE_TX) \
		+OUT_CSV=$(OUT_CSV) \
		+OUT_SUMMARY=$(OUT_SUMMARY) \
		-do "quietly set NumericStdNoWarnings 1; quietly set StdArithNoWarnings 1; run -all; quit -f"

clean:
	rm -rf $(WORK) $(EMU_WORK) $(BUILD_DIR) transcript vsim.wlf $(RESULTS_DIR)/*.csv $(RESULTS_DIR)/*.summary
