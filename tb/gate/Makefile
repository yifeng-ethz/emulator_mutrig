QUESTA_HOME ?= /data1/intelFPGA_pro/23.1/questa_fse
Q18_SIMLIB  ?= /data1/intelFPGA/18.1/quartus/eda/sim_lib

VLIB  = $(QUESTA_HOME)/bin/vlib
VMAP  = $(QUESTA_HOME)/bin/vmap
VCOM  = $(QUESTA_HOME)/bin/vcom
VLOG  = $(QUESTA_HOME)/bin/vlog
VSIM  = $(QUESTA_HOME)/bin/vsim
LMUTIL = $(QUESTA_HOME)/linux_x86_64/lmutil

QUESTA_LICENSE := $(QUESTA_HOME)/LR-287689_License.dat
ETH_LIC_SERVER := 8161@lic-mentor.ethz.ch

export LM_LICENSE_FILE   := $(ETH_LIC_SERVER):$(QUESTA_LICENSE)
export MGLS_LICENSE_FILE := $(LM_LICENSE_FILE)

PARSER_SRC  = $(realpath ../../../mutrig_frame_deassembly)
IP_SRC      = $(realpath ../../rtl)
NETLIST_DIR = $(realpath ../../syn/quartus/gate_sim)
NETLIST_V   = $(NETLIST_DIR)/emulator_mutrig_syn.vo
TB_SRC      = $(realpath ../tb_emulator_mutrig.sv)
WORK        = work_gate
LIBDIR      = gate_verilog_libs
TB_TOP      = tb_emulator_mutrig

TEST ?= ALL
SEED ?= 42

.PHONY: license_check gate_netlist libs compile run run_all clean

license_check:
	@echo "═══ Checking Mentor floating license at $(ETH_LIC_SERVER) ═══"
	@$(LMUTIL) lmstat -f mtiverification -c $(ETH_LIC_SERVER) >/dev/null 2>&1 || \
	  { echo "ERROR: mtiverification feature not visible via $(ETH_LIC_SERVER)"; exit 1; }

gate_netlist:
	@echo "═══ Regenerating Quartus post-fit functional gate netlist ═══"
	cd ../../syn/quartus && quartus_eda emulator_mutrig_syn -c emulator_mutrig_syn --simulation --tool=modelsim --format=verilog --output_directory gate_sim --gen_script=gate_level

$(LIBDIR)/arriav_ver/_info: | license_check
	@echo "═══ Compiling Quartus simulation libraries for gate netlist ═══"
	rm -rf $(LIBDIR)
	mkdir -p $(LIBDIR)
	$(VLIB) $(LIBDIR)/altera_lnsim_ver
	$(VMAP) altera_lnsim_ver $(LIBDIR)/altera_lnsim_ver
	$(VLOG) -sv -work altera_lnsim_ver $(Q18_SIMLIB)/altera_lnsim.sv
	$(VLIB) $(LIBDIR)/altera_ver
	$(VMAP) altera_ver $(LIBDIR)/altera_ver
	$(VLOG) -vlog01compat -work altera_ver $(Q18_SIMLIB)/altera_primitives.v
	$(VLIB) $(LIBDIR)/lpm_ver
	$(VMAP) lpm_ver $(LIBDIR)/lpm_ver
	$(VLOG) -vlog01compat -work lpm_ver $(Q18_SIMLIB)/220model.v
	$(VLIB) $(LIBDIR)/sgate_ver
	$(VMAP) sgate_ver $(LIBDIR)/sgate_ver
	$(VLOG) -vlog01compat -work sgate_ver $(Q18_SIMLIB)/sgate.v
	$(VLIB) $(LIBDIR)/altera_mf_ver
	$(VMAP) altera_mf_ver $(LIBDIR)/altera_mf_ver
	$(VLOG) -vlog01compat -work altera_mf_ver $(Q18_SIMLIB)/altera_mf.v
	$(VLIB) $(LIBDIR)/arriav_ver
	$(VMAP) arriav_ver $(LIBDIR)/arriav_ver
	$(VLOG) -vlog01compat -work arriav_ver $(Q18_SIMLIB)/mentor/arriav_atoms_ncrypt.v
	$(VLOG) -vlog01compat -work arriav_ver $(Q18_SIMLIB)/mentor/arriav_hmi_atoms_ncrypt.v
	$(VLOG) -vlog01compat -work arriav_ver $(Q18_SIMLIB)/arriav_atoms.v

libs: $(LIBDIR)/arriav_ver/_info

compile: gate_netlist libs $(WORK)/_vmake

$(WORK)/_vmake: $(NETLIST_V) $(TB_SRC) emulator_mutrig_gate_shim.sv $(IP_SRC)/emulator_mutrig_pkg.sv | libs
	@echo "═══ Compiling emulator_mutrig gate-level bench ═══"
	rm -rf $(WORK)
	$(VLIB) $(WORK)
	$(VMAP) work $(WORK)
	$(VCOM) -2008 -work $(WORK) $(PARSER_SRC)/crc16_calc.vhd
	$(VCOM) -2008 -work $(WORK) $(PARSER_SRC)/frame_rcv_ip.vhd
	$(VLOG) -work $(WORK) -sv $(IP_SRC)/emulator_mutrig_pkg.sv
	$(VLOG) -work $(WORK) -vlog01compat +incdir+$(NETLIST_DIR) $(NETLIST_V)
	$(VLOG) -work $(WORK) -sv emulator_mutrig_gate_shim.sv
	$(VLOG) -work $(WORK) -sv +define+EMUT_GATE_SIM $(TB_SRC)
	@touch $@

run: compile
	@echo "═══ Running gate TEST=$(TEST) SEED=$(SEED) ═══"
	$(VSIM) -c -do "quietly set NumericStdNoWarnings 1; quietly set StdArithNoWarnings 1; run -all; quit -f" \
	  -L altera_lnsim_ver -L altera_ver -L lpm_ver -L sgate_ver -L altera_mf_ver -L arriav_ver \
	  -work $(WORK) -t ps -voptargs=+acc \
	  -suppress 19 -suppress 3009 -suppress 3473 \
	  +TEST=$(TEST) +SEED=$(SEED) \
	  $(TB_TOP)

run_all: run

clean:
	rm -rf $(WORK) $(LIBDIR) transcript vsim.wlf
