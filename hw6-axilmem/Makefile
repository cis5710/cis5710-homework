# synthesis

SYNTH_SOURCES=DatapathAxilMemory.sv
TOP_SYNTH_MODULE=RiscvProcessor

ZIP_SOURCES=DatapathAxilMemory.sv ../hw2b/cla.sv ../hw4-multicycle/divider_unsigned_pipelined.sv
ZIP_FILE=axilmem.zip

# implementation

#IMPL_SOURCES=$(SYNTH_SOURCES) system/OledDevice.sv system/mmcm.v system/debouncer.v system/delay_ms.v system/OLEDCtrl.v system/SpiCtrl.v system/RiscvSystem.sv 
#IP_BLOCKS=system/ip/charLib/charLib.xci system/ip/init_sequence_rom/init_sequence_rom.xci system/ip/pixel_buffer/pixel_buffer.xci
#TOP_IMPL_MODULE=RiscvSystem
# same constraints as HW3
#CONSTRAINTS=system/hw3-singlecycle.xdc
#BITSTREAM_FILENAME=axilmem.bit

include ../common/make/vivado.mk
