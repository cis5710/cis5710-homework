import cocotb, json, os, sys, random

from pathlib import Path
from cocotb.runner import get_runner, get_results
from cocotb.triggers import Timer

# directory for this homework
PROJECT_PATH = Path(__file__).resolve().parent

p = Path.cwd() / '..' / 'common' / 'python'
sys.path.append(str(p))
import cocotb_utils as cu
from cocotb_utils import assertEquals

# for deterministic random numbers
random.seed(12345)

def runCocotbTestsHalfAdder(pytestconfig):
    """run half adder tests"""

    verilog_sources = [ PROJECT_PATH / "rca.sv" ]
    toplevel_module = "halfadder"

    runr = get_runner(cu.SIM)
    runr.build(
        verilog_sources=verilog_sources,
        vhdl_sources=[],
        hdl_toplevel=toplevel_module,
        waves=cu.shouldGenerateWaveforms(),
        includes=[PROJECT_PATH],
        build_dir=cu.SIM_BUILD_DIR,
        build_args=cu.VERILATOR_FLAGS,
    )

    runr.test(
        seed=12345,
        waves=cu.shouldGenerateWaveforms(),
        hdl_toplevel=toplevel_module, 
        test_module=Path(__file__).stem, # use tests from the current file
        testcase="test_" + toplevel_module
    )
    pass

def runCocotbTestsFullAdder1(pytestconfig):
    """run fulladder1 tests"""

    verilog_sources = [ PROJECT_PATH / "rca.sv" ]
    toplevel_module = "fulladder1"

    runr = get_runner(cu.SIM)
    runr.build(
        verilog_sources=verilog_sources,
        vhdl_sources=[],
        hdl_toplevel=toplevel_module,
        waves=cu.shouldGenerateWaveforms(),
        includes=[PROJECT_PATH],
        build_dir=cu.SIM_BUILD_DIR,
        build_args=cu.VERILATOR_FLAGS,
    )

    runr.test(
        seed=12345,
        waves=cu.shouldGenerateWaveforms(),
        hdl_toplevel=toplevel_module, 
        test_module=Path(__file__).stem, # use tests from the current file
        testcase="test_" + toplevel_module
    )
    pass

def runCocotbTestsFullAdder2(pytestconfig):
    """run fulladder2 tests"""

    verilog_sources = [ PROJECT_PATH / "rca.sv" ]
    toplevel_module = "fulladder2"

    runr = get_runner(cu.SIM)
    runr.build(
        verilog_sources=verilog_sources,
        vhdl_sources=[],
        hdl_toplevel=toplevel_module,
        waves=cu.shouldGenerateWaveforms(),
        includes=[PROJECT_PATH],
        build_dir=cu.SIM_BUILD_DIR,
        build_args=cu.VERILATOR_FLAGS,
    )

    runr.test(
        seed=12345,
        waves=cu.shouldGenerateWaveforms(),
        hdl_toplevel=toplevel_module, 
        test_module=Path(__file__).stem, # use tests from the current file
        testcase="test_" + toplevel_module
    )
    pass

def runCocotbTestsRca4(pytestconfig):
    """run rca4 tests"""

    verilog_sources = [ PROJECT_PATH / "rca.sv" ]
    toplevel_module = "rca4"

    runr = get_runner(cu.SIM)
    runr.build(
        verilog_sources=verilog_sources,
        vhdl_sources=[],
        hdl_toplevel=toplevel_module,
        waves=cu.shouldGenerateWaveforms(),
        includes=[PROJECT_PATH],
        build_dir=cu.SIM_BUILD_DIR,
        build_args=cu.VERILATOR_FLAGS,
    )

    runr.test(
        seed=12345,
        waves=cu.shouldGenerateWaveforms(),
        hdl_toplevel=toplevel_module, 
        test_module=Path(__file__).stem, # use tests from the current file
        testcase="test_" + toplevel_module
    )
    pass

def runCocotbTests(pytestconfig):
    """calculate scores for autograder"""
    test_results = cu.aggregateTestResults(
        get_results(Path(cu.SIM_BUILD_DIR,'runCocotbTestsHalfAdder.None')),
        get_results(Path(cu.SIM_BUILD_DIR,'runCocotbTestsFullAdder1.None')),
        get_results(Path(cu.SIM_BUILD_DIR,'runCocotbTestsFullAdder2.None')),
        get_results(Path(cu.SIM_BUILD_DIR,'runCocotbTestsRca4.None')),
    )
    # 1 point per cocotb test
    points = { 'pointsEarned': test_results['tests_passed'], 'pointsPossible': test_results['tests_total'] }
    with open(cu.POINTS_FILE, 'w') as f:
        json.dump(points, f, indent=2)
        pass
    pass


#########################
## TEST CASES ARE HERE ##
#########################

@cocotb.test()
async def test_halfadder(dut):
    for a in [0,1]:
        for b in [0,1]:
            await Timer(1, "ns")
            dut.a.value = a
            dut.b.value = b
            await Timer(1, "ns")
            if a == 0 and b == 0:
                # 0 + 0 == 0
                assertEquals(0, dut.s.value)
                assertEquals(0, dut.cout.value)
            elif a == 1 and b == 1:
                # 1 + 1 == 2'b10
                assertEquals(0, dut.s.value)
                assertEquals(1, dut.cout.value)
            else:
                # 1+0 (or 0+1) == 1
                assertEquals(1, dut.s.value)
                assertEquals(0, dut.cout.value)
                pass
            pass
        pass
    pass

@cocotb.test()
async def test_fulladder1(dut):
    for a in [0,1]:
        for b in [0,1]:
            for c in [0,1]:
                await Timer(1, "ns")
                dut.a.value = a
                dut.b.value = b
                dut.cin.value = c
                await Timer(1, "ns")
                sum = a + b + c
                if 0 == sum:
                    assertEquals(0, dut.s.value)
                    assertEquals(0, dut.cout.value)
                elif 1 == sum:
                    assertEquals(1, dut.s.value)
                    assertEquals(0, dut.cout.value)
                elif 2 == sum:
                    assertEquals(0, dut.s.value)
                    assertEquals(1, dut.cout.value)
                else:
                    assertEquals(1, dut.s.value)
                    assertEquals(1, dut.cout.value)
                    pass
                pass
            pass
        pass
    pass

@cocotb.test()
async def test_fulladder2(dut):
    for a in range(4):
        for b in range(4):
            for c in [0,1]:
                await Timer(1, "ns")
                dut.a.value = a
                dut.b.value = b
                dut.cin.value = c
                await Timer(1, "ns")
                expected_sum = a + b + c
                actual_sum = dut.s.value + (dut.cout.value << 2)
                assertEquals(expected_sum, actual_sum, f'expected {a}+{b}+{c} == {expected_sum} but it was {dut.s.value} + {dut.cout.value} == {actual_sum}')
                pass
            pass
        pass
    pass

@cocotb.test()
async def test_rca4(dut):
    for a in range(16):
        for b in range(16):
            for c in [0,1]:
                await Timer(1, "ns")
                dut.a.value = a
                dut.b.value = b
                await Timer(1, "ns")
                expected_sum = (a + b) & 0x0F # truncate to 4 bits
                expected_cout = ((a + b) & 0x10) >> 4
                actual_sum = dut.sum.value
                actual_cout = dut.carry_out.value
                assertEquals(expected_sum, actual_sum, f'expected {a}+{b} == {expected_sum} but it was {actual_sum}')
                assertEquals(expected_cout, actual_cout, f'expected carry-out of {a}+{b} to be {expected_cout} but it was {actual_cout}')
                pass
            pass
        pass
    pass
