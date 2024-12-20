# Check that given variables are set and all have non-empty values,
# die with an error otherwise.
#
# Params:
#   1. Variable name(s) to test.
#   2. (optional) Error message to print.
# c/o https://stackoverflow.com/questions/10858261/abort-makefile-if-variable-not-set
check_defined = \
    $(strip $(foreach 1,$1, \
        $(call __check_defined,$1,$(strip $(value 2)))))
__check_defined = \
    $(if $(value $1),, \
      $(error Undefined $1$(if $2, ($2))))

# variables that should be defined for all homeworks
$(call check_defined, SYNTH_SOURCES TOP_SYNTH_MODULE, Each homework Makefile should define this)

ifdef TOP_IMPL_MODULE
$(call check_defined, IMPL_SOURCES TOP_IMPL_MODULE BITSTREAM_FILENAME CONSTRAINTS, Each implementation homework Makefile should define this)
endif

ifdef ZIP_SOURCES
$(call check_defined, ZIP_SOURCES ZIP_FILE, Each homework Makefile where a zip file is submitted should define this)
endif

# shorthand variables for constraint files and Tcl scripts
# NB: COMMON_DIR is wrt the Makefile in each lab's directory, not wrt this file
COMMON_DIR=../common
TCL_DIR=$(COMMON_DIR)/tcl
SDBOOT_DIR=$(COMMON_DIR)/sdcard-boot
SDBOOT_BIF=.boot.bif
PATH_UPDATE_SOURCE_FILE=~cis5710/tools/cis5710-update-path.sh
BACKEND_OUTPUT_DIR=fpga_build

time=/usr/bin/time -f 'command took %E m:s and %M KB'

# NB: the .set_testcase.v target does create a file .set_testcase.v, but we want it to run every time so we declare it phony
.PHONY: codecheck test synth pnr program pennsim boot clean

# if invoked with no explicit target, print out a help message
.DEFAULT: help
help:
	@echo -e "Valid targets are: codecheck test synth pnr zip program boot clean"

codecheck:
	python3 codecheck.py

test:
	@echo You can run just specific tests via:
	@echo "     pytest-3 --exitfirst --capture=no testbench.py --tests TEST1,TEST2,..."
	pytest-3 --capture=no --exitfirst testbench.py

# run synthesis to identify code errors/warnings
synth: $(SYNTH_SOURCES)
	mkdir -p $(BACKEND_OUTPUT_DIR)
	bash -c "$(time) synlig -p \"systemverilog_defines -DSYNTHESIS; read_systemverilog $(SYNTH_SOURCES); synth_ecp5 -top $(TOP_SYNTH_MODULE); write_json $(BACKEND_OUTPUT_DIR)/$(TOP_SYNTH_MODULE)-netlist.json\" 2>&1 | tee $(BACKEND_OUTPUT_DIR)/synth.log"

synth-yosys: $(SYNTH_SOURCES)
	mkdir -p $(BACKEND_OUTPUT_DIR)
	bash -c "set -o pipefail; $(time) yosys -p \"verilog_defines -DSYNTHESIS; read -vlog2k $(SYNTH_SOURCES); synth_ecp5 -top $(TOP_SYNTH_MODULE) -json $(BACKEND_OUTPUT_DIR)/$(TOP_SYNTH_MODULE)-netlist.json\" 2>&1 | tee $(BACKEND_OUTPUT_DIR)/synth.log"

# run pnr to generate a bitstream
pnr: $(BACKEND_OUTPUT_DIR)/$(TOP_SYNTH_MODULE)-netlist.json
	bash -c "$(time) nextpnr-ecp5 --report $(BACKEND_OUTPUT_DIR)/report.json --85k --package CABGA381 --json $^ --textcfg $(BACKEND_OUTPUT_DIR)/$(TOP_SYNTH_MODULE).config --lpf $(CONSTRAINTS) --lpf-allow-unconstrained 2>&1 | tee $(BACKEND_OUTPUT_DIR)/pnr.log"
	python3 -m json.tool $(BACKEND_OUTPUT_DIR)/report.json > $(BACKEND_OUTPUT_DIR)/resource-report.json
	bash -c "ecppack --compress --freq 62.0 --input $(BACKEND_OUTPUT_DIR)/$(TOP_SYNTH_MODULE).config --bit $(BACKEND_OUTPUT_DIR)/$(TOP_SYNTH_MODULE).bit 2>&1 | tee $(BACKEND_OUTPUT_DIR)/ecppack.log"

# program the device with a bitstream
program:
	openFPGALoader --freq 3000000 --board ulx3s $(BACKEND_OUTPUT_DIR)/$(TOP_SYNTH_MODULE).bit

# create a zip archive of source code, bitstream, and power/performance/area reports. We filter out warnings because for the ALU-only version of the processor labs we pull in a bitstream, even though the bitstream is only for the full version of the lab
zip: $(ZIP_SOURCES)
	zip -j $(ZIP_FILE) $(ZIP_SOURCES) | grep -v warning

# make BOOT.BIN image for programming FPGA from an SD card
# TODO: not working for ULX3S, I don't think it can program FPGA from the SD card
boot: vivado_output/$(BITSTREAM_FILENAME) $(SDBOOT_DIR)/zynq_fsbl_0.elf
ifndef XILINX_VIVADO
	$(error ERROR cannot find Vivado, run "source $(PATH_UPDATE_SOURCE_FILE)")
endif
	echo "the_ROM_image:{[bootloader]"$(SDBOOT_DIR)/zynq_fsbl_0.elf > $(SDBOOT_BIF)
	echo vivado_output/$(BITSTREAM_FILENAME)"}" >> $(SDBOOT_BIF)
	bootgen -image $(SDBOOT_BIF) -arch zynq -o vivado_output/BOOT.BIN

# remove build files
clean:
	rm -rf points.json sim_build/ $(BACKEND_OUTPUT_DIR)/ slpp_all/
