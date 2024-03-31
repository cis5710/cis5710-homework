import cocotb, json, os, random

from pathlib import Path
from cocotb.runner import get_runner, get_results
from cocotb.clock import Clock
from cocotb.triggers import RisingEdge, ClockCycles
from cocotb_bus.drivers.amba import AXI4LiteMaster

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
    verilog_sources = [proj_path / "DatapathAxilMemory.sv" ]
    toplevel_module = "MemAxiLiteTester"

    runr = get_runner(sim)
    runr.build(
        verilog_sources=verilog_sources,
        vhdl_sources=[],
        hdl_toplevel=toplevel_module,
        # TODO: remove this later
        #parameters={'NUM_BLOCKS':4, 'BLOCK_SIZE_BYTES': 8},
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
        results_xml='axilmem.results.xml',
        testcase=pytestconfig.option.tests,
    )

class AXI4LiteManager(AXI4LiteMaster):
    def __init__(self, entity, name, clock, **kwargs):
        super().__init__(entity, name, clock, **kwargs)
        pass


async def preTestSetup(dut):
    """Setup the DUT. MUST be called at the start of EACH test."""
    # Create a 2ns period clock on port clk
    clock = Clock(dut.ACLK, 2, units="ns")
    # Start the clock. Start it low to avoid issues on the first RisingEdge
    cocotb.start_soon(clock.start(start_high=False))

    # NB: cocotb_bus's initialization doesn't work
    # possibly related to https://github.com/cocotb/cocotb-bus/issues/51
    dut.I_ARADDR.value = 0
    dut.I_ARVALID.value = 0
    dut.I_RREADY.value = 1
    # intentionally skip I_* write interface signals
    dut.D_ARADDR.value = 0
    dut.D_ARVALID.value = 0
    dut.D_RREADY.value = 1

    dut.D_AWADDR.value = 0
    dut.D_WSTRB.value = 0
    dut.D_WDATA.value = 0
    dut.D_AWVALID.value = 0
    dut.D_WVALID.value = 0
    dut.D_BREADY.value = 1

    # wait for first rising edge
    await RisingEdge(dut.ACLK)

    # enter reset, note that it's active-low
    dut.ARESETn.value = 0
    await ClockCycles(dut.ACLK, 2)
    # leave reset
    dut.ARESETn.value = 1
    # design should be reset now
    return

if __name__ == "__main__":
    runCocotbTests()
    pass


TIMEOUT_NS = 40

#########################
## TEST CASES ARE HERE ##
#########################

# test that the imem has appropriate initial outputs
async def testInsnInit(dut):
    await preTestSetup(dut)
    assert 1 == dut.I_ARREADY.value, "imem ARREADY should initially be ready to read"
    assert 0 == dut.I_RVALID.value, "imem RVALID should initially be invalid"

# test one read of imem
@cocotb.test(timeout_time=TIMEOUT_NS, timeout_unit="ns")
async def testInsnRead(dut):
    await preTestSetup(dut)

    # initialize memory with some data
    addr4 = 0x1234_5678
    dut.mem.mem_array[1].value = addr4

    imem = AXI4LiteManager(dut, "I", dut.ACLK)

    # read the data back
    value = await imem.read(0x4)
    assert value == addr4

# test multiple reads of imem
@cocotb.test(timeout_time=TIMEOUT_NS * 15, timeout_unit="ns")
async def testInsnMultiRead(dut):
    await preTestSetup(dut)

    def hexRepeat(x):
        assert x >= 0 and x <= 15
        return int(("%x" % x) * 8, 16)

    # initialize memory with some data
    for i in range(1,15):
        dut.mem.mem_array[i].value = hexRepeat(i)
        pass

    imem = AXI4LiteManager(dut, "I", dut.ACLK)

    # read the data back
    for i in range(1,15):
        value = await imem.read(i*4)
        assert hexRepeat(i) == value, f'error reading address 0x{i*4:x}, expected value 0x{expected:x} but was 0x{actual:x}'
        pass

