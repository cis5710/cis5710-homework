You'll implement a two-level Carry-LookAhead (CLA) adder, as discussed in class. This adder will then be used in your processor implementation in a later homework.

## gp4 schematic

Draw a detailed schematic (by hand or computerized) of your hardware design for the `gp4` CLA module. You don't need to draw a CLA schematic or one for `gp8`; those are similar to the lecture slides and to `gp4`, respectively.

You should include signal names, module names, port names and bus widths. You can leave a module as a black box to simplify things, but then you should show elsewhere on the schematic what that black box does.

Simple modules (e.g., muxes and the SystemVerilog operators you are allowed to use) can be drawn as in the lecture slides or as a simple box with a label. They don't need further elaboration.

See also [the example schematic for Lab 1](../hw1-systemverilog/hw1-schematic.pdf).

When your schematic is complete, you can translate it directly into SystemVerilog. We encourage you to keep your schematic up-to-date as your design evolves.


## gp4/gp8 modules

We supply some skeleton code in `cla.sv`, including module port definitions and the simple `gp1` generate-propagate module at the leaf of the CLA hierarchy. You will need to implement three additional modules to have a complete 32-bit adder.

You should start with the `gp4` module, which computes aggregate g/p signals for a 4-bit slice of the addition. The module takes the bit-level g/p signals from `gp1` as input, and computes whether all 4 bits collectively generate/propagate a carry. The module also computes the actual carry-out values for the low-order 3b of its input. You should also think about why `gp4` doesn't compute 4b worth of carry-out 😉. The `gp4` module will form the top layer of your CLA hierarchy. Our `gp4` solution is about 30 lines of code.

SystemVerilog's reduction operators will come in handy in building your `gp4` module. They perform a bit-wise reduction like so:
```
wire [3:0] w;
wire or_reduction;
assign or_reduction = (| w);
assign or_reduction = (w[3] | w[2] | w[1] | w[0]); // equivalent to code above
```
Reductions can be combined with indexing to reduce just a portion of a bus:
```
wire [3:0] w;
wire or_reduction;
assign or_reduction = (| w[2:0]);
assign or_reduction = (w[2] | w[1] | w[0]); // equivalent to code above
```

You can run `gp4` tests via `pytest-3 -s testbench_gp4.py`, though their coverage is low so we encourage you to add other test cases as well.

Once you have the `gp4` module working, you can move on to the `gp8` module which will form the base of your CLA hierarchy. The `gp8` logic is a generalization of `gp4` to a larger window size. Though it is harder, you may consider implementing a parameterized `gpn` module that computes generate/propagate/carry-out over an N-bit window. You can then instantiate this appropriately for both `gp4` and `gp8`.

## cla module

Finally, you will build the 32-bit adder module `cla`. Use the `gp1`, `gp4` and `gp8` modules to build your CLA tree and to compute the final sum. Our `cla` solution is about 30 lines of code.

You can test your `cla` module via `pytest-3 -s testbench.py`. This is the set of tests that the autograder will run; it does not test your `gp4`/`gp8` modules by themselves.

## Submitting your code

Submit your `cla.sv` file on Gradescope.
