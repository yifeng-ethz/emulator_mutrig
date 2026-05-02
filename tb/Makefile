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