# test that imem does not accept writes
@cocotb.test(timeout_time=TIMEOUT_NS, timeout_unit="ns", expect_error=cocotb.result.SimTimeoutError)
async def testInsnWriteTimeout(dut):
    await preTestSetup(dut)

    magic = 0x1234_5678
    imem = AXI4LiteManager(dut, "I", dut.ACLK)

    # a write to imem should never be accepted, i.e. AWREADY is never 1, so this times out
    await imem.write(0x4, magic)

    # this assert should be unreachable, but just in case, check that the write didn't happen
    assert magic != dut.mem.mem_array[1].value

async def insn_read_helper(dut, address, expected):
    dut.I_ARVALID.value = 1
    dut.I_ARADDR.value = address
    assert 1 == dut.I_ARREADY # memory will accept read
    await RisingEdge(dut.ACLK) # memory accepts read at this edge
    # memory works on read here
    await RisingEdge(dut.ACLK)
    # memory output available here

    assert 1 == dut.I_RVALID.value
    assert expected == dut.I_RDATA.value

# test that imem supports reads in consecutive cycles
@cocotb.test(timeout_time=TIMEOUT_NS, timeout_unit="ns")
async def testInsnReadConsecutive(dut):
    await preTestSetup(dut)

    # initialize memory with some data
    expected = [
        0x99c0ffee,
        0x1bad1dea,
        0x1b0ba7ea,
        0xab1ec0de,
        ]
    for i in range(len(expected)):
        dut.mem.mem_array[i+1].value = expected[i]
        pass
    
    for i in range(len(expected)):
        cocotb.start_soon(insn_read_helper(dut, (i+1)*4, expected[i]))
        await RisingEdge(dut.ACLK)
        pass
    # so we can see the last cycle more easily in the waveforms
    await RisingEdge(dut.ACLK)


# test one read of dmem 
@cocotb.test(timeout_time=TIMEOUT_NS, timeout_unit="ns")
async def testDataRead(dut):
    await preTestSetup(dut)

    # initialize memory with some data
    addr4 = 0x1234_5678
    dut.mem.mem_array[1].value = addr4

    dmem = AXI4LiteManager(dut, "D", dut.ACLK)

    # read the data back
    value = await dmem.read(0x4)
    assert value == addr4

# test multiple reads of dmem
@cocotb.test(timeout_time=TIMEOUT_NS * 15, timeout_unit="ns")
async def testDataMultiRead(dut):
    await preTestSetup(dut)

    def hexRepeat(x):
        assert x >= 0 and x <= 15
        return int(("%x" % x) * 8, 16)

    # initialize memory with some data
    for i in range(1,15):
        dut.mem.mem_array[i].value = hexRepeat(i)
        pass

    dmem = AXI4LiteManager(dut, "D", dut.ACLK)

    # read the data back
    for i in range(1,15):
        actual = await dmem.read(i*4)
        expected = hexRepeat(i)
        assert expected == actual, f'error reading address 0x{i*4:x}, expected value 0x{expected:x} but was 0x{actual:x}'
        pass

# test write+read to dmem
@cocotb.test(timeout_time=TIMEOUT_NS, timeout_unit="ns")
async def testDataWriteRead(dut):
    await preTestSetup(dut)

    dmem = AXI4LiteManager(dut, "D", dut.ACLK)

    # write to memory
    addr4 = 0x1234_5678
    await dmem.write(0x4, addr4)

    # read the data back
    value = await dmem.read(0x4)
    assert addr4 == value

# test multiple writes+reads to dmem
@cocotb.test(timeout_time=TIMEOUT_NS * 15, timeout_unit="ns")
async def testDataMultiWriteRead(dut):
    await preTestSetup(dut)

    def hexRepeat(x):
        assert x >= 0 and x <= 15
        return int(("%x" % x) * 8, 16)
    
    dmem = AXI4LiteManager(dut, "D", dut.ACLK)

    # write values to memory
    for i in range(1,15):
        await dmem.write(i*4, hexRepeat(i))
        pass

    # read the data back
    for i in range(1,15):
        actual = await dmem.read(i*4)
        expected = hexRepeat(i)
        assert expected == actual, f'error reading address 0x{i*4:x}, expected value 0x{expected:x} but was 0x{actual:x}'
        pass

