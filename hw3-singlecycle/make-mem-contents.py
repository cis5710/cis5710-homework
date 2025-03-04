import sys
from pathlib import Path

p = Path.cwd() / '..' / 'common' / 'python'
sys.path.append(str(p))
import riscv_binary_utils

riscv_binary_utils.loadBinaryIntoHexFile(
    #'ledrop-rust/target/riscv32im-unknown-none-elf/release/ledrop', # Rust version
    'ledrop-c/ledrop.bin', # C version
    'mem_initial_contents.hex',
    maxWords=1024
)
