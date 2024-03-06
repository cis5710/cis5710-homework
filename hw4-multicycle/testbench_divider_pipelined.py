import cocotb, json, os, random

from pathlib import Path
from cocotb.runner import get_runner, get_results
from cocotb.clock import Clock
from cocotb.triggers import RisingEdge, ClockCycles

# directory where our simulator will compile our tests + code
SIM_BUILD_DIR = "sim_build"

DIVIDER_STAGES = 2

def runCocotbTests(pytestconfig):
    """setup cocotb tests, based on https://docs.cocotb.org/en/stable/runner.html"""

    # for deterministic random numbers
    random.seed(12345)

    hdl_toplevel_lang = os.getenv("HDL_TOPLEVEL_LANG", "verilog")
    sim = os.getenv("SIM", "verilator")
    proj_path = Path(__file__).resolve().parent
    assert hdl_toplevel_lang == "verilog"
    verilog_sources = [proj_path / "divider_unsigned_pipelined.sv" ]
    toplevel_module = "divider_unsigned_pipelined"

    runr = get_runner(sim)
    runr.build(
        verilog_sources=verilog_sources,
        vhdl_sources=[],
        hdl_toplevel=toplevel_module,
        #parameters={'STAGES':DIVIDER_STAGES},
        includes=[proj_path],
        build_dir=SIM_BUILD_DIR,
        always=True, # always build the code
        build_args=['--assert','-Wall','-Wno-DECLFILENAME',
                    '--trace','--trace-fst','--trace-structs','--trace-max-array',str(2**18),
                    '--coverage']
    ),

    runr.test(
        seed=12345,
        waves=True,
        hdl_toplevel=toplevel_module,
        test_module=Path(__file__).stem, # use tests from this file
        results_xml='divider_pipelined.results.xml',
        testcase=pytestconfig.option.tests,
    )

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
async def test0(dut):
    await preTestSetup(dut)
    dut.i_dividend.value = 4
    dut.i_divisor.value = 2

    await ClockCycles(dut.clk, DIVIDER_STAGES)
    assert 2 == dut.o_quotient.value
    assert 0 == dut.o_remainder.value

@cocotb.test()
async def test1(dut):
    await preTestSetup(dut)
    dut.i_dividend.value = 12
    dut.i_divisor.value = 3

    await ClockCycles(dut.clk, DIVIDER_STAGES)
    assert 4 == dut.o_quotient.value
    assert 0 == dut.o_remainder.value

@cocotb.test()
async def test_2consecutive(dut):
    await preTestSetup(dut)
    dut.i_dividend.value = 4
    dut.i_divisor.value = 2
    await ClockCycles(dut.clk, 1)
    dut.i_dividend.value = 12
    dut.i_divisor.value = 3

    await ClockCycles(dut.clk, DIVIDER_STAGES-1)
    assert 2 == dut.o_quotient.value
    assert 0 == dut.o_remainder.value
    await ClockCycles(dut.clk, 1)
    assert 4 == dut.o_quotient.value
    assert 0 == dut.o_remainder.value

# Test helper that launches a new division every `stages` cycles, and expects
# each quotient/remainder `stages` cycles later.
async def test_divider(dut, trials, stages, even):
    MAX = 2**32
    for _ in range(trials):
        a = random.randrange(0,MAX)
        b = random.randrange(1,MAX) # no divide-by-zero
        if even: # dividend is always even
            a &= 0xFFFF_FFFE
        else: # dividend is always odd
            a |= 0x1
            pass
        dut.i_dividend.value = a
        dut.i_divisor.value = b
        await ClockCycles(dut.clk, stages)

        exp_quotient = int(a / b)
        exp_remainder = a % b

        msg = f'expected {a} / {b} = {exp_quotient} rem {exp_remainder}\n'
        msg += f'but was quot={dut.o_quotient.value.integer} rem={dut.o_remainder.value.integer}'
        assert exp_quotient == dut.o_quotient.value, msg
        assert exp_remainder == dut.o_remainder.value, msg
        pass
    pass

@cocotb.test()
async def test_kconsecutive(dut):
    await preTestSetup(dut)

    trials = 20
    cocotb.start_soon(test_divider(dut,trials,DIVIDER_STAGES,True))
    for _ in range(1,DIVIDER_STAGES):
        await ClockCycles(dut.clk, 1)
        await cocotb.start(test_divider(dut,trials,DIVIDER_STAGES,False))
        pass
    await ClockCycles(dut.clk, DIVIDER_STAGES * trials)
    pass