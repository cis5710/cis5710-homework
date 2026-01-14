You'll implement a two-level Carry-LookAhead (CLA) adder, as discussed in class. This adder will then be used in your processor implementation in a later homework.

## gp4 schematic

Draw a detailed schematic (by hand or computerized) of your hardware design for the `gp4` CLA module. You don't need to draw a CLA schematic or one for `gp8`; those are similar to the lecture slides and to `gp4`, respectively.

You should include signal names, module names, port names and bus widths. You can leave a module as a black box to simplify things, but then you should show elsewhere on the schematic what that black box does.

Simple modules (e.g., muxes and the SystemVerilog operators you are allowed to use) can be drawn as in the lecture slides or as a simple box with a label. They don't need further elaboration.

See also [the example schematic for Lab 1](../hw1-systemverilog/hw1-schematic.pdf).

When your schematic is complete, you can translate it directly into SystemVerilog. We encourage you to keep your schematic up-to-date as your design evolves.


## gp4/gp8 modules

We supply some skeleton code in `CarryLookaheadAdder.sv`, including module port definitions and the simple `gp1` generate-propagate module at the leaf of the CLA hierarchy. You will need to implement three additional modules to have a complete 32-bit adder.

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

You can run `gp4` tests via `pytest --exitfirst --capture=no testbench.py -k runCocotbTestsGp4`, though their coverage is low so we encourage you to add other test cases as well.

Once you have the `gp4` module working, you can move on to the `gp8` module which will form the base of your CLA hierarchy. The `gp8` logic is a generalization of `gp4` to a larger window size. Though it is harder, you may consider implementing a parameterized `gpn` module that computes generate/propagate/carry-out over an N-bit window. You can then instantiate this appropriately for both `gp4` and `gp8`.

## CarryLookaheadAdder module

Finally, you will build the 32-bit adder module `CarryLookaheadAdder`. Use the `gp1`, `gp4` and `gp8` modules to build your CLA tree and to compute the final sum. Our `CarryLookaheadAdder` solution is about 30 lines of code.

You can test your `CarryLookaheadAdder` module via `pytest --exitfirst --capture=no testbench.py -k runCocotbTestsCla`.

The autograder will run both the CLA and gp4 tests. You can do this yourself via the command `pytest --exitfirst --capture=no testbench.py`

## Submitting your code

Submit your `CarryLookaheadAdder.sv` file on Gradescope.

## FPGA Demo

Now that your code works in simulation, you can run the FPGA board demo to see it run in real life!

The demo for this homework is the **CLA Challenge**, which checks your CLA against all possible 16-bit inputs (2<sup>32</sup> total). Progress is shown via the LEDs on the board, with a blinking LED indicating that a section (1/8th of the input space) is in progress, and a solid LED indicating that a section was checked successfully. If all 8 LEDs are solid at the end of the test, your design has succesfully passed the CLA Challenge! If an error is detected, the blinking stops and shows solid LEDs for the completed sections; the first (rightmost) unlit LED indicates the failed section.

The design runs at 25 MHz, so the challenge takes a little under 3 minutes to complete.

[Just as in HW1](../hw1-systemverilog/README.md#fpga-demo), run `make demo` inside the Docker container to build your bitstream (in `fpga_build/SystemDemo.bit`). Then, outside the container, connect the FPGA via USB and program it to see the demo run!
