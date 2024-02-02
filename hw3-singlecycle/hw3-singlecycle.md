# Homework 3: Single-cycle Datapath

`DatapathSingleCycle.sv` has your starter code, including the memory, the program counter, and signals useful for decoding rv32im instructions. This homework has two milestones, described next.

We have recently updated the `riscv-tests` submodule with the binaries needed for testing your processor. Be sure you get those changes by running (from the root directory of your git repo) the command:
```
git submodule update --recursive riscv-tests/
```

## HW3A: ALU & Branch Instructions

You should start by completing your register file in the `RegFile` module. We have provided a set of register file tests that you can run via `pytest-3 testbench_regfile.py`.

Once your register file is working, you can start implementing your processor. For this milestone, your processor must support ALU instructions (`lui` through `and` on our [ISA sheet](../riscv isa reference sheet.pdf)), branches (`beq` through `bgeu`) and the `ecall` instruction.

> For our purposes, `ecall` just needs to set the `halt` output of the processor to 1

You should start with `lui`, which loads an immediate into the upper bits of a register. The first step is to fetch the `lui` instruction from memory. The memory unit lives outside your datapath, as you can see in the `RiscvProcessor` module. The memory supports simultaneous access via a read-only port for fetching instructions, and a read-write port for loads and stores. Your datapath sends an address (on the `pc` outut) to the memory, and the memory responds with the value at the requested addresses (on the `insn` input). The documentation of the `MemorySingleCycle` module has more details. You can ignore the other memory inputs/outputs until the next milestone when you'll implement loads and stores.

We recommend that you move through the tests in `testbench.py` in order, from `testLui` to `testEcall`. Once those pass, you are ready to start running assembly tests from the [official RISC-V test suite](https://github.com/riscv-software-src/riscv-tests). The tests are listed at the bottom of `testbench.py`. You should start with `rv32ui-p-simple` and work your way down. The autograder will run the tests up through `rv32ui-p-bne`. To run the same tests that the autograder will, use the command:

```
RVTEST_ALUBR=1 pytest-3 testbench.py
```

> If you're curious about these test names, `rv32` means these are tests for the 32-bit RV ISA. `u` means they are for userspace instructions, as opposed to the *privileged* instructions an OS would use. `i` is the base integer instruction set. `-p-` indicates that the system supports only physical (not virtual) memory, and the suffix is the opcode being tested (e.g., `lui`), though other instructions are also used as part of the test as well.

You will need to use your CLA adder from HW2B to implement the `addi`, `add` and `sub` instructions. In other situations in which you need to add things (e.g., incrementing the PC or computing branch targets), you can use the SystemVerilog `+` operator.

The assembly code for each RV test is available to help you understand what each test is doing. For example, the assembly for the `rv32ui-p-lui` test is in the file [`../riscv-tests/isa/rv32ui-p-lui.dump`](../riscv-tests/isa/rv32ui-p-lui.dump), which you can view with a text editor. While these RV tests contain a relatively small number of instructions, you may find it helpful to also create your own test cases that produce shorter waveforms and allow for quicker debugging. You can follow the template of the existing tests in `testbench.py` to write your own tests in RV assembly, which will get assembled into machine code and loaded into the processor's memory for execution.


## HW3B: Remaining Instructions

In this second milestone, you will need to support the remaining rv32im instructions. The memory instructions, with multi-byte loads and stores, will likely be where you spend the most time.

You should instantiate your divider from HW2A and use it to implement the divide and remainder instructions. You can use the `*` operator for multiply. For this milestone, the autograder will run `pytest-3 testbench.py` to run all of the RV tests against your processor.

All told, your implementation should need around 300-400 lines of code.

## Disallowed Verilog Operators

You cannot use the `-`, `/` or `%` operators in your code.

## Testing and Debugging Tips

You can edit the `testOneRiscvTest` test in `testbench.py` to run any single RV test, which will result in much simpler waveforms.

In GtkWave, use the `disasm_wire` signal (be sure to change the Data Format of `ASCII`) to view the assembly code for the current instruction. This, along with the PC and `cycles_current` value, can help you track what your processor is doing. This disassembler has not been extensively tested, however, so it may contain bugs.

The tests in `testbench.py` are arranged in the order in which we recommend you add instructions, as sometimes a test depends on instructions from earlier tests, e.g., the `fence_i` test has self-modifying code and requires working load and store instructions. Always re-run old tests to make sure that your additions have not broken anything.



## Submitting

TBD

