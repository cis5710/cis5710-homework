"""
gem5 launcher: RISC-V out-of-order (O3) CPU + LocalBP (2bit_local) branch
predictor, running a fixed gem5-resources workload in SE mode.

Edit the settings below, then run:
    build/RISCV/gem5.opt run_localbp.py          (add -d <dir> to pick the output dir)
Branch predictor stats are in stats.txt under ...core.branchPred.*
"""

import m5, re, sys
from m5.objects import BranchPredictor, LocalBP

from gem5.components.boards.simple_board import SimpleBoard
from gem5.components.cachehierarchies.classic.private_l1_private_l2_cache_hierarchy import (
    PrivateL1PrivateL2CacheHierarchy,
)
from gem5.components.memory import SingleChannelDDR3_1600
from gem5.components.processors.cpu_types import CPUTypes
from gem5.components.processors.simple_processor import SimpleProcessor
from gem5.isas import ISA
from gem5.resources.resource import BinaryResource, obtain_resource
from gem5.simulate.exit_event import ExitEvent
from gem5.simulate.simulator import Simulator
from m5.objects import RiscvISA

# ---------------------------------------------------------------------------
# Settings
# ---------------------------------------------------------------------------
MAX_INSTS = 0              # stop after this many instructions (0 = run to end)

# LocalBP
LOCAL_ENTRIES = 2048       # counters in the table (power of two)
CTR_BITS = 2               # bits per saturating counter
INST_SHIFT = 2             # low PC bits dropped before indexing: 2 for 4-byte
                           # instructions, 1 if the binary uses the C extension

# Memory system
CLK = "3GHz"
L1I_SIZE = "32KiB"
L1D_SIZE = "32KiB"
L2_SIZE = "1MiB"
MEM_SIZE = "2GiB"

# ---------------------------------------------------------------------------
# System
# ---------------------------------------------------------------------------
processor = SimpleProcessor(cpu_type=CPUTypes.O3, isa=ISA.RISCV, num_cores=1)

cpu = processor.get_cores()[0].get_simobject()
# cpu.isa = [RiscvISA(riscv_type="RV32")] # switch to 32-bit CPU

# LocalBP's localPredictorSize is measured in BITS of storage; the number of
# table entries is localPredictorSize / localCtrBits.
# BTB, return-address stack and indirect predictor keep gem5's defaults.
cpu.branchPred = BranchPredictor(
    conditionalBranchPred=LocalBP(
        localPredictorSize=LOCAL_ENTRIES * CTR_BITS,
        localCtrBits=CTR_BITS,
        
        # this line assumes you've added the tagMatching parameter. Comment it out if you haven't done so yet.
        tagMatching=True,
    ),
    instShiftAmt=INST_SHIFT,
)

if MAX_INSTS:
    cpu.max_insts_any_thread = MAX_INSTS

board = SimpleBoard(
    clk_freq=CLK,
    processor=processor,
    memory=SingleChannelDDR3_1600(size=MEM_SIZE),
    cache_hierarchy=PrivateL1PrivateL2CacheHierarchy(
        l1d_size=L1D_SIZE, l1i_size=L1I_SIZE, l2_size=L2_SIZE
    ),
)

if len(sys.argv) != 2:
    print(f'usage: {sys.argv[0]} <hello, qsort>')
    sys.exit(1)
    pass

workload = sys.argv[1]
if workload == 'hello':
    board.set_se_binary_workload(obtain_resource('riscv-hello'), arguments=[])
elif workload == 'qsort':
    board.set_se_binary_workload(BinaryResource(local_path="qsort.bin"), arguments=[])
else:
    print(f'invalid workload: {workload}')
    sys.exit(1)
    pass


# ---------------------------------------------------------------------------
# Run
# ---------------------------------------------------------------------------
simulator = Simulator(
    board=board,
    full_system=False,
    on_exit_event={ExitEvent.MAX_INSTS: (lambda: True)},  # end at MAX_INSTS
)
simulator.run()
print(f"Finished at tick {simulator.get_current_tick()}: "
      f"{simulator.get_last_exit_event_cause()}")
m5.stats.dump()

def stat(pattern, lines):
    """Sum every stats.txt line whose name matches the regex."""
    return sum(float(l.split()[1]) for l in lines
               if l.split() and re.search(pattern, l.split()[0]))

with open("m5out/stats.txt") as f:
    stat_lines = f.read().split("Begin Simulation Statistics")[-1].splitlines()
    insts = stat(r"^simInsts$", stat_lines)
    cycles = stat(r"\.core\.numCycles$", stat_lines)
    mispredicts = stat(r"branchPred\.mispredicted_\d+::(?!total)", stat_lines)

    print(f"IPC             = {insts / cycles:.3f}")
    print(f"MPKI            = {1000 * mispredicts / insts:.3f}")

    # sample code for reading your own counters
    #tagMatches = stat(r"BranchPred\.tagMatches", stat_lines)
    #tagMismatches = stat(r"BranchPred\.tagMismatches", stat_lines)
    #print(f"Tag Matches     = {int(tagMatches)}")
    #print(f"Tag Mismatches  = {int(tagMismatches)}")
    pass
