import cocotb, json, random, sys

from pathlib import Path
from cocotb.runner import get_runner, get_results
from cocotb.triggers import Timer

p = Path.cwd() / '..' / 'common' / 'python'
sys.path.append(str(p))
import cocotb_utils

# directory where our simulator will compile our tests + code
SIM_BUILD_DIR = "sim_build"

# simulator to use
SIM = "verilator"

VERILATOR_FLAGS = ['--assert','-Wall','-Wno-DECLFILENAME','--trace-fst','--trace-structs']
random.seed(12345) # for determinism
PROJECT_PATH = Path(__file__).resolve().parent

def runCocotbTestsGp4(pytestconfig):
    """run GP4 tests"""

    verilog_sources = [PROJECT_PATH / "cla.sv" ]
    toplevel_module = "gp4"

    runr = get_runner(SIM)
    runr.build(
        verilog_sources=verilog_sources,
        hdl_toplevel=toplevel_module,
        includes=[PROJECT_PATH],
        build_dir=SIM_BUILD_DIR,
        always=True,
        waves=True,
        build_args=VERILATOR_FLAGS,
    ),

    runr.test(
        seed=12345,
        waves=True,
        hdl_toplevel=toplevel_module, 
        test_module='testbench_gp4', # use tests from testbench_gp4.py
        testcase=pytestconfig.option.tests,
    )
    pass

def runCocotbTestsCla(pytestconfig):
    """run CLA tests"""

    verilog_sources = [PROJECT_PATH / "cla.sv" ]
    toplevel_module = "cla"

    try:
        runr = get_runner(SIM)
        runr.build(
            verilog_sources=verilog_sources,
            hdl_toplevel=toplevel_module,
            includes=[PROJECT_PATH],
            build_dir=SIM_BUILD_DIR,
            always=True,
            waves=True,
            build_args=VERILATOR_FLAGS,
        ),

        runr.test(
            seed=12345,
            waves=True,
            hdl_toplevel=toplevel_module, 
            test_module=Path(__file__).stem, # use tests from this file
            testcase=pytestconfig.option.tests,
        )
    finally:
        test_results = cocotb_utils.aggregate_test_results(
            get_results(Path(SIM_BUILD_DIR,'runCocotbTestsGp4.None')),
            get_results(Path(SIM_BUILD_DIR,'runCocotbTestsCla.None'))
        )
        # 1 point per cocotb test
        points = { 'pointsEarned': test_results['tests_passed'], 'pointsPossible': test_results['tests_total'] }
        with open('points.json', 'w') as f:
            json.dump(points, f, indent=2)
            pass
        pass


#########################
## TEST CASES ARE HERE ##
#########################

@cocotb.test()
async def test_0_0_0(dut):
    await Timer(1, "ns")
    dut.a.value = 0
    dut.b.value = 0
    dut.cin.value = 0
    await Timer(1, "ns")
    assert 0 == dut.sum.value

@cocotb.test()
async def test_0_1_0(dut):
    await Timer(1, "ns")
    dut.a.value = 0
    dut.b.value = 1
    dut.cin.value = 0
    await Timer(1, "ns")
    assert 1 == dut.sum.value

@cocotb.test()
async def test_1_0_0(dut):
    await Timer(1, "ns")
    dut.a.value = 1
    dut.b.value = 0
    dut.cin.value = 0
    await Timer(1, "ns")
    assert 1 == dut.sum.value

@cocotb.test()
async def test_1_1_0(dut):
    await Timer(1, "ns")
    dut.a.value = 1
    dut.b.value = 1
    dut.cin.value = 0
    await Timer(1, "ns")
    assert 2 == dut.sum.value

@cocotb.test()
async def test_1_1_1(dut):
    await Timer(1, "ns")
    dut.a.value = 1
    dut.b.value = 1
    dut.cin.value = 1
    await Timer(1, "ns")
    assert 3 == dut.sum.value

@cocotb.test()
async def test_overflow0(dut):
    await Timer(1, "ns")
    dut.a.value = 0xFFFF_FFFF
    dut.b.value = 0
    dut.cin.value = 1
    await Timer(1, "ns")
    assert 0 == dut.sum.value

@cocotb.test()
async def test_overflow1(dut):
    await Timer(1, "ns")
    dut.a.value = 0xAAAA_AAAA # 1's in even positions
    dut.b.value = 0x5555_5555 # 1's in odd positions
    dut.cin.value = 1
    await Timer(1, "ns")
    assert 0 == dut.sum.value

@cocotb.test()
async def test_random1k(dut):
    for i in range(1000):
        await Timer(1, "ns")
        a = random.randrange(-(2**31),2**31)
        b = random.randrange(-(2**31),2**31)
        cin = random.randrange(0,2)
        dut.a.value = a
        dut.b.value = b
        dut.cin.value = cin
        await Timer(1, "ns")

        # truncate to 32b
        exp_sum = (a + b + cin) & 0x0000_FFFF_FFFF
        actual_sum = dut.sum.value.integer & 0x0000_FFFF_FFFF

        msg = f'expected {a} + {b} + {cin} = {exp_sum} but was {actual_sum}'
        assert exp_sum == actual_sum, msg
        pass
    pass
