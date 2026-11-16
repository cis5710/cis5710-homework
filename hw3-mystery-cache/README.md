# HW3: Mystery Cache

In this assignment, you must reverse-engineer a rival processor company's L1 data cache design by running assembly programs on their chip and inferring the design from the sequence of hits and misses you observe. You have obtained access to gem5 simulators representing two different chips, and must discover the L1d design of each one. You know the following things about these chips:

* There is no L2 cache, only an L1
* Instruction (code) cache accesses can be ignored
* All block sizes and total cache capacities are powers of two
* Cache capacity is at most 1MB
* All caches implement the LRU replacement policy
* There is no prefetching or victim buffer, there is only an L1D cache
* You know that the `gem5-mystery0` processor has a direct-mapped cache
* The `gem5-mystery1` cache has unknown associativity.

You must discover the *cache block size*, *associativity* (for `mystery1`) and *total capacity* of these caches.

# Probing the cache

First, you must write a small RISC-V assembly program to perform memory accesses that exercise the cache. We have given you some sample code in `template.s` which you will need to modify.

First, navigate to the HW3 directory and compile the assembly code into a `probe` binary:
```
cd /workspaces/gem5-cis5710-homework/hw3-mystery-cache/
riscv64-linux-gnu-gcc -nostdlib -static -o probe template.s
```

Next, run that binary on a simulator. It will report hits and misses.
```
./gem5-mystery0 probe
```

Based on the program you wrote and the report, try to infer how the cache is organized. You will need to write and run several different programs to precisely identify the cache organization.

# Submitting your answers

Submit your answers on Gradescope.
