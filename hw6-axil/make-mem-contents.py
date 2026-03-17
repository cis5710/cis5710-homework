import sys
from pathlib import Path

p = Path.cwd() / '..' / 'common' / 'python'
sys.path.append(str(p))
import riscv_binary_utils

riscv_binary_utils.loadBinaryIntoHexFile(
    'atarvi-native/target/riscv32im-unknown-none-elf/release/candycrvsh',
    'mem_initial_contents.hex',
    maxAddress=8192*4
)
