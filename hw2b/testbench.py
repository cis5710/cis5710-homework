import cocotb, json, os, random

from pathlib import Path
from cocotb.runner import get_runner, get_results
from cocotb.triggers import Timer

# directory where our simulator will compile our tests + code
SIM_BUILD_DIR = "sim_build"


def runCocotbTests(pytestconfig):
    """setup cocotb tests, based on https://docs.cocotb.org/en/stable/runner.html"""

    # for deterministic random numbers
    random.seed(12345)

    hdl_toplevel_lang = os.getenv("HDL_TOPLEVEL_LANG", "verilog")
    sim = os.getenv("SIM", "verilator")
    proj_path = Path(__file__).resolve().parent
    assert hdl_toplevel_lang == "verilog"
    verilog_sources = [proj_path / "cla.sv" ]
    toplevel_module = "cla"

    pointsEarned = 0
    try:
        runr = get_runner(sim)
        runr.build(
            verilog_sources=verilog_sources,
            vhdl_sources=[],
            hdl_toplevel=toplevel_module,
            includes=[proj_path],
            build_dir=SIM_BUILD_DIR,
            always=True,
            build_args=['--assert','-Wall','-Wno-DECLFILENAME','--trace','--trace-fst','--trace-structs']
        ),

        runr.test(
            seed=12345,
            waves=True,
            hdl_toplevel=toplevel_module, 
            test_module=Path(__file__).stem, # use tests from this file
            testcase=pytestconfig.option.tests,
        )
    finally:
        total_failed = get_results(Path(SIM_BUILD_DIR,'runCocotbTests.results.xml'))
        # 1 point per test
        pointsEarned += total_failed[0] - total_failed[1]
        pointsPossible = total_failed[0]     
        points = { 'pointsEarned': pointsEarned, 'pointsPossible': pointsPossible }
        with open('points.json', 'w') as f:
            json.dump(points, f, indent=2)
            pass
        pass


if __name__ == "__main__":
    runCocotbTests()
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
