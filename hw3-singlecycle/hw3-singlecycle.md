# Homework 3: Single-cycle Datapath

`DatapathSingleCycle.sv` has your starter code, including the memory, the program counter, and signals useful for decoding rv32im instructions. This homework builds upon previous assignments, and you will need to **copy your divider and CLA .sv files** into this directory so that they can be used in your processor.

> We have recently updated the `riscv-tests` submodule with the binaries needed for testing your processor. Be sure you get those changes by running (from the root directory of your git repo) the command: `git submodule update --recursive riscv-tests/`

This homework has two milestones, described next.

## HW3A: ALU & Branch Instructions

You should start by completing your register file in the `RegFile` module. We have provided a set of register file tests that you can run via `pytest-3 -s testbench_regfile.py`.

Once your register file is working, you can start implementing your processor. 

> **The instance of the RegFile module inside your processor must be named `rf` for the tests to work**.

For this milestone, your processor must support ALU instructions (`lui` through `and` (but not `auipc`) on our [ISA sheet](../riscv%20isa%20reference%20sheet.pdf)), branches (`beq` through `bgeu`) and the `ecall` instruction.

> For our purposes, `ecall` just needs to set the `halt` output of the processor to 1

You should start with `lui`, which loads an immediate into the upper bits of a register. The first step is to fetch the `lui` instruction from memory. The memory unit lives outside your datapath, as you can see in the `RiscvProcessor` module. The memory supports simultaneous access via a read-only port for fetching instructions, and a read-write port for loads and stores. Your datapath sends an address (on the `pc` outut) to the memory, and the memory responds with the value at the requested addresses (on the `insn` input). The documentation of the `MemorySingleCycle` module has more details. You can ignore the other memory inputs/outputs until the next milestone when you'll implement loads and stores.