async def data_read_helper(dut, address, expected):
    dut.D_ARVALID.value = 1
    dut.D_ARADDR.value = address
    assert 1 == dut.D_ARREADY # memory will accept read
    await RisingEdge(dut.ACLK) # memory accepts read at this edge
    # memory works on read here
    await RisingEdge(dut.ACLK)
    # memory output available here

    assert 1 == dut.D_RVALID.value
    assert expected == dut.D_RDATA.value

# test that dmem supports reads in consecutive cycles
@cocotb.test(timeout_time=TIMEOUT_NS, timeout_unit="ns")
async def testDataReadConsecutive(dut):
    await preTestSetup(dut)

    # initialize memory with some data
    expected = [
        0x99c0ffee,
        0x1bad1dea,
        0x1b0ba7ea,
        0xab1ec0de,
        ]
    for i in range(len(expected)):
        dut.mem.mem_array[i+1].value = expected[i]
        pass
    
    for i in range(len(expected)):
        cocotb.start_soon(data_read_helper(dut, (i+1)*4, expected[i]))
        await RisingEdge(dut.ACLK)
        pass
    # so we can see the last cycle more easily in the waveforms
    await RisingEdge(dut.ACLK)

# test that we can read in parallel from imem and dmem
@cocotb.test(timeout_time=TIMEOUT_NS, timeout_unit="ns")
async def testInsnDataReadConsecutive(dut):
    await preTestSetup(dut)

    # initialize memory with some data
    expected = [
        0x99c0ffee,
        0x1bad1dea,
        0x1b0ba7ea,
        0xab1ec0de,
        ]
    for i in range(len(expected)):
        dut.mem.mem_array[i+1].value = expected[i]
        pass
    
    for i in range(len(expected)):
        cocotb.start_soon(insn_read_helper(dut, (i+1)*4, expected[i]))
        
        # read dmem in reverse order
        data_i = (len(expected)-1) - i
        cocotb.start_soon(data_read_helper(dut, (data_i+1)*4, expected[data_i]))

        await RisingEdge(dut.ACLK)
        pass
    # so we can see the last cycle more easily in the waveforms
    await RisingEdge(dut.ACLK)

async def data_write_helper(dut, address, value):
    dut.D_AWVALID.value = 1
    dut.D_AWADDR.value = address
    dut.D_WDATA.value = value
    dut.D_WVALID.value = 1
    dut.D_WSTRB.value = 0xF
    assert 1 == dut.D_AWREADY # memory will accept write address
    assert 1 == dut.D_WREADY # memory will accept write data
    await RisingEdge(dut.ACLK) # memory accepts write at this edge
    # memory works on write during this cycle
    await RisingEdge(dut.ACLK)
    # write response available here

    assert 1 == dut.D_BVALID.value
    assert 0 == dut.D_BRESP.value
    assert value == dut.mem.mem_array[int(address/4)].value

# test that dmem supports writes in consecutive cycles
@cocotb.test(timeout_time=TIMEOUT_NS, timeout_unit="ns")
async def testDataWriteConsecutive(dut):
    await preTestSetup(dut)

    # initialize memory with some data
    values = [
        0x99c0ffee,
        0x1bad1dea,
        0x1b0ba7ea,
        0xab1ec0de,
        ]
    
    for i in range(len(values)):
        cocotb.start_soon(data_write_helper(dut, (i+1)*4, values[i]))
        await RisingEdge(dut.ACLK)
        pass
    # so we can see the last cycle more easily in the waveforms
    await RisingEdge(dut.ACLK)

# Test consecutive write+read to dmem. Also tests that a read and a write (to different addresses)
# can occur in parallel.
@cocotb.test(timeout_time=TIMEOUT_NS, timeout_unit="ns")
async def testDataWriteReadConsecutive(dut):
    await preTestSetup(dut)

    # initialize memory with some data
    values = [
        0x99c0ffee,
        0x1bad1dea,
        0x1b0ba7ea,
        0xab1ec0de,
        ]
    
    for i in range(len(values)):
        cocotb.start_soon(data_write_helper(dut, (i+1)*4, values[i]))
        await RisingEdge(dut.ACLK)
        cocotb.start_soon(data_read_helper(dut, (i+1)*4, values[i]))
        pass
    # so we can see the last cycle more easily in the waveforms
    await RisingEdge(dut.ACLK)
