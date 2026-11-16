# m5ops.inc -- gem5 "magic" instructions for the mystery-cache homework.
# Use with:   .include "m5ops.inc"
#
#   M5_RESET_STATS   zero all cache counters (start of measured region)
#   M5_DUMP_STATS    print the counters accumulated since the last reset
#   EXIT code        exit the program with the given status
#
# The M5 macros clobber a0 and a1. They do not touch memory, so they add no
# cache accesses of their own.

.macro M5_RESET_STATS
    li   a0, 0              # delay  = 0 ticks
    li   a1, 0              # period = 0 (one-shot)
    .word 0x8000007b        # m5_reset_stats
.endm

.macro M5_DUMP_STATS
    li   a0, 0
    li   a1, 0
    .word 0x8200007b        # m5_dump_stats
.endm

.macro EXIT code
    li   a0, \code
    li   a7, 93             # Linux exit syscall
    ecall
.endm
