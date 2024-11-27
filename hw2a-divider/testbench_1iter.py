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

    toplevel_module = "divu_1iter"
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

    results_file = runr.test(
        seed=12345,
        waves=True,
        hdl_toplevel=toplevel_module, 
        test_module=Path(__file__).stem, # use tests from this file
        testcase=pytestconfig.option.tests,
    )
    pass


if __name__ == "__main__":
    runCocotbTests()
    pass


#########################
## TEST CASES ARE HERE ##
#########################

@cocotb.test()
async def test_rem_lt_divisor(dut):
    await Timer(1, "ns")
    dut.i_dividend.value = 0x8000_0000
    dut.i_divisor.value = 2
    dut.i_remainder.value = 0
    dut.i_quotient.value = 8
    await Timer(1, "ns")
    assert 0 == dut.o_dividend.value
    assert 16 == dut.o_quotient.value
    assert 1 == dut.o_remainder.value
    pass

@cocotb.test()
async def test_rem_gte_divisor(dut):
    await Timer(1, "ns")
    dut.i_dividend.value = 0x8000_0000
    dut.i_divisor.value = 1
    dut.i_remainder.value = 0
    dut.i_quotient.value = 8
    await Timer(1, "ns")
    assert 0 == dut.o_dividend.value
    assert 16+1 == dut.o_quotient.value
    assert 0 == dut.o_remainder.value
    pass

@cocotb.test()
async def test_random1k(dut):
    for i in range(1000):
        await Timer(1, "ns")
        dividend = random.randrange(0,2**31)
        divisor = random.randrange(1,2**31) # NB: no divide-by-zero
        remainder = random.randrange(0,2**31)
        quotient = random.randrange(0,2**31)
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
