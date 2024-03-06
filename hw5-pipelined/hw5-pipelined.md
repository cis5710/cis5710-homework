# Homework 5: Fully Pipelined Datapath

In this homework you will build on your design from HW4 and pipeline the entire datapath into 5 stages. There are two milestones for this assignment.

## Milestone 1: RV32I ALU Instructions and Branches

For this first milestone, you will need to handle the RV32I ALU instructions (except `auipc`) and also branch instructions. You can run this subset of the tests via the command:

```
RVTEST_ALUBR=1 pytest-3 -s testbench.py
```

You will need to implement MX and WX bypasses, and also a **WD bypass** so that if an instruction $i_d$ in Decode reads a register $x$ and another instruction $i_w$ in Writeback writes to $x$ in that same cycle, $i_d$ will receive its value of $x$ from $i_w$. You can implement this WD bypass inside your register file, or outside it in the Decode stage of the datapath, either is fine.

For this milestone, your datapath should always, by default, fetch the next sequential PC. Branch directions should be determined in Execute. On a taken branch, your datapath will flush the instructions in Fetch and Decode (replacing them with NOPs/bubbles) and then fetch the correct-path instruction in the following cycle (when the branch moves to the Memory stage). The pipelining lecture slides discuss the cycle timing in detail.

We recommend you work through the test cases in the order listed in `testbench.py`. The riscv-tests (except for `simple`) all exercise a variety of bypasses so you'll need all of that working before you can run them.

### Datapath trace outputs

To validate your pipelined design more fully, we have also introduced cycle-level test traces in this homework. Your datapath will need to set the `trace_*` output signals to identify, in each cycle, what is happening in the Writeback stage. See the documentation in `DatapathPipelined.sv` on these ports for details. We have provided cycle-by-cycle traces of the expected behavior of your processor in the `trace-*.json` files. The testbench will compare your processor's output against these traces for the LUI and BEQ riscv-tests (see `testTraceRvLui` and `testTraceRvBeq` in `testbench.py`). For the other riscv-tests we check only functional correctness, not cycle-level timing.


## Milestone 2: All RV32IM Instructions

For the second milestone, you will need to handle the rest of the RV32IM instructions. You can run this full set of tests via the command:

```
pytest-3 -s testbench.py
```

With the presence of load instructions comes the possibility of load-use dependencies, which must be handled via stalling. You should implement stalling in the Decode stage, i.e., if there is a load in Execute and a dependent instruction in Decode, in the next cycle the load should advance to Memory, the dependent instruction should remain in Decode, and Execute should be filled with a NOP.

You will also need to add WM bypassing to your pipeline.

You will need to support divide and remainder operations - for simplicity we'll discuss only divide as remainder is handled identically. Your divide operations should use the 2-stage pipelined divider from HW4. Since a divide takes 2 cycles, its quotient will not be available until the beginning of the Writeback stage, similar to loads. You will need to add a "divide-to-use" stall if there is a dependent instruction immediately following the divide.

One final case to handle is the `fence` instruction to support self-modifying code. Due to parallel execution within the pipeline, `fence` can no longer be a simple NOP: consider a store that writes to instruction memory in the Memory stage but the instructions at the written location have already been fetched. This behavior is a departure from the single-cycle design, where all instruction fetches "see the values" of all prior stores automatically. See `testFence` for an example. To preserve single-cycle behavior for your pipeline, if a `fence` instruction precedes a store in the pipeline, the `fence` should stall until the store reaches Writeback. If there are no stores preceding the `fence` instruction in the pipeline, or there is only one such store and it is in the Writeback stage, then no stalling is necessary.

> Note: this is a departure from official RV semantics, which would require this behavior only on the specific `fence.i` instruction instead. We'll discuss this later in class but for simplicity you can treat all fences the same in your design.

Cycle-level tracing is also enabled for this milestone, this time for the LW and dhrystone tests.

## Memory

Due to pipelining, our memory now works slightly differently than it did in HW3/HW4. The HW5 memory uses the same clock as the datapath, and all memory reads/writes occur on the negative edge (half-way through the cycle).

## Disallowed SystemVerilog Operators

You cannot use the `/` or `%` operators in your code (except as part of compile-time code like `for` loops). Run `make codecheck` to see if any illegal operators are present; the autograder performs this same check.

## Implementation Tips

The pipelined design is substantially more complex than our previous designs. Our reference implementation is over 50% larger than the multi-cycle design. As signals multiply across the pipeline stages (e.g., you'll want to track the PC for each insn in each stage now), we recommend a strict naming convention (e.g., `f_` for all Fetch signals, `d_` for all Decode signals, etc.) to make it easy to identify which signal corresponds to which stage.

SystemVerilog's `struct packed` are a great way to bundle your signals together and easily pass information from one stage to the next. Be sure to always assign these inside `always_ff` or `always_comb` blocks, however, to avoid combinational loops.

We have packaged up the RV disassembler into the `Disasm` module which is easier to work with. We recommend you instantiate one for each stage. The 32'd0 insn is also rendered as the string "bubble" now.

Instead of copying over all of your HW4 code at once and adding pipeline stages to it, we recommend you pull in just the parts needed to get each test case working. This will keep your design as small as possible as long as possible, making it easier to understand and debug.

The testcases we have provided are relatively limited. Adding your own tests will help you uncover bugs before they crop up in a larger riscv-test or dhrystone which are harder to understand.

## Check timing closure

For this homework, you will again run the Vivado toolchain to see how much your improved divider design affects overall frequency. To verify timing closure, run `make impl` (this only works on biglab, see [our previous instructions](../hw3-singlecycle/hw3-singlecycle.md#check-timing-closure)).

To change the clock frequency, edit the file `hw5-pipelined/system/mmcm.v` following the instructions at line 60. There is no target frequency you have to hit, but we are collecting this data to get a general sense of the trends across the designs.

## Submitting

Run `make impl` and `make zip` (both on biglab.seas) and submit the `pipelined.zip` file on Gradescope.
