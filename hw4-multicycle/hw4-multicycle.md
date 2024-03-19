# Homework 4: Pipelined Divider and Multi-cycle Datapath

This homework has two main components. First, you will pipeline your divider from HW2A to improve its critical path. Then, you will integrate your faster divider with your processor from HW3.

## 2-stage Pipelined Divider

Your `divu_1iter` code can be recycled verbatim from HW2A. Then you should start from your `divider_unsigned` code and convert it to have 2 pipeline stages. Each stage should complete 16 "iterations" of the division algorithm, and your divider should support starting a new division operation on each cycle.

We have provided an initial set of divider tests for you in `pytest-3 -s testbench_divider_pipelined.py`. 

## Datapath Integration

After your divider is working, you will need to integrate it into your datapath. Your datapath is almost entirely unchanged from HW3, except that `div`, `divu`, `rem` and `remu` instructions will take 2 cycles instead of one. We'll refer to these 4 kinds of instructions as "divide operations" for simplicity.

Your divider module is pipelined and so, theoretically, you could start back-to-back divide operations on consecutive cycles for improved performance. However, your datapath will not (yet) take advantage of this and so consecutive divide operations will each take 2 cycles. Thus, *k* consecutive divide operations will take *2k* cycles.

You can run the datapath tests via `pytest-3 -s testbench.py`. These are a subset of the HW3 tests, but include all of the riscv-tests and dhrystone.

All told, the datapath changes amount to less than 10 lines of code.


## Disallowed SystemVerilog Operators

You cannot use the `/` or `%` operators in your divider code (except as part of compile-time code like `for` loops), or additionally the `-` operator in your datapath (`-` is ok in the divider, however). Run `make codecheck` to see if any illegal operators are present; the autograder performs this same check.

## Testing and Debugging Notes

The autograder runs both the divider and the datapath tests on your submission.

## Check timing closure

For this homework, you will again run the Vivado toolchain to see how much your improved divider design affects overall frequency. To verify timing closure, run `make impl` (this only works on biglab, see [HW3 instructions](../hw3-singlecycle/hw3-singlecycle.md#check-timing-closure)).

### Buying yourself some time

To change the clock frequency, edit the file `hw4-multicycle/system/mmcm.v` following the instructions at line 60.

## Submitting

Run `make impl` and `make zip` (both on biglab.seas) and submit the `multi.zip` file on Gradescope.
