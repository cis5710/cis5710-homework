In this homework, you'll create a key component of the processor: the divider unit.

RISC-V contains 4 division/remainder insns (`div`,`divu`,`rem` and `remu`) which
perform signed and unsigned divide and remainder operations. You will build a
module that performs unsigned division and remainder operations. In a later
homework when you build a complete RV processor, you will add a bit of
extra logic to support the signed division/remainder as well.

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

## Writing your code

Begin with the `divu_1iter` module that does one iteration of the division
operation. You can then instantiate this module 32 times to form the full
divider. Think about how each output value is computed from the inputs.

We recommend using a SV `for` loop to instantiate and connect the 32
instances. It is quite tedious (and error-prone) to connect them by hand.

## Tests

We have provided tests for both the `divu_1iter` and `divider_unsigned`
modules. You can run the `divu_1iter` tests via:

```
pytest-3 testbench_1iter.py
```

There are only a couple simple tests provided, so you may find it useful to use
these as a template for adding your own tests that cover various corner cases.

Later, when you have the `divu_1iter` module working you can run the
`divider_unsigned` tests with:

```
pytest-3 testbench.py
```

Note that the autograder only runs these latter `divider_unsigned` tests, so
only those will be part of your grade, not the "1iter" tests. You may again find
it useful to add your own tests.

## Submitting your code

Submit your `divider_unsigned.sv` file via Gradescope.
