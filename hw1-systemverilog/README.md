# HW1: SystemVerilog Debugging

This homework will introduce you to the process of building, testing and debugging SystemVerilog code.

There are two components to this homework. HW1A involves looking through a waveform file (`treasure_hunt.vcd`) using the GtkWave program to get you familiar with looking at waveforms. HW1B involves fixing some bugs in some simple adder circuits.

We recommend you start with HW1A, though the two components don't really depend on each other. The instructions for the HW1A treasure hunt are **on the Gradescope assignment**. Here we discuss HW1B.

Note that both parts of HW1 are **individual assignments**, so you should complete them on your own.

## Run the tests

We've provided a [cocotb](https://www.cocotb.org) testbench for you, in the file `testbench.py`. A testbench is code that generates test inputs, provides each input to a module being tested (called the UUT/DUT for "unit under test" or "design under test"), and checks that the output is correct. Testbench code is purely for simulation, so it can be written in a software language like Python
that cannot synthesize into real hardware.

The provided `testbench.py` file tests all possible inputs for each of the
modules in `rca.sv` - it is a very thorough testbench, made possible because the
DUTs are quite simple. 

Run the tests by `cd`-ing into the `hw1` directory (where this file is) and running the command `pytest-3 testbench.py --tests halfadder`. The `--tests` flag can be used to filter which tests are run; we start with the `halfadder` since that's the simplest module in `rca.sv` and it doesn't instantiate any other modules, but other modules instantiate it. The `pytest-3` command will compile your design and then run the tests on it with the [Verilator](http://verilator.org) simulator. The tests should pass, indicating that the halfadder is good to go :-).

Next, run the fulladder tests with `pytest-3 testbench.py --tests fulladder`. Unfortunately, the code will fail to compile. The compiler error can help guide you to what is wrong with the code.

## The rest of the tests

After fixing `fulladder`, you can move on to `fulladder2` and finally `rca4`. The bugs you encounter will involve different issues. Sometimes the code will fail to compile. Sometimes the code may compile but fail to work correctly, in which case looking at the tests and waveforms will be necessary instead.

When a test fails, it tells you that something is wrong, but it doesn't explain why. Careful testing of each module can be helpful in limiting the amount of code you need to examine: if we had only given tests for the `rca4` module, and it fails a test, you don't immediately know whether the bug is in `rca4` itself or in `fulladder2`, `fulladder`, or `halfadder`. But if you start at the bottom of the module hierarchy and work up, you can shorten your debugging journey.

A good place to start when you have a failing test case is to look at the testbench code to understand the test that failed. The `pytest-3` output will tell you which assert inside `testbench.py` failed, and by looking at the `testbench.py` code you can see what was being tested. Once you see which hardware signal has the wrong value, you should try to trace "backwards" in the SystemVerilog code and see why the bad value is there. To better understand what is going on, dig into the waveforms! They really make it faster to perform this backwards tracing to hone in on the root cause of the bug.

> cocotb puts waveforms for a failing test in the `sim_build/dump.fst` file.

## Submitting Code

Once your code passes all the tests, you are ready to submit your fixed `rca.sv` file **via Gradescope**.


## Optional ZedBoard Demo

Now that your code works in simulation, you can run the ZedBoard demo if you want. For this (and future) demos you'll need to work from the [SEAS Biglab
machines](https://www.seas.upenn.edu/cets/answers/biglab.html). The Vivado tools
are too heavyweight to run with the time/memory limitations in place on eniac, and would make our Docker container extremely large.

### Generating a bitstream

After you get your code on biglab, run the command `source /home1/c/cis5710/tools/cis5710-update-path.sh` to update your `$PATH` variable to find the Vivado tools. Then, change to the `hw1` directory and run the command `make impl` to generate a `.bit` bitstream file. This will run the *synthesis* and *implementation* steps of the FPGA design flow, mapping your design onto the ZedBoard's hardware. It will take a few minutes.

When implementation completes, it should create a bitstream file `output/rca4.bit`.

### Programming via Linux command line (recommended)

The simplest way to program the ZedBoards is to use a SEAS Linux machine, found in Moore 100A, the K Lab in Moore 200, and a few in Towne M70.

> Note that stations in the K Lab have both a Windows *and* a Linux machine (the Linux machines in the K Lab are the machines **with all-black USB ports on the front**. The machines with the blue USB 3.0 ports are the Windows machines.). You can switch between them via the KVM (keyboard/video/mouse) switch beneath the monitor: the Linux machine is typically **input 2**.

Once you login to the machine, follow the [instructions for connecting the
ZedBoard](https://docs.google.com/presentation/d/1spwy8Ech3oLO72_VbKN5WkDlwbWy0WWISxv_lMjhRkg/edit?usp=sharing),
and then switch to the terminal application. From the
lab1 directory, run the command `make program`. You will be prompted for the
`.bit` bitstream file you want to use, and then the FPGA should get programmed
accordingly.

#### Programming via Vivado GUI

You can also program the ZedBoard via the Vivado GUI. See [instructions for Windows here](https://docs.google.com/presentation/d/1spwy8Ech3oLO72_VbKN5WkDlwbWy0WWISxv_lMjhRkg/edit?usp=sharing). 

You can use similar instructions to program via the Vivado GUI on a Linux machine. Start Vivado by running the usual `source ...` command to get the Vivado tools onto your PATH, then run the command `vivado &` on the command line and the GUI should appear within a few moments. You can then follow the Windows tutorial linked above as the menus are identical.

In our experience, the Linux version is substantially more responsive than the Windows version (not the fault of Windows, it seems to be due to the way that the Windows version of Vivado is installed onto a network drive).

### Use your design

Once the FPGA is programmed, your design is running in hardware! The toggle switches at the bottom of the ZedBoard are used to input two 4-bit integers, and their 4-bit sum is displayed on the lowest-order 4 LEDs.
