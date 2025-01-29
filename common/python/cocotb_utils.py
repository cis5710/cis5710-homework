"""This file has code used across several testbenches."""

from pathlib import Path

VERILATOR_FLAGS = [
    '--assert',
    '-Wall',
    '-Wno-DECLFILENAME',
    '--trace',
    '--trace-fst',
    '--trace-structs',
    # NB: --trace-max-array must be ≥ size of the memory (in 4B words) for memory to appear in the waveforms
    '--trace-max-array',str(2**18)
    ]

# directory where our simulator will compile our tests + code
SIM_BUILD_DIR = "sim_build"

# simulator to use
SIM = "verilator"

# NB: these paths are relative to the testbench file, not cocotb_utils.py
RISCV_TESTS_PATH = Path('../../riscv-tests/isa')
RISCV_BENCHMARKS_PATH = Path('../../riscv-tests/benchmarks')

POINTS_FILE = 'points.json'

def assertEquals(expected, actual, msg=''):
    """Wrapper around regular assert, with automatic formatting of values in hex"""
    if expected != actual:
        assert_msg = f'expected 0x{int(expected):X} but was 0x{int(actual):X}'
        if msg != '':
            assert_msg += f': {msg}'
            pass
        assert expected == actual, assert_msg
        pass
    pass

def aggregateTestResults(*results):
    """Aggregates total/failed counts from all arguments, where each argument is a call to cocotb.runner.get_results()"""
    total_tests = sum([r[0] for r in results])
    total_failed_tests = sum([r[1] for r in results])
    return { 
        'tests_total': total_tests,
        'tests_failed': total_failed_tests,
        'tests_passed': total_tests - total_failed_tests
        }
