# synthesis

SYNTH_SOURCES=DatapathSingleCycle.sv
TOP_SYNTH_MODULE=RiscvProcessor

ZIP_SOURCES=DatapathSingleCycle.sv ../hw2a/divider_unsigned.sv ../hw2b/cla.sv \
	vivado_output/singlecycle.bit vivado_output/post_route_power_report.txt \
	vivado_output/post_route_timing_summary_report.txt vivado_output/post_route_utilization_report.txt
ZIP_FILE=single.zip

# testbench

#TESTBENCH=dummy.v
#TOP_TESTBENCH_MODULE=dummy

# implementation

IMPL_SOURCES=$(SYNTH_SOURCES) system/mmcm.v system/RiscvSystem.sv
TOP_IMPL_MODULE=RiscvSystem
CONSTRAINTS=system/hw3-singlecycle.xdc
BITSTREAM_FILENAME=singlecycle.bit

include ../common/make/vivado.mk
