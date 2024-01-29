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

    toplevel_module = "gp4"
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
    pass


if __name__ == "__main__":
    runCocotbTests()
    pass


#########################
## TEST CASES ARE HERE ##
#########################

@cocotb.test()
async def test_zeroes(dut):
    await Timer(1, "ns")
    dut.gin.value = 0x0
    dut.pin.value = 0x0
    dut.cin.value = 0
    await Timer(1, "ns")
    assert 0 == dut.gout.value
    assert 0 == dut.pout.value
    assert 0x0 == dut.cout.value
    pass

@cocotb.test()
async def test_msb_generate(dut):
    await Timer(1, "ns")
    dut.gin.value = 0x8
    dut.pin.value = 0x0
    dut.cin.value = 0x0
    await Timer(1, "ns")
    assert 1 == dut.gout.value
    assert 0 == dut.pout.value
    assert 0x0 == dut.cout.value
    pass

@cocotb.test()
async def test_propagate_full(dut):
    await Timer(1, "ns")
    dut.gin.value = 0x0
    dut.pin.value = 0xF
    dut.cin.value = 1
    await Timer(1, "ns")
    assert 0 == dut.gout.value
    assert 1 == dut.pout.value
    assert 0x7 == dut.cout.value
    pass

@cocotb.test()
async def test_propagate_partway(dut):
    await Timer(1, "ns")
    dut.gin.value = 0x0
    dut.pin.value = 0x7
    dut.cin.value = 1
    await Timer(1, "ns")
    assert 0 == dut.gout.value
    assert 0 == dut.pout.value
    assert 0x7 == dut.cout.value
    pass

@cocotb.test()
async def test_propagate_full_nocarry(dut):
    await Timer(1, "ns")
    dut.gin.value = 0x0
    dut.pin.value = 0xF
    dut.cin.value = 0
    await Timer(1, "ns")
    assert 0 == dut.gout.value
    assert 1 == dut.pout.value
    assert 0x0 == dut.cout.value
    pass

@cocotb.test()
async def test_propagate_and_propagate(dut):
    await Timer(1, "ns")
    dut.gin.value = 0xF
    dut.pin.value = 0xF
    dut.cin.value = 1
    await Timer(1, "ns")
    assert 1 == dut.gout.value
    assert 1 == dut.pout.value
    assert 0x7 == dut.cout.value
    pass

