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

ifdef SV_SYNTH_SOURCES
$(call check_defined, SV_SYNTH_SOURCES VERILOG_SYNTH_SOURCE TOP_MODULE_RESOURCE_CHECK CONSTRAINTS, Each homework with a demo should define this in Makefile)
endif

ifdef ZIP_SOURCES
$(call check_defined, ZIP_SOURCES ZIP_FILE, Each homework Makefile where a zip file is submitted should define this)
endif

# shorthand variables for commonly-referenced things
BACKEND_OUTPUT_DIR=fpga_build

#time=/usr/bin/time -f 'command took %E m:s and %M KB'
time=/usr/bin/time

.PHONY: codecheck test synth clock-gen pnr program clean

# if invoked with no explicit target, print out a help message
.DEFAULT: help
help:
	@echo -e "Valid targets are: codecheck test synth pnr zip program boot clean"

codecheck:
	python3 codecheck.py

test:
	@echo You can run just specific tests via:
	@echo "     MAKEFLAGS=-j4 pytest --exitfirst --capture=no -k runCocotbTests_ADD_TEST_COLLECTION_HERE testbench.py --tests TEST1,TEST2,..."
	MAKEFLAGS=-j4 pytest --capture=no --exitfirst testbench.py

demo:
	$(MAKE) synth-yosys-fast pnr-fast TOP_MODULE=$(TOP_MODULE_DEMO)

demo-slow:
	$(MAKE) synth-yosys pnr TOP_MODULE=$(TOP_MODULE_DEMO)

resource-check:
	$(MAKE) synth-yosys pnr TOP_MODULE=$(TOP_MODULE_RESOURCE_CHECK)

check-logs:
	-grep -iE '(warning|error|fail|removing unused)' $(BACKEND_OUTPUT_DIR)/*.log | grep -Ev '(Removing unused module ..abstract|Removing unused output signal .0.[id]cache.current_state|Replacing memory.*with list of registers)' | grep --color=always -iE '(warning|error|fail|removing unused)'

$(VERILOG_SYNTH_SOURCE): $(SV_SYNTH_SOURCES) clock-gen
	sv2v -DSYNTHESIS $(SV_SYNTH_SOURCES) --write=$(VERILOG_SYNTH_SOURCE) --top=$(TOP_MODULE) --incdir=`pwd`

synth: synth-yosys

synth-yosys: $(VERILOG_SYNTH_SOURCE)
	mkdir -p $(BACKEND_OUTPUT_DIR)
	bash -c "set -o pipefail; $(time) yosys -p \"verilog_defines -DSYNTHESIS; read -vlog2k $^; synth_ecp5 -top $(TOP_MODULE) -json $(BACKEND_OUTPUT_DIR)/$(TOP_MODULE)-netlist.json\" 2>&1 | tee $(BACKEND_OUTPUT_DIR)/synth.log"

synth-yosys-fast: $(VERILOG_SYNTH_SOURCE)
	mkdir -p $(BACKEND_OUTPUT_DIR)
	bash -c "set -o pipefail; $(time) yosys -p \"verilog_defines -DSYNTHESIS; read -vlog2k $^; synth_ecp5 -noabc9 -run begin:check -top $(TOP_MODULE); hierarchy -check; stat; check -noinit; blackbox =A:whitebox; write_json $(BACKEND_OUTPUT_DIR)/$(TOP_MODULE)-netlist.json\" 2>&1 | tee $(BACKEND_OUTPUT_DIR)/synth.log"

# run pnr to generate a bitstream
pnr: $(BACKEND_OUTPUT_DIR)/$(TOP_MODULE)-netlist.json
	bash -c "set -o pipefail; $(time) nextpnr-ecp5 --report $(BACKEND_OUTPUT_DIR)/report.json --85k --package CABGA381 --json $< --textcfg $(BACKEND_OUTPUT_DIR)/$(TOP_MODULE).config --lpf $(CONSTRAINTS) 2>&1 | tee $(BACKEND_OUTPUT_DIR)/pnr.log"
	python3 -m json.tool $(BACKEND_OUTPUT_DIR)/report.json > $(BACKEND_OUTPUT_DIR)/resource-report.json
	bash -c "set -o pipefail; ecppack --compress --freq 62.0 --input $(BACKEND_OUTPUT_DIR)/$(TOP_MODULE).config --bit $(BACKEND_OUTPUT_DIR)/$(TOP_MODULE).bit 2>&1 | tee $(BACKEND_OUTPUT_DIR)/ecppack.log"

pnr-fast: $(BACKEND_OUTPUT_DIR)/$(TOP_MODULE)-netlist.json
	bash -c "set -o pipefail; $(time) nextpnr-ecp5 --report $(BACKEND_OUTPUT_DIR)/report.json --85k --package CABGA381 --json $< --textcfg $(BACKEND_OUTPUT_DIR)/$(TOP_MODULE).config --lpf $(CONSTRAINTS) --no-tmdriv --placer heap 2>&1 | tee $(BACKEND_OUTPUT_DIR)/pnr.log"
	python3 -m json.tool $(BACKEND_OUTPUT_DIR)/report.json > $(BACKEND_OUTPUT_DIR)/resource-report.json
	bash -c "set -o pipefail; ecppack --compress --freq 62.0 --input $(BACKEND_OUTPUT_DIR)/$(TOP_MODULE).config --bit $(BACKEND_OUTPUT_DIR)/$(TOP_MODULE).bit 2>&1 | tee $(BACKEND_OUTPUT_DIR)/ecppack.log"

# program the device with a bitstream
program:
	openFPGALoader --freq 3000000 --board ulx3s $(BACKEND_OUTPUT_DIR)/$(TOP_MODULE_DEMO).bit

# create a zip archive of source code, bitstream, and power/performance/area
# reports. We filter out warnings because for the ALU-only version of the
# processor labs we pull in a bitstream, even though the bitstream is only for
# the full version of the lab
zip: $(ZIP_SOURCES)
	zip -j $(ZIP_FILE) $(ZIP_SOURCES) | grep -v warning

# remove build files
clean:
	rm -rf points.json sim_build/ $(BACKEND_OUTPUT_DIR)/ slpp_all/
