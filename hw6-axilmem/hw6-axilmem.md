# Homework 6: Pipelined Datapath with AXI-Lite Memory

In this homework you will build a more realistic memory that communicates via the AXI4-Lite interface, and then integrate that memory with your pipelined datapath from HW5. There is only a single submission for this homework, though we decompose the assignment into 3 key steps below.

## Step 1: AXI-Lite Memory

First, you will need to build your AXI4-Lite memory module, completing the starter code given in the `MemoryAxiLite` module. The [official AXI4-Lite specification from ARM](https://www.arm.com/architecture/system-architectures/amba/amba-4) is a valuable and accessible resource. There are both simplifications and complications with respect to the official AXI4-Lite (hereafter AXIL for simplicity) specification that you can/should make in your design.

### Simplifications

Your AXIL memory can assume that `AWADDR` and `WDATA`/`WSTRB` will appear together in the same cycle. In the official AXIL spec, they can appear independently and must be buffered internally until both are received.

You can also assume that the manager (the datapath) will always be ready to receive outputs from the subordinate (via `RREADY` and `BREADY`). This also helps simplify processing inside the memory.

Your memory will have a fixed 1-cycle latency for both reads and writes.

### Complications

To keep up with the datapath, the memory needs to be able to handle consecutive memory reads as a new instruction needs to be fetched each cycle, and the processor may run a series of consecutive load instructions. Similarly, the memory needs to be able to handle consecutive memory writes due to consecutive store instructions. The general AXIL interface allows the subordinate to determine the timing of responses to the manager (e.g., the manager must wait until `RVALID`/`BVALID` is set by the subordinate). However, in our datapath we want to avoid both stalls and the additional complexity of handling variable latency in the Fetch/Memory stages. It is both easier and higher performance to make the memory capable of handling consecutive requests than to have the pipeline support a truly latency-insensitive memory.

### Testing

We have also provided a set of tests for your `MemoryAxiLite` module, which you can run via:
```
pytest-3 -s testbench_mem.py
```
Note that the [cocotb-bus library](https://github.com/cocotb/cocotb-bus) (pre-installed in your Docker container) has nice support for generating AXIL read/write requests and checking the responses, making it easy to interact with your memory with a few lines of Python.

### Tips

We have created parameters for `ADDR_WIDTH` and `DATA_WIDTH` to allow flexibility for future versions of this assignment. However, both parameters will always be 32 for this assignment, so your `MemoryAxiLite` should manage an array of 4B words and reads and writes will request 32-bit addresses. The `NUM_WORDS` parameter can change, however, to be other powers-of-two and your code should be able to handle that. When testing `MemoryAxiLite` in isolation we scale it down to make debugging easier, but riscv-tests and dhrystone require a larger memory.

The memory supports two full AXIL interfaces, for both instruction and data memory. Writes via the instruction interface (the `I_`-prefixed signals) can be ignored. However, the machinery for reads is identical between instruction and data memory. We recommend creating a SystemVerilog sub-module to handle AXIL reading, which you can then duplicate for both imem and dmem. This will keep your code cleaner, and if you fix a bug it will be automatically fixed for both imem and dmem. Note that you should not replicate the memory contents (`mem_array`) -- that lives only in `MemoryAxiLite`. However, the control logic to handle the AXIL signaling can be delegated to a sub-module. SV interfaces can also help simplify wiring between `MemoryAxiLite` and its sub-modules if you decide to go this route.

Building `MemoryAxiLite` is the most complex part of this assignment. Our implementation is about 250 lines of code (with a sub-module for reads).


## Step 2: fetch from MemoryAxiLite

Once your `MemoryAxiLite` is working, we recommend copying over all of your HW5 pipeline code (including `RegFile`, structs used for pipeline registers, etc.) and starting on the pipeline integration. You should begin by changing instruction fetch to interact with your `MemoryAxiLite` module instead of the old `MemorySingleCycle`, but continuing to use `MemorySingleCycle` for the data memory, as shown in our template code for `DatapathAxilMemory`. Note that you will also need to update `RiscvProcessor` accordingly to reflect your current `DatapathAxilMemory` interface.

It's also reasonable to update both Fetch and Memory together (Steps 2 & 3), since the changes are relatively small. Step 3 doesn't need to be fully working for you to test/debug your Step 2 changes; it will only need to be sufficiently wired together to get your code to compile.

Once your Fetch/Decode stages are updated properly, you can start running tests that use only non-memory instructions via:
```
RVTEST_ALUBR=1 pytest-3 -s testbench.py
```

The most significant change with `MemoryAxiLite` over `MemorySingleCycle` is that `MemoryAxiLite` runs on the positive edge, instead of running in the middle of each cycle. The ramification is that the Fetch stage is now responsible for calculating a PC and sending it to the imem (via `ARADDR` and such), but the fetched instruction bits won't come back until the *next* positive edge and thus they are only accessible in the Decode stage (via `RDATA`). So, you can't disassemble the Fetch instruction anymore, because there are no instruction bits in Fetch to disassemble - we only have a PC. This is now (finally!) just like the pipeline design discussed in class.

You may need to update your branch misprediction squash logic as well, to account for the fact that the mis-predicted Fetch instruction similarly arrives later, too. With HW5, that mispredicted Fetch instruction was already in the Fetch stage and so could be squashed when going into the registers at the start of the Decode stage. Now with `MemoryAxiLite`, the mispredicted Fetch instruction arrives "directly" in the Decode stage (so it does not go into those Decode registers) and needs to be ignored accordingly.

The pipeline integration is mainly a conceptual challenge of dealing with the "later" arrival of instructions from memory. The required code changes are only about 10 lines.

## Step 3: load/store to MemoryAxiLite

Once you have fetch updated, you are ready to sever all ties with `MemorySingleCycle` and use `MemoryAxiLite` for data memory as well. Again, the main change is that the result of load instructions is not available in the Memory stage anymore, but is available only in Writeback.

As you work through data memory integration, you will want to run tests with load and store instructions, via:
```
pytest-3 -s testbench.py
```

Integrating load/store support will likely require moving a fair bit of logic (dozens of lines of code) from Memory to Writeback to handle the arrival of load results there, however the changes are not very deep.


## Datapath trace outputs

This homework has the same cycle-level tracing tests as in HW5, and the reference traces are identical since using `MemoryAxiLite` does not introduce any additional stall conditions (nor remove any).


## Disallowed SystemVerilog Operators

You cannot use the `/` or `%` operators in your code (except as part of compile-time code like `for` loops). Run `make codecheck` to see if any illegal operators are present; the autograder performs this same check.


## Check timing closure

For this homework, you will again run the Vivado toolchain to see how much your improved divider design affects overall frequency. To verify timing closure, run `make impl` (this only works on biglab, see [our previous instructions](../hw3-singlecycle/hw3-singlecycle.md#check-timing-closure)).

To change the clock frequency, edit the file `hw6-axilmem/system/mmcm.v` following the instructions at line 60. There is no target frequency you have to hit, but we are collecting this data to get a general sense of the trends across the designs.

## Submitting

Run `make impl` and `make zip` (both on biglab.seas) and submit the `axilmem.zip` file on Gradescope. The autograder runs all tests from both `testbench_mem.py` and `testbench.py`.
