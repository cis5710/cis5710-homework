# Homework 3: Single-cycle Datapath

`DatapathSingleCycle.sv` has your starter code, including the memory, the program counter, and signals useful for decoding rv32im instructions. This homework builds upon previous assignments, and will automatically include your HW2 divider and CLA so that they can be used as part of your processor.

This homework has two milestones, described next.

## HW3A: ALU & Branch Instructions

You should start by completing your register file in the `RegFile` module. We have provided a set of register file tests that you can run via `pytest --exitfirst --capture=no -k runCocotbTestsRegisterFile testbench.py`.

Once your register file is working, you can start implementing your processor. 

> **The instance of the RegFile module inside your processor must be named `rf` for the tests to work**.

For this milestone, your processor must support ALU instructions (`lui` through `and` (but not `auipc`) on our [ISA sheet](../riscv%20isa%20reference%20sheet.pdf)), branches (`beq` through `bgeu`) and the `ecall` instruction.

> For our purposes, `ecall` just needs to set the `halt` output of the processor to 1

You should start with `lui`, which loads an immediate into the upper bits of a register. The first step is to fetch the `lui` instruction from memory. The memory unit lives outside your datapath, as you can see in the `Processor` module. The memory supports simultaneous access via a read-only port for fetching instructions, and a read-write port for loads and stores. Your datapath sends an address (on the `pc_to_imem` output) to the memory, and the memory responds with the value at the requested addresses (on the `insn_from_imem` input). The documentation of the `MemorySingleCycle` module has more details. You can ignore the other memory inputs/outputs until the next milestone when you'll implement loads and stores.

