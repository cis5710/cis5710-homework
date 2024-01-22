#!/bin/bash

# iterate over a directory full of bitstreams, programming them each onto an attached ZedBoard 

if [ -z "$1" ]; then
    echo "usage: $0 directory-containing-bitstreams/"
fi

ls -1 $1/*.bit > bitstreams.txt
export BITSTREAM_FILE=bitstreams.txt
vivado -mode batch -notrace -source /home/devietti/cis501labs/cis501/common/tcl/program-multiple.tcl
