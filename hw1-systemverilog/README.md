# HW1: SystemVerilog Debugging

This homework will introduce you to the process of building, testing and debugging SystemVerilog code.

There are two components to this homework. HW1A involves looking through a waveform file (`treasure_hunt.fst`) to get you familiar with looking at waveforms. HW1B involves fixing some bugs in some simple adder circuits.

We recommend you start with HW1A, though the two components don't really depend on each other. The instructions for the HW1A treasure hunt are **on the Gradescope assignment**. Here we discuss HW1B.

Note that both parts of HW1 are **individual assignments**, so you should complete them on your own.

## Run the tests

We've provided a [cocotb](https://www.cocotb.org) testbench for you, in the file `testbench.py`. A testbench is code that generates test inputs, provides each input to a module being tested (called the UUT/DUT for "unit under test" or "design under test"), and checks that the output is correct. Testbench code is purely for simulation, so it can be written in a software language like Python that cannot be translated into hardware.

The provided `testbench.py` file tests all possible inputs for each of the
modules in `rca.sv` - it is a very thorough testbench, made possible because the
DUTs are quite simple. 

Run the tests by `cd`-ing into the `hw1-systemverilog` directory (where this file is) and running the command `pytest -xs testbench.py --tests halfadder`. The `--tests` flag can be used to filter which tests are run; we start with the `halfadder` since that's the simplest module in `rca.sv` and it doesn't instantiate any other modules, but other modules instantiate it. The `pytest` command will compile your design and then run the tests on it with the [Verilator](http://verilator.org) simulator. The tests should pass, indicating that the halfadder is good to go :-).

Next, run the fulladder tests with `pytest -xs testbench.py --tests fulladder`. Unfortunately, the code will fail to compile. The compiler error can help guide you to what is wrong with the code.

## The rest of the tests

After fixing `fulladder`, you can move on to `fulladder2` and finally `rca4`. The bugs you encounter will involve different issues. Sometimes the code will fail to compile. Sometimes the code may compile but fail to work correctly, in which case looking at the tests and waveforms will be necessary instead.

When a test fails, it tells you that something is wrong, but it doesn't explain why. Careful testing of each module can be helpful in limiting the amount of code you need to examine: if we had only given tests for the `rca4` module, and it fails a test, you don't immediately know whether the bug is in `rca4` itself or in `fulladder2`, `fulladder`, or `halfadder`. But if you start at the bottom of the module hierarchy and work up, you can shorten your debugging journey.

A good place to start when you have a failing test case is to look at the testbench code to understand the test that failed. The `pytest` output will tell you which assert inside `testbench.py` failed, and by looking at the `testbench.py` code you can see what was being tested. Once you see which hardware signal has the wrong value, you should try to trace "backwards" in the SystemVerilog code and see why the bad value is there. To better understand what is going on, dig into the waveforms! They really make it faster to perform this backwards tracing to hone in on the root cause of the bug.

> cocotb puts waveforms for a failing test in the `sim_build/dump.fst` file.

## Submitting Code

Once your code passes all the tests, you are ready to submit your fixed `rca.sv` file **via Gradescope**.


## FPGA Demo

Now that your code works in simulation, you can run the FPGA board demo to see it run in real life! 

### Generating a bitstream

Inside the Docker container, run the command `make synth pnr`. This will generate a *bitstream* file by running *synthesis* and then *place-and-route*, mapping your design onto the FPGA's hardware.

When this completes, you will have your bitstream file in `fpga_build/rca4_demo.bit`.

### Programming the FPGA

TODO: update! see if we can program from container

You can use `make program` to download your bitstream onto the FPGA, a process known as "programming the FPGA". Once the FPGA is programmed, your design is running in hardware!

The demo code is in the `rca4_demo` module, and it uses your adder to add 2 to a 4-digit binary number represented by four of the board's buttons (B2, B5, B4, B6). When a button is not pressed, it represents a 0; pressing it changes that bit to a 1 instead. The resulting sum is displayed on the LEDs D0-D5.
