QUESTA_HOME ?= /data1/intelFPGA_pro/23.1/questa_fse
VLIB        = $(QUESTA_HOME)/bin/vlib
VMAP        = $(QUESTA_HOME)/bin/vmap
VCOM        = $(QUESTA_HOME)/bin/vcom
VLOG        = $(QUESTA_HOME)/bin/vlog
VSIM        = $(QUESTA_HOME)/bin/vsim
LMUTIL      = $(QUESTA_HOME)/linux_x86_64/lmutil

QUESTA_LICENSE := $(QUESTA_HOME)/LR-287689_License.dat
ETH_LIC_SERVER := 8161@lic-mentor.ethz.ch

export LM_LICENSE_FILE   := $(ETH_LIC_SERVER):$(QUESTA_LICENSE)
export MGLS_LICENSE_FILE := $(LM_LICENSE_FILE)

IP_SRC     = $(realpath ../../rtl)
PARSER_SRC = $(realpath ../../../mutrig_frame_deassembly)
WORK       = work_poisson_delay
TB_TOP     = tb_poisson_delay

HIT_RATE             ?= 0
WARMUP_CYCLES        ?= 50000
MEASURE_CYCLES       ?= 200000
DRAIN_TIMEOUT_CYCLES ?= 400000
OUT_CSV              ?= $(CURDIR)/results/poisson_delay.csv
OUT_SUMMARY          ?= $(CURDIR)/results/poisson_delay.summary

.PHONY: license_check compile run clean

license_check:
	@echo "═══ Checking Mentor floating license at $(ETH_LIC_SERVER) ═══"
	@$(LMUTIL) lmstat -f mtiverification -c $(ETH_LIC_SERVER) >/dev/null 2>&1 || \
	  { echo "ERROR: mtiverification feature not visible via $(ETH_LIC_SERVER)"; exit 1; }

compile: license_check $(WORK)/_vmake

$(WORK)/_vmake: $(IP_SRC)/emulator_mutrig_pkg.sv \
                $(IP_SRC)/prbs15_lfsr.sv \
                $(IP_SRC)/crc16_8.sv \
                $(IP_SRC)/hit_generator.sv \
                $(IP_SRC)/frame_assembler.sv \
                $(IP_SRC)/emulator_mutrig.sv \
                $(PARSER_SRC)/crc16_calc.vhd \
                $(PARSER_SRC)/frame_rcv_ip.vhd \
                tb_poisson_delay.sv
	@echo "═══ Compiling poisson delay bench ═══"
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
	$(VLOG) -work $(WORK) -sv tb_poisson_delay.sv
	@touch $@

run: compile
	@mkdir -p $(dir $(OUT_CSV)) $(dir $(OUT_SUMMARY))
	@echo "═══ Running short-mode poisson delay sweep point HIT_RATE=$(HIT_RATE) ═══"
	$(VSIM) -c -do "quietly set NumericStdNoWarnings 1; quietly set StdArithNoWarnings 1; run -all; quit -f" \
	  -work $(WORK) -t ps -voptargs=+acc \
	  -suppress 19 -suppress 3009 -suppress 3473 \
	  +HIT_RATE=$(HIT_RATE) \
	  +WARMUP_CYCLES=$(WARMUP_CYCLES) \
	  +MEASURE_CYCLES=$(MEASURE_CYCLES) \
	  +DRAIN_TIMEOUT_CYCLES=$(DRAIN_TIMEOUT_CYCLES) \
	  +OUT_CSV=$(OUT_CSV) \
	  +OUT_SUMMARY=$(OUT_SUMMARY) \
	  $(TB_TOP)

clean:
	rm -rf $(WORK) transcript vsim.wlf results
