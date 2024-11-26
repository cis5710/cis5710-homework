# source verilog files
SYNTH_SOURCES=rca.sv
TOP_SYNTH_MODULE=rca4

# testbench files
TESTBENCH=dummy.sv
TOP_TESTBENCH_MODULE=dummy

# zip file that gets uploaded
ZIP_SOURCES=rca.sv output/rca4.bit
ZIP_FILE=rca.zip

# implementation files
IMPL_SOURCES=$(SYNTH_SOURCES)
TOP_IMPL_MODULE=rca4
CONSTRAINTS=hw1.xdc 
BITSTREAM_FILENAME=rca4.bit

include ../common/make/vivado.mk
