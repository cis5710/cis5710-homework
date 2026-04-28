import sys
from pathlib import Path

p = Path.cwd() / '..' / 'common' / 'python'
sys.path.append(str(p))
import riscv_binary_utils

riscv_binary_utils.loadBinaryIntoHexFile(
    sys.argv[1],    
    'mem_initial_contents.hex',
    maxAddress=8192*4
    #maxAddress=4096*4
    #maxAddress=512*4
)
