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
    verilog_sources = [proj_path / "divider_unsigned.sv" ]
    toplevel_module = "divider_unsigned"

    pointsEarned = 0
    pointsPossible = 0
    try:
        runr = get_runner(sim)
        runr.build(
            verilog_sources=verilog_sources,
            vhdl_sources=[],
            hdl_toplevel=toplevel_module,
            includes=[proj_path],
            build_dir=SIM_BUILD_DIR,
            always=True, # always build the code
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
async def test_simple0(dut):
    await Timer(1, "ns")
    dut.i_dividend.value = 4
    dut.i_divisor.value = 2
    await Timer(1, "ns")
    assert 2 == dut.o_quotient.value
    assert 0 == dut.o_remainder.value

@cocotb.test()
async def test_simple1(dut):
    await Timer(1, "ns")
    dut.i_dividend.value = 4
    dut.i_divisor.value = 4
    await Timer(1, "ns")
    assert 1 == dut.o_quotient.value
    assert 0 == dut.o_remainder.value

@cocotb.test()
async def test_simple2(dut):
    await Timer(1, "ns")
    dut.i_dividend.value = 10
    dut.i_divisor.value = 4
    await Timer(1, "ns")
    assert 2 == dut.o_quotient.value
    assert 2 == dut.o_remainder.value

@cocotb.test()
async def test_simple3(dut):
    await Timer(1, "ns")
    dut.i_dividend.value = 2
    dut.i_divisor.value = 4
    await Timer(1, "ns")
    assert 0 == dut.o_quotient.value
    assert 2 == dut.o_remainder.value

@cocotb.test()
async def test_random1k(dut):
    for i in range(1000):
        await Timer(1, "ns")
        dividend = random.randrange(0,2**32)
        divisor = random.randrange(1,2**32) # NB: no divide-by-zero
        dut.i_dividend.value = dividend
        dut.i_divisor.value = divisor
        await Timer(1, "ns")

        exp_quotient = int(dividend / divisor)
        exp_remainder = dividend % divisor

        msg = f'expected {dividend} / {divisor} = {exp_quotient} rem {exp_remainder}\n'
        msg += f'but was quot={dut.o_quotient.value} rem={dut.o_remainder.value}'
        assert exp_quotient == dut.o_quotient.value, msg
        assert exp_remainder == dut.o_remainder.value, msg
        pass
    pass
