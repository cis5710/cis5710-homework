import sys
from pathlib import Path

p = Path.cwd() / '..' / 'common' / 'python'
sys.path.append(str(p))
import riscv_binary_utils

riscv_binary_utils.loadBinaryIntoHexFile(
    'mystery-signal/mystery.bin', # C version
    'mem_initial_contents.hex',
    maxAddress=4096
)
