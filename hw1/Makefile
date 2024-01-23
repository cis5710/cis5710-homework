# source verilog files
SYNTH_SOURCES=rca.v
TOP_SYNTH_MODULE=rca4

# testbench files
TESTBENCH=rca_testbench.v
TOP_TESTBENCH_MODULE=test_adders

# zip file that gets uploaded
ZIP_SOURCES=rca.v output/rca4.bit
ZIP_FILE=rca.zip

# implementation files
IMPL_SOURCES=$(SYNTH_SOURCES)
TOP_IMPL_MODULE=rca4
CONSTRAINTS=lab1.xdc 
BITSTREAM_FILENAME=rca4.bit

include ../common/make/vivado.mk