We recommend that you move through the tests in `testbench.py` in order, from `testLui` to `testEcall`. Once those pass, you are ready to start running assembly tests from the [official RISC-V test suite](https://github.com/riscv-software-src/riscv-tests). The tests are listed at the bottom of `testbench.py`. You should start with `rv32ui-p-simple` and work your way down. The autograder will run the tests up through `rv32ui-p-bne`. To run the same tests that the autograder will, use the command:

```
RVTEST_ALUBR=1 pytest --exitfirst --capture=no testbench.py
```

> If you're curious about these test names, `rv32` means these are tests for the 32-bit RV ISA. `u` means they are for userspace instructions, as opposed to the *privileged* instructions an OS would use. `i` is the base integer instruction set. `-p-` indicates that the system supports only physical (not virtual) memory, and the suffix is the primary opcode being tested (e.g., `lui`), though other instructions are also used as part of the test as well.

You will need to use your CLA adder from HW2B to implement the `addi`, `add` and `sub` instructions. In other situations in which you need to add things (e.g., incrementing the PC or computing branch targets), you can use the SystemVerilog `+` operator.

The assembly code for each RV test is available to help you understand what each test is doing. For example, the assembly for the `rv32ui-p-lui` test is in the file [`../riscv-tests/isa/rv32ui-p-lui.dump`](../riscv-tests/isa/rv32ui-p-lui.dump), which you can view with a text editor. While these RV tests contain a relatively small number of instructions, you may find it helpful to also create your own test cases that produce shorter waveforms and allow for quicker debugging. You can follow the template of the existing tests in `testbench.py` to write your own tests in RV assembly, which will get assembled into machine code and loaded into the processor's memory for execution.


## HW3B: Remaining Instructions

In this second milestone, you will need to support the remaining rv32im instructions. The memory instructions, with multi-byte loads and stores, will likely be where you spend the most time. Note that your processor does not need to support misaligned memory accesses, and we don't run the `rv32ui-p-ma_data` test that would exercise these cases.

You should instantiate your divider from HW2A and use it to implement the divide and remainder instructions. You can use the `*` operator for multiply. For this milestone, the autograder will run `pytest --exitfirst --capture=no testbench.py` to run all of the RV tests against your processor. This will also run the larger [Dhrystone benchmark](https://en.wikipedia.org/wiki/Dhrystone) ([source code here](https://github.com/cis5710/riscv-tests/tree/master/benchmarks/dhrystone)) which runs about 190k instructions through your processor, and will allow us to make performance comparisons across the processors we build.

All told, your implementation should need around 300-400 lines of code.

## Disallowed Verilog Operators

You cannot use the `-`, `/` or `%` operators in your code.

## Testing and Debugging Tips

You can run just a single RV test via a command like `pytest --exitfirst --capture=no -k runCocotbTestsProcessor testbench.py --tests riscvTest_001`. This will result in much simpler waveforms than when running all tests together (as they all appear consecutively in a single waveform file). You can also specify a comma-separated list of tests to the `--tests` flag to run multiple tests, e.g., `pytest --exitfirst --capture=no -k runCocotbTestsProcessor testbench.py --tests testLui,riscvTest_001`.

In the waveforms, use the `disasm_wire` signal inside the `DatapathSingleCycle` module (be sure to change the Data Format to `ASCII`) to view the assembly code for the current instruction. This, along with the PC and `cycles_current` value, can help you track what your processor is doing. You can also see the name of the currently-running test using the `test_case` wire (again, use the ASCII data format) inside the `Processor` module.

The tests in `testbench.py` are arranged in the order in which we recommend you work on implementing instructions, as sometimes a test depends on instructions from earlier tests, e.g., the store tests use load instructions to verify that the stores updated memory properly. Always re-run old tests to make sure that your changes have not broken anything.


## Check timing closure

For this homework, in addition to the usual testing in simulation, you will also run the FPGA tools to generate a bitstream. Doing so allows you to check how fast your design runs (its clock frequency) and how many FPGA resources it consumes. We will not require you to reach a particular clock frequency or resource consumption level, though the clock is set at 4 MHz by default which was sufficient for our solution but YMMV.

To generate a bitstream, run `make resource-check`. This will take a few minutes, and when it completes you can examine the `fpga_build/resource-report.json` file to see information about critical paths, the frequency of your design, and the resource consumption. The frequency part of the report is especially important, and it will look something like this:

```
"fmax": {
    "$glbnet$clk_proc": {
        "achieved": 5.247085094451904,
        "constraint": 4.166666507720947
    },
    "clk_mem": {
        "achieved": 22.045854568481445,
        "constraint": 4.0100250244140625
    }
},
```

The key metric is whether you have achieved *timing closure*, i.e., whether the *achieved* clock frequency of your design meets its *constraint* (the frequency you requested). If the achieved value is >= the constraint, you have achieved timing closure. Otherwise, timing closure has failed and you need to run with a slower clock. If your design does not meet timing, go ahead and **submit it anyway**. Your score is based solely on the functional tests, not on timing. 

We next discuss how to adjust the clock frequency, which will be useful in future homework assignments.

### Buying yourself some time

To change the clock frequency, you can specify the `CLOCK_FREQUENCY` environment variable when you run the FPGA compiler, like this:

```
CLOCK_FREQUENCY=3.5 make resource-check
```

Clock frequency is specified in MHz, so the command above would request a 3.5 MHz clock. Note that the clock generation circuits cannot generate arbitrary frequencies, so your actual frequency may not be quite what you request. There will also be a warning if you request a clock below 10 MHz, but it is ok to ignore this warning.

### Reporting timing results

The autograder will run `make resource-check` on your code after it runs the tests. This will cause autograding to take several minutes. This is much longer than in prior labs, so plan accordingly with respect to the deadline.

Clock frequency results and LUT usage will be gathered in an anonymized leaderboard as well. Leaderboard results will not affect homework scores in this homework, though they may in a future one. Your resource report is automatically included in the .zip file you submit via Gradescope.

## Submitting

For both HW3A and HW3B, run `make resource-check` and `make zip` and then submit the `single.zip` file on Gradescope.

# FPGA Demo

The demo for this homework is a small reaction-time game, written [in Rust](ledrop/src/main.rs). In this game, a "ball" travels along the LEDs on the board and you have to "catch" it by pressing button B2 once LED D0 (red) is lit and holding it until the next LED would be lit. If you caught the ball, a blue "success" LED (D7) will briefly illuminate, and the ball will start moving faster. If you press B2 at any other time, however, you will lose and must reset the processor (via button B0/PWR).

The machine code for the demo is pre-compiled in `mem_initial_contents.hex`. You can build your bitstream via `make demo` (this will take a couple minutes). It is very important that your design meets timing closure, otherwise timing glitches will likely corrupt the gameplay. You are free to adjust `CLOCK_FREQUENCY` as necessary (see above).

> You can also edit the game code if you want, to adjust the gameplay or even create a new game. Recompile the game code via `make demo-code`. Be sure to also then regenerate your bitstream via `make demo` so that the board runs the latest version of your game.

## Programming the FPGA

TODO: board programming instructions...

## TA Sign-off

You should demonstrate the demo running on a board to a TA during their Office Hours. They will give your team credit for the demo. Editing the game is not required, though we will be excited if you decide to do so!