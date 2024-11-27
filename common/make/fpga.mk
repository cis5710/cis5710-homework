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

time=time -f "command took %E m:s and %M KB"

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
	@echo "     pytest-3 --capture=no --exitfirst testbench.py --tests TEST1,TEST2,..."
	pytest-3 --capture=no --exitfirst testbench.py

# run synthesis to identify code errors/warnings
synth: $(SYNTH_SOURCES)
	mkdir -p $(BACKEND_OUTPUT_DIR)
	$(time) synlig -p "read_systemverilog $(SYNTH_SOURCES); synth_ecp5; write_json $(BACKEND_OUTPUT_DIR)/$(TOP_SYNTH_MODULE)-netlist.json"

# run pnr to generate a bitstream
pnr: $(BACKEND_OUTPUT_DIR)/$(TOP_SYNTH_MODULE)-netlist.json
	$(time) nextpnr-ecp5 --report $(BACKEND_OUTPUT_DIR)/report.json --85k --package CABGA381 --json $^ --textcfg $(BACKEND_OUTPUT_DIR)/$(TOP_SYNTH_MODULE).config --lpf $(CONSTRAINTS)
	python3 -m json.tool $(BACKEND_OUTPUT_DIR)/report.json > $(BACKEND_OUTPUT_DIR)/resource-report.json
	ecppack --compress --freq 62.0 --input $(BACKEND_OUTPUT_DIR)/$(TOP_SYNTH_MODULE).config --bit $(BACKEND_OUTPUT_DIR)/$(TOP_SYNTH_MODULE).bit

# program the device with a bitstream
program:
	openFPGALoader --board ulx3s $(BACKEND_OUTPUT_DIR)/$(TOP_SYNTH_MODULE).bit

# create a zip archive of source code, bitstream, and power/performance/area reports. We filter out warnings because for the ALU-only version of the processor labs we pull in a bitstream, even though the bitstream is only for the full version of the lab
zip: $(ZIP_SOURCES)
	zip -j $(ZIP_FILE) $(ZIP_SOURCES) | grep -v warning

# find path to this Makefile (NB: MAKEFILE_LIST also contains vivado.mk as the 2nd entry)
THIS_MAKEFILE_PATH=$(dir $(realpath $(firstword $(MAKEFILE_LIST))))

# make BOOT.BIN image for programming FPGA from an SD card
# TODO: not working for ULX3S yet
boot: vivado_output/$(BITSTREAM_FILENAME) $(SDBOOT_DIR)/zynq_fsbl_0.elf
ifndef XILINX_VIVADO
	$(error ERROR cannot find Vivado, run "source $(PATH_UPDATE_SOURCE_FILE)")
endif
	echo "the_ROM_image:{[bootloader]"$(SDBOOT_DIR)/zynq_fsbl_0.elf > $(SDBOOT_BIF)
	echo vivado_output/$(BITSTREAM_FILENAME)"}" >> $(SDBOOT_BIF)
	bootgen -image $(SDBOOT_BIF) -arch zynq -o vivado_output/BOOT.BIN

# remove Vivado logs and our hidden file
clean:
	rm -rf sim_build/ fpga_build/ slpp_all/
