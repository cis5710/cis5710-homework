In this homework, you'll create a key component of the processor: the divider unit.

RISC-V contains 4 division/remainder insns (`div`,`divu`,`rem` and `remu`) which
perform signed and unsigned divide and remainder operations. You will build a
module that performs unsigned division and remainder operations. In a later
homework when you build a complete RV processor, you will add a bit of
extra logic to support the signed division/remainder operations as well.

## Division Algorithm (Software)

The module takes as input two 32-bit data values (dividend and divisor) and
outputs two 32-bit values (remainder and quotient). It should use the following
algorithm, described in C code:

```c
int divide(int dividend, int divisor) {
    int quotient = 0;
    int remainder = 0;

    for (int i = 0; i < 32; i++) {
        remainder = (remainder << 1) | ((dividend >> 31) & 0x1);
        if (remainder < divisor) {
            quotient = (quotient << 1);
        } else {
            quotient = (quotient << 1) | 0x1;
            remainder = remainder - divisor;
        }

        dividend = dividend << 1;
    }

    return quotient;
}
```

Your circuit will compute the quotient and remainder in the same way, but in a
single cycle using combinational logic only.


## Corner case: divide-by-zero

A divisor of 0 is a special case. You do not need to handle this case in your
modules. In a later homework, you will need to handle this and other corner
cases per the RV ISA specification.

## Disallowed Verilog Operators

You cannot use SystemVerilog's `/` or `%` operators in your code. This will be
enforced by the autograder, and you can run `make codecheck` to perform these
same checks yourself before submitting.

## Schematic

Draw a detailed schematic (by hand or computerized) of your hardware design for the divider. You should include signal names, module names, port names and bus widths. You can leave a module as a black box to simplify things, but then you should show elsewhere on the schematic what that black box does. Simple modules (muxes and any SystemVerilog operators you are allowed to use) can be drawn as in the lecture slides or as a simple box with a label; they don't need further elaboration. For the `divider_unsigned` module, you don't need to draw all 32 instances of the `divu_1iter` module, but should show **the first two and the last one** to demonstrate that you know how to wire them together.

See also [the example schematic for HW1](../hw1-systemverilog/hw1-schematic.pdf). Grading of the schematics will be on a full-credit/no-credit basis. We won't rigorously examine the correctness of your design, but instead aim to give you quick feedback about obvious flaws. Still, it behooves you to invest time in your schematic to catch bugs up-front, instead of looking at waveforms or code.

**Please make sure your PDFs are rotated correctly, and are not insanely huge resolution!** We will take points off for these since they make grading more difficult.

When your schematic is complete, you can translate it directly into SystemVerilog. We encourage you to keep your schematic up-to-date as your design evolves, as it will help ensure your design works as required.

## Writing your code

Begin with the `divu_1iter` module that does one iteration of the division
operation. You can then instantiate this module 32 times to form the full
divider. Think about how each output value is computed from the inputs.

We recommend using a SV `for` loop to instantiate and connect the 32
instances. It is quite tedious (and error-prone) to connect them by hand.

## Tests

We have provided tests for both the `divu_1iter` and `divider_unsigned`
modules. You can run tests via the command

```
MAKEFLAGS=-j4 pytest --exitfirst --capture=no testbench.py
```

This runs the `divu_1iter` tests and then the `divider_unsigned` tests, exiting at the first failure.
There are only a couple simple tests provided in the `testbench*.py` files, so you may find it useful to use
these as a template for adding your own tests to cover various corner cases.

## Submitting your code

Submit your `divider_unsigned.sv` file via Gradescope.
