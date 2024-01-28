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

    # by default, run all tests
    all_tests = ["divider_unsigned", "divu_1iter"]
    tests_to_run = all_tests

    if pytestconfig.option.tests != "":
        tests_to_run = []
        # filter the tests to run
        tests_requested = pytestconfig.option.tests.split(",")
        for tr in tests_requested:
            assert tr in all_tests, f'Invalid test "{tr}" requested, expecting a comma-separated list from {all_tests}'
            tests_to_run.append(tr)
            pass
        pass

    pointsEarned = 0
    try:
        for top_module in tests_to_run:
            runr = get_runner(sim)
            runr.build(
                verilog_sources=verilog_sources,
                vhdl_sources=[],
                hdl_toplevel=top_module,
                includes=[proj_path],
                build_dir=SIM_BUILD_DIR,
                always=True,
                build_args=['--assert','-Wall','-Wno-DECLFILENAME','--trace','--trace-fst','--trace-structs']
            ),

            results_file = runr.test(
                seed=12345,
                waves=True,
                hdl_toplevel=top_module, 
                test_module="testbench",
                testcase="test_"+top_module,
            )
            total_failed = get_results(results_file)
            # 1 point per test
            pointsEarned += total_failed[0] - total_failed[1]
            pass
    finally:
        points = { 'pointsEarned': pointsEarned, 'pointsPossible': len(all_tests) }
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
async def test_divider_unsigned(dut):
    for i in range(100):
        await Timer(1, "ns")
        dividend = random.randint(0,2**32)
        divisor = random.randint(1,2**32) # NB: no divide-by-zero
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


@cocotb.test()
async def test_divu_1iter(dut):
    for i in range(100):
        await Timer(1, "ns")
        dividend = random.randint(0,2**31)
        divisor = random.randint(1,2**31) # NB: no divide-by-zero
        remainder = random.randint(0,2**31)
        quotient = random.randint(0,2**31)
        dut.i_dividend.value = dividend
        dut.i_divisor.value = divisor
        dut.i_remainder.value = remainder
        dut.i_quotient.value = quotient
        await Timer(1, "ns")

        # compute expected values
        exp_remainder = (remainder << 1) | ((dividend >> 31) & 0x1)
        exp_quotient = quotient << 1
        if exp_remainder >= divisor:
            exp_quotient = (quotient << 1) | 0x1
            exp_remainder = exp_remainder - divisor
            pass
        exp_dividend = dividend << 1

        # check against actual values
        msg = f'input {dividend} / {divisor} rem={remainder} quotient={quotient}\n'
        msg += f'expected dividend={exp_dividend} quot={exp_quotient} rem={exp_remainder}\n'
        msg += f'but was dividend={dut.o_dividend.value} quot={dut.o_quotient.value} rem={dut.o_remainder.value}'
        assert exp_dividend == dut.o_dividend.value, msg
        assert exp_quotient == dut.o_quotient.value, msg
        assert exp_remainder == dut.o_remainder.value, msg
        pass
    pass
