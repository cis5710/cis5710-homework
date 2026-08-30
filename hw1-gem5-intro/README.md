# HW1: Intro to gem5

This assignment will introduce you to building and running the gem5 microarchitecture simulator, which will be the main tool we use for the homework in this class.

Before you can begin the assignment, you should follow the [setup instructions](../README.md) to set up VS Code and the Docker container for this course.



# Step 1: Build gem5

We have pre-compiled much of gem5 for you (which takes several hours), but left a few pieces open so that you can familiarize yourself with the build process for future homeworks.

Inside your VS Code dev container's shell, run the following commands:

```
cd /gem5
scons build/RISCV/gem5.fast
```

This will build a simulator that models a RISC-V chip that can contain a wide variety of configurable CPU pipelines, caches, on-chip networks and memory systems.

You'll find that the build encounters a compiler error, due to a small syntax error that we've added to the source code. Fix the error so that the simulator builds successfully.



# Step 2: Run mystery binary

Now that you have built the simulator, you are ready to run it. From VS Code, click on the `Output` tab on the bottom and then the `Terminal` section. This is a shell session running inside your dev contianer.

At the shell prompt, run this command:
```
cd hw1-gem5-intro
```

gem5 is controlled via a Python interface. Examine the file `hw1.gem5.py`, which constructs the simulator out of the different building blocks that gem5 provides, like CPUs, caches, etc. This Python script also tells the simulator which program to run.

Launch the simulator like this:
```
/gem5/build/RISCV/gem5.fast hw1.gem5.py
```

This will run the `mystery.bin` RISC-V program. Use the output of this program to submit your answer on Gradescope for this homework.



# Additional Resources

You can learn more about gem5 through the [Learning gem5 online book](https://www.gem5.org/documentation/learning_gem5/introduction/).
