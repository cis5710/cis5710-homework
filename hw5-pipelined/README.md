# Homework 5: Fully Pipelined Datapath

In this homework you will build on your design from HW4 and pipeline the entire datapath into 5 stages. There are two milestones for this assignment.

## Milestone 1: RV32I ALU Instructions and Branches

For this first milestone, you will need to handle the RV32I ALU instructions (except `auipc`) and also branch instructions. You can run this subset of the tests via the command:

```
RVTEST_ALUBR=1 pytest --exitfirst --capture=no testbench.py
```

You will need to implement MX and WX bypasses, and also a **WD bypass** so that if an instruction $i_d$ in Decode reads a register $x$ and another instruction $i_w$ in Writeback writes to $x$ in that same cycle, $i_d$ will receive its value of $x$ from $i_w$. You can implement this WD bypass inside your register file, or outside it in the Decode stage of the datapath, either is fine.

For this milestone, your datapath should always, by default, fetch the next sequential PC. Branch directions should be determined in Execute. On a taken branch, your datapath will flush the instructions in Fetch and Decode (replacing them with NOPs/bubbles) and then fetch the correct-path instruction in the following cycle (when the branch moves to the Memory stage). The pipelining lecture slides discuss the cycle timing in detail.

We recommend you work through the test cases in the order listed in `testbench.py`. The riscv-tests (except for `simple`) all exercise a variety of bypasses so you'll need all of that working before you can run them.

### Datapath trace outputs

To validate your pipelined design more fully, we have also introduced cycle-level test traces in this homework. Your datapath will need to set the `trace_*` output signals to identify, in each cycle, what is happening in the Writeback stage. See the documentation in `DatapathPipelined.sv` on these ports for details. We have provided cycle-by-cycle traces of the expected behavior of your processor in the `trace-*.json` files. The testbench will compare your processor's output against these traces for the LUI and BEQ riscv-tests (see `testTraceRvLui` and `testTraceRvBeq` in `testbench.py`). For the other riscv-tests we check only functional correctness, not cycle-level timing.


## Milestone 2: All RV32IM Instructions

For the second milestone, you will need to handle the rest of the RV32IM instructions. You can run this full set of tests via the command:

```
pytest --exitfirst --capture=no testbench.py
```

With the presence of load instructions comes the possibility of load-use dependencies, which must be handled via stalling. You should implement stalling in the Decode stage, i.e., if there is a load in Execute and a dependent instruction in Decode, in the next cycle the load should advance to Memory, the dependent instruction should remain in Decode, and Execute should be filled with a NOP.

You will also need to add WM bypassing to your pipeline.

### Divide/remainder operations

You will need to support divide and remainder operations - for simplicity we'll discuss only divide as remainder is handled identically. Your divide operations should use the pipelined divider from HW4. Since a divide takes 8 cycles, its quotient will not be available until much later than other ALU operations.

Divide operations should proceed to the M stage after they complete the divider pipeline. This keeps divides similar to other insns and allows for regular MX bypassing in cases like the one below where a (non-divide) consumer insn immediately follows a divide insn:
```
div x1,x2,x3 F D X0 X1 X2 X3 X4 X5 X6 X7 M W
addi x4,x1,0   F D  *  *  *  *  *  *  *  X M W
```

When the M stage is waiting for a divide insn to complete, the resulting stalls should have `CYCLE_DIV` status.

Your divide pipeline should also permit back-to-back execution of consecutive *independent* divide insns. If the first `div` insn enters Fetch in cycle 0, the code below will execute as follows:
```
div x1,x2,x3 F D X0 X1 X2 X3 X4 X5 X6 X7 M  W
div x4,x5,x6   F D  X0 X1 X2 X3 X4 X5 X6 X7 M W
```

For *dependent* divide insns, the younger insn must stall until the older insn completes the entire divide pipeline. The resulting stalls should also use status `CYCLE_DIV`.
```
div x1,x2,x3 F D X0 X1 X2 X3 X4 X5 X6 X7 M  W
div x4,x5,x1   F D  *  *  *  *  *  *  *  X0 X1 X2 X3 X4 X5 X6 X7 M W
```

Cycle-level tracing is also enabled for this milestone, this time for the LW and dhrystone tests.

## Memory

Due to pipelining, our memory now works slightly differently than it did in HW3/HW4. The HW5 memory uses the same clock as the datapath, and all memory reads/writes occur on the negative edge (half-way through the cycle).

## Disallowed SystemVerilog Operators

You cannot use the `/` or `%` operators in your code (except as part of compile-time code like `for` loops). Run `make codecheck` to see if any illegal operators are present; the autograder performs this same check.

## Implementation Tips

The pipelined design is substantially more complex than our previous designs. Our reference implementation is over 50% larger than the multi-cycle design. As signals multiply across the pipeline stages (e.g., you'll want to track the PC for each insn in each stage now), we recommend a strict naming convention (e.g., use the `f_` prefix for all Fetch signals, `d_` for all Decode signals, etc.) to make it easy to identify which signal corresponds to which stage.

SystemVerilog's `struct packed` are a great way to bundle your signals together and easily pass information from one stage to the next. Be sure to always assign these inside `always_ff` or `always_comb` blocks, however, to avoid combinational loops.

We have packaged up the RV disassembler into the `Disasm` module which is easier to work with. We recommend you instantiate one for each stage. The 32'd0 insn is also rendered as the string "bubble" now.

Instead of copying over all of your HW4 code at once and adding pipeline stages to it, we recommend you pull in just the parts needed to get each test case working. This will keep your design as small as possible as long as possible, making it easier to understand and debug.

The testcases we have provided are relatively limited. Adding your own tests will help you uncover bugs before they crop up in a larger riscv-test or dhrystone which are harder to understand. Alternatively, if you do discover a bug via a larger test, consider trying to reproduce the bug via a smaller test. This can make it easier to check your fix and to ensure that it stays fixed as you work on other parts of the design.

## Check timing closure

For this homework, you will again run `make resource-check` to see how pipelining improves frequency.

## Submitting

Run `make resource-check` and then `make zip` and submit the `pipelined.zip` file on Gradescope. There is a resource leaderboard for this assignment, but it is strictly informational - no points are awarded based on the leaderboard results.

## HW5 Demo: Communication between PC and FPGA processor

After you have finished your 5-stage pipelined datapath, you can start working on HW5 demo. In this demo, we will establish communication between your laptop and the FPGA. You can send a string of characters using the keyboard to your processor on the FPGA and the processor will send a reversed string back to your laptop. The code running on the CPU is [this small C program](uart-c/uart.c).

Run `make demo-code` first to generate the assmebly code running on your processor. And then run `make demo` to generate the bitstream. 

### Windows

Refer to hw2b demo on how to program your FPGA after successfully generating your bitstream. 

After programming your FPGA, you can use any application that supports serial communication. In this homework we use **Mobaxterm** as an example.

Click `Session -> Serial` and choose the valid serial port and set the baud rate to be **115200**. Then click `OK`.

Type in 8 characters using your keyboard and you should see the reversed string being shown the serial terminal.


### Mac 

After programming your FPGA (run `make program` on your machine), open another local terminal and run `screen /dev/cu.usbserial-* 115200` to monitor the serial communication between your FPGA board and your Mac.

Once connected, type 8 characters using your keyboard. You should see the string displayed in reverse order on the serial terminal.

To exit the session, press: `Control + a + k`. Confirm the termination by selecting `y` when prompted.
