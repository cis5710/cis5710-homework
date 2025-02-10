# Homework 4: Pipelined Divider and Multi-cycle Datapath

This homework has two main components. First, you will pipeline your divider from HW2A to improve its critical path. Then, you will integrate your faster divider with your processor from HW3.

## 8-stage Pipelined Divider

Your `divu_1iter` code can be recycled verbatim from HW2A. Then you should start from your `divider_unsigned` code and convert it to have 8 pipeline stages. Each stage should complete 4 "iterations" of the division algorithm, and your divider should support starting a new division operation on each cycle.

The `stall` input can be ignored for now. Later in HW6, you will need to utilize this input.

We have provided an initial set of divider tests for you in `pytest --exitfirst --capture=no -k runCocotbTestsDivider testbench.py`. 

## Datapath Integration

After your divider is working, you will need to integrate it into your datapath. Your datapath is almost entirely unchanged from HW3, except that `div`, `divu`, `rem` and `remu` instructions will take 8 cycles instead of one. We'll refer to these 4 kinds of instructions as "divide operations" for simplicity.

Your divider module is pipelined and so, theoretically, you could start back-to-back independent divide operations on consecutive cycles for improved performance. However, your datapath will not (yet) take advantage of this and so consecutive divide operations will take 8 cycles each. Thus, *k* consecutive divide operations will take *8k* cycles.

You can run the processor tests via `pytest --exitfirst --capture=no -k runCocotbTestsProcessor testbench.py`. These include some simple assembly test cases as well as all of the riscv-tests and dhrystone.

All told, the datapath changes amount to around a dozen lines of code.


## Disallowed SystemVerilog Operators

You cannot use the `/` or `%` operators in your divider code (except as part of compile-time code like `for` loops), or additionally the `-` operator in your datapath (`-` is ok in the divider, however). Run `make codecheck` to see if any illegal operators are present; the autograder performs this same check.

## Testing and Debugging Notes

The autograder runs both the divider and the processor tests.

## Check timing closure

For this homework, you will again run synthesis and place-and-route to see how much your improved divider design affects overall frequency. To verify timing closure, run `make resource-check` (like in [HW3 instructions](../hw3-singlecycle/README.md#check-timing-closure)).


## Submitting

Run `make resource-check` and then `make zip` and submit the `multi.zip` file on Gradescope. There is a resource
leaderboard for this assignment, but it is strictly informational - no points are awarded to based on the leaderboard.
