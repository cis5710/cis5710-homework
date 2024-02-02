import cocotb, os, random

from pathlib import Path
from cocotb.runner import get_runner
from cocotb.clock import Clock
from cocotb.triggers import RisingEdge, FallingEdge, ClockCycles

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
    verilog_sources = [proj_path / "DatapathSingleCycle.sv" ]

    toplevel_module = "RegFile"
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

async def preTestSetup(dut):
    """Setup the DUT. MUST be called at the start of EACH test."""
    # Create a 2ns period clock on port clk
    clock = Clock(dut.clk, 2, units="ns")
    # Start the clock. Start it low to avoid issues on the first RisingEdge
    cocotb.start_soon(clock.start(start_high=False))
    # wait for first rising edge
    await RisingEdge(dut.clk)

    # raise `rst` signal for 2 cycles
    dut.rst.value = 1
    await ClockCycles(dut.clk, 2)
    # lower `rst` signal
    dut.rst.value = 0
    # design should be reset now
    return

if __name__ == "__main__":
    runCocotbTests()
    pass


#########################
## TEST CASES ARE HERE ##
#########################

@cocotb.test()
async def readx0(dut):
    "test that we can read 0 from x0"
    await preTestSetup(dut)

    dut.rs1.value = 0x0
    await FallingEdge(dut.clk)
    assert 0 == dut.rs1_data.value
    pass

@cocotb.test()
async def writeReadx0(dut):
    "writes to x0 should be discarded"
    await preTestSetup(dut)

    dut.rd.value = 0
    dut.rd_data.value = 0x1234_5678
    dut.we.value = 1
    await ClockCycles(dut.clk, 1)
    dut.we.value = 0
    dut.rs1.value = 0
    await FallingEdge(dut.clk)
    assert 0 == dut.rs1_data
    pass

@cocotb.test()
async def writeReadx1(dut):
    "test that we can write and then read x1"
    await preTestSetup(dut)

    dut.rd.value = 1
    dut.rd_data.value = 0x1234_5678
    dut.we.value = 1
    await ClockCycles(dut.clk, 1)
    dut.we.value = 0
    dut.rs1.value = 1
    await FallingEdge(dut.clk)
    assert 0x1234_5678 == dut.rs1_data
    pass

@cocotb.test()
async def checkIndividual(dut):
    "for each register, write and read back the written value"
    await preTestSetup(dut)

    for regnum in range(1,32):
        # initial value should be zero
        dut.rs1.value = regnum
        dut.rs2.value = regnum
        await FallingEdge(dut.clk)
        assert 0 == dut.rs1_data
        assert 0 == dut.rs2_data

        # write a random value, read it back
        value = random.randrange(2**32)
        dut.rd.value = regnum
        dut.rd_data.value = value
        dut.we.value = 1
        await ClockCycles(dut.clk, 1)
        dut.we.value = 0
        dut.rs1.value = regnum
        dut.rs2.value = regnum
        await FallingEdge(dut.clk)
        assert value == dut.rs1_data
        assert value == dut.rs2_data
        pass

@cocotb.test()
async def checkBatch(dut):
    "write to all registers, then read all the values back"
    await preTestSetup(dut)

    values = {}
    values[0] = 0

    for regnum in range(1,32):
        # write a random value, read it back
        value = random.randrange(2**32)
        values[regnum] = value
        dut.rd.value = regnum
        dut.rd_data.value = value
        dut.we.value = 1
        await ClockCycles(dut.clk, 1)
        pass

    dut.we.value = 0
    for regnum1 in range(32):
        for regnum2 in range(32):
            dut.rs1.value = regnum1
            dut.rs2.value = regnum2
            await FallingEdge(dut.clk)
            assert values[regnum1] == dut.rs1_data
            assert values[regnum2] == dut.rs2_data
            pass
        pass
    pass
