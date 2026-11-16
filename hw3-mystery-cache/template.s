# template.s -- starting point for probing the mystery cache.
#
# Build (any RISC-V Linux cross toolchain), e.g.:
#   riscv64-linux-gnu-gcc -nostdlib -static -o probe template.s
# Run:
#   gem5 probe
#
# Only the loads/stores between M5_RESET_STATS and M5_DUMP_STATS are counted
# in "L1D stats dump #1". Instruction fetches are never counted.

    .include "m5ops.inc"

    .bss
    .balign 4096
array:
    .space  1 << 20         # 1 MiB of zeroed memory to play with

    .text
    .globl _start
_start:
    la      t0, array        # t0 = &array[0]

    M5_RESET_STATS

    # your code goes here
    lb t1, 0(t0)

    M5_DUMP_STATS

    EXIT 0
