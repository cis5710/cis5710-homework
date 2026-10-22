# HW2: Branch Prediction

This is an individual assignment.

In this assignment, you will modify gem5's existing bimodal branch predictor (`LocalBP` in the code) to add a *tag* to each saturating counter to avoid aliasing among different branch PCs. You will then run a benchmark to see how well your modified branch predictor performs.

### Writing the code

Review the code for a bimodal branch predictor in `/gem5/src/cpu/pred/2bit_local.hh` and `2bit_local.cc`. Extend this code to include an `Addr`-sized *tag* to each saturating counter.

**Predicting** When a prediction is made (the `lookup` function), check the tag. If the tag matches, then we know the saturating counter reflects the state of the current branch, and we return whatever prediction the counter says. If the tag does not match, return "not taken" as a prediction, as a safe default.

**Training** When the predictor is updated, if the tag matches the PC of the current branch, then update the counter as normal. If the tag does *not* match, set the counter to the weakly-not-taken or weakly-taken state (to avoid being biased by the behavior of the prior branch at the counter) based on the true branch direction, and set the tag to the PC of the current branch. Nothing needs to be done if `squashed` is true, as LocalBP does not update state on wrong-path execution.

You must also add a new boolean configuration parameter `tagMatching` to `/gem5/src/cpu/pred/BranchPredictor.py`, which enables/disables the tag behavior. When `tagMatching == False` (the default), `LocalBP` should retain the original bimodal predictor behavior. When `tagMatching == True`, your tagging logic should be activated. Having a configuration parameter allows you to easily toggle the tagging on/off without rebuilding gem5.

We also recommend you implement some statistics to track the behavior of your tagged predictor, e.g., counting the number of times tags were matched or mismatched. This can help you debug your implementation, and also provides insight into why the predictor performs the way it does. gem5 tracks many stats, which are written to `m5out/stats.txt` at the end of the simulation. See `/gem5/src/cpu/pred/bpred_unit.hh` and `bpred_unit.cc` for examples of how to work with stats in gem5. 

### Building gem5

To build gem5, run the following commands from inside the Dev Container:

```
cd /gem5
scons --limit-ld-memory-usage --linker=gold build/RISCV/gem5.opt
```

For reference, our Docker image uses gem5 commit `f5c5a6e390f55dd5984977815bf9d0bd05da6945`.

### Run experiments

To run gem5, run the following commands from inside the Dev Container:

```
cd /workspaces/gem5-cis5710-homework/hw2-bpred-tags
/gem5/build/RISCV/gem5.opt hw2.gem5.py hello
```

This will run a simple `hello-world` program on your processor. Note that `hw2.gem5.py` reports IPC and MPKI (mispredictions per kilo-instructions) at the end of the simulation.

For `hello-world`, with tagging enabled our reference implementation reports:
```
IPC             = 0.179
MPKI            = 53.290
Tag Matches     = 2215
Tag Mismatches  = 2079
```
You can use these numbers to help debug your implementation.

### Submit to Gradescope

Submit your modified `2bit_local.hh`, `2bit_local.cc` and `BranchPredictor.py` files on Gradescope. The autograder will build and run your code with `qsort` to validate IPC and MPKI. Tag (mis)matches are not compared.

We're seeing the autograder take at least 20 minutes to compile and run your code, so please budget your time accordingly.