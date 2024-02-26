# synthesis

SYNTH_SOURCES=DatapathMultiCycle.sv
TOP_SYNTH_MODULE=RiscvProcessor

ZIP_SOURCES=DatapathMultiCycle.sv divider_unsigned_pipelined.sv ../hw2b/cla.sv \
	vivado_output/multicycle.bit vivado_output/post_route_power_report.txt \
	vivado_output/post_route_timing_summary_report.txt vivado_output/post_route_utilization_report.txt
ZIP_FILE=multi.zip

# implementation

IMPL_SOURCES=$(SYNTH_SOURCES) system/OledDevice.sv system/mmcm.v system/debouncer.v system/delay_ms.v system/OLEDCtrl.v system/SpiCtrl.v system/RiscvSystem.sv 
IP_BLOCKS=system/ip/charLib/charLib.xci system/ip/init_sequence_rom/init_sequence_rom.xci system/ip/pixel_buffer/pixel_buffer.xci
TOP_IMPL_MODULE=RiscvSystem
# same constraints as HW3
CONSTRAINTS=system/hw3-singlecycle.xdc
BITSTREAM_FILENAME=multicycle.bit

include ../common/make/vivado.mk