We recommend that you move through the tests in `testbench.py` in order, from `testLui` to `testEcall`. Once those pass, you are ready to start running assembly tests from the [official RISC-V test suite](https://github.com/riscv-software-src/riscv-tests). The tests are listed at the bottom of `testbench.py`. You should start with `rv32ui-p-simple` and work your way down. The autograder will run the tests up through `rv32ui-p-bne`. To run the same tests that the autograder will, use the command:

```
RVTEST_ALUBR=1 pytest-3 -s testbench.py
```

> If you're curious about these test names, `rv32` means these are tests for the 32-bit RV ISA. `u` means they are for userspace instructions, as opposed to the *privileged* instructions an OS would use. `i` is the base integer instruction set. `-p-` indicates that the system supports only physical (not virtual) memory, and the suffix is the primary opcode being tested (e.g., `lui`), though other instructions are also used as part of the test as well.

You will need to use your CLA adder from HW2B to implement the `addi`, `add` and `sub` instructions. In other situations in which you need to add things (e.g., incrementing the PC or computing branch targets), you can use the SystemVerilog `+` operator.

The assembly code for each RV test is available to help you understand what each test is doing. For example, the assembly for the `rv32ui-p-lui` test is in the file [`../riscv-tests/isa/rv32ui-p-lui.dump`](../riscv-tests/isa/rv32ui-p-lui.dump), which you can view with a text editor. While these RV tests contain a relatively small number of instructions, you may find it helpful to also create your own test cases that produce shorter waveforms and allow for quicker debugging. You can follow the template of the existing tests in `testbench.py` to write your own tests in RV assembly, which will get assembled into machine code and loaded into the processor's memory for execution.


## HW3B: Remaining Instructions

In this second milestone, you will need to support the remaining rv32im instructions. The memory instructions, with multi-byte loads and stores, will likely be where you spend the most time. Note that your processor does not need to support misaligned memory accesses, and we don't run the `rv32ui-p-ma_data` test that would exercise these cases.

You should instantiate your divider from HW2A and use it to implement the divide and remainder instructions. You can use the `*` operator for multiply. For this milestone, the autograder will run `pytest-3 -s testbench.py` to run all of the RV tests against your processor. This will also run the larger [Dhrystone benchmark](https://en.wikipedia.org/wiki/Dhrystone) ([source code here](https://github.com/cis5710/riscv-tests/tree/master/benchmarks/dhrystone)) which runs about 190k instructions through your processor, and will allow us to make performance comparisons across the processors we build.

All told, your implementation should need around 300-400 lines of code.

## Disallowed Verilog Operators

You cannot use the `-`, `/` or `%` operators in your code.

## Testing and Debugging Tips

You can edit the `testOneRiscvTest` test in `testbench.py` to run any single RV test. You can then run just this test via `pytest-3 -s testbench.py --tests testOneRiscvTest`. This should result in simpler waveforms. You can also specify a comma-separated list of tests to the `--tests` flag.

In GtkWave, use the `disasm_wire` signal (be sure to change the Data Format to `ASCII`) to view the assembly code for the current instruction. This, along with the PC and `cycles_current` value, can help you track what your processor is doing. This disassembler has not been extensively tested, however, so it may contain bugs. PRs welcome!

The tests in `testbench.py` are arranged in the order in which we recommend you work on implementing instructions, as sometimes a test depends on instructions from earlier tests, e.g., the store tests use load instructions to verify that the stores updated memory properly. Always re-run old tests to make sure that your changes have not broken anything.


## Check timing closure

For this homework, in addition to the usual testing in simulation, you will also run the Vivado toolchain on your code to translate it into an FPGA bitstream. You don't need to actually load your bitstream onto an FPGA, but you should see if your design has reached *timing closure*, which means that the logic you've designed can be run safely at the clock speed you specify. The clock speed for HW3 is currently set at 5MHz, which is sufficient for our solution but YMMV.

To verify timing closure, run `make impl`.

> This command will only work on biglab.seas.upenn.edu, which is where Vivado is installed. Run the command `source /home1/c/cis5710/tools/cis5710-update-path.sh` to add Vivado to your path. See the [HW1 demo instructions](../hw1/hw1.md#optional-zedboard-demo) for more details.

After `make impl` completes (which will take 5-10 minutes), examine the `vivado_output/post_route_timing_summary_report.txt` file that is generated as part of the implementation process. Look for the *Design Timing Summary* section of the report that looks like this:
```
------------------------------------------------------------------------------------------------
| Design Timing Summary
| ---------------------
------------------------------------------------------------------------------------------------

    WNS(ns)      TNS(ns)  TNS Failing Endpoints  TNS Total Endpoints
    -------      -------  ---------------------  -------------------
     87.841        0.000                      0                  569


All user specified timing constraints are met.
```

The WNS (Worst case Negative Slack) is the key metric, which describes how long before the clock edge the signal(s) on the critical path were stable. If WNS is a positive value, then timing closure has been achieved. If it is negative then **timing closure has not been achieved**, and you ideally would run with a slower clock. Unfortunately, our 5 MHz clock is already very close to the minimum frequency that the ZedBoard can generate. If your design does not meet timing, go ahead and **submit it anyway**. Your score is based solely on the functional tests, not on timing.

We next discuss how to adjust the clock frequency, which will be useful in future homework assignments.

### Buying yourself some time

To change the clock frequency, edit the file `hw3-singlecycle/system/mmcm.v` following the instructions at line 129. You can use the slack reported by Vivado to guide your decision about a new frequency to choose. E.g., if your design has a slack of -2ns, then your clock period needs to be at least 2ns longer. [This online calculator](https://www.sensorsone.com/period-to-frequency-calculator/) is handy for translating a clock period into a frequency.

Re-run `make impl` and see if you achieve timing closure with the slower clock. Overall, it pays to go with a slower clock than absolutely necessary. There are many ways to ask Vivado to try harder to achieve timing closure, though this will lengthen compilation times, so we won't cover them here.

### Reporting timing results

Your timing results (and metrics for area and power) are automatically included in the .zip file you submit via Canvas. We'll use this to look at resource consumption across all the designs in the class.


## Optional ZedBoard Demo

TBD

## Submitting

For both HW3A and HW3B, run `make impl` and `make zip` (both on biglab.seas, not inside the docker container) and submit the `single.zip` file on Gradescope.
