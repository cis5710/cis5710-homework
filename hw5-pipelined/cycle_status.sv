/**
 * This enum is used to classify each cycle as it comes through the Writeback stage, identifying
 * if a valid insn is present or, if it is a stall cycle instead, the reason for the stall. The
 * enum values are mutually exclusive: only one should be set for any given cycle. These values
 * are compared against the trace-*.json files to ensure that the datapath is running with the
 * correct timing.
 *
 * You will need to set these values at various places within your pipeline, and propagate them
 * through the stages until they reach Writeback where they can be checked. Note that MULTIPLE
 * stall conditions may be present in a single cycle.
 */
typedef enum {
  /** invalid value, this should never appear after the initial reset sequence completes */
  CYCLE_INVALID = 0,
  /** a stall cycle that arose from the initial reset signal */
  CYCLE_RESET = 1,
  /** not a stall cycle, a valid insn is in Writeback */
  CYCLE_NO_STALL = 2,
  /** a stall cycle that arose from a taken branch/jump */
  CYCLE_TAKEN_BRANCH = 4,

  // the values below are only needed in HW5B and later

  /** a stall cycle that arose from waiting for a multi-cycle div/rem insn */
  CYCLE_DIV = 8,
  /** a stall cycle that arose from a load-to-use stall */
  CYCLE_LOAD2USE = 16,
  /** a stall cycle that arose from a div/rem-to-use stall */
  CYCLE_DIV2USE = 32,
  /** NOT CURRENTLY USED: a stall cycle that arose from a fence.i insn */
  CYCLE_FENCEI = 64,

  // the values below are only needed in HW6B

  /** a stall cycle that arose from an insn cache miss */
  CYCLE_ICACHE_MISS = 128,
  /** a stall cycle that arose from a data cache miss */
  CYCLE_DCACHE_MISS = 256

} cycle_status_e;
