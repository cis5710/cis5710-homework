import cocotb, sys
from pathlib import Path

from cocotb.clock import Clock
from cocotb.triggers import RisingEdge, ClockCycles
from cocotbext.axi import AxiLiteBus, AxiLiteMaster
from cocotb.utils import get_sim_time

p = Path.cwd() / '..' / 'common' / 'python'
sys.path.append(str(p))
from cocotb_utils import assertEquals

TIMEOUT_NS = 50
CLOCK_PERIOD_NS = 2

async def preTestSetup(dut, setupAxilCache=True):
    """Setup the DUT. MUST be called at the start of EACH test."""
    # Create a clock on port clk
    clock = Clock(dut.ACLK, CLOCK_PERIOD_NS, units="ns")
    # Start the clock. Start it low to avoid issues on the first RisingEdge
    cocotb.start_soon(clock.start(start_high=False))

    axil_cache = None
    if setupAxilCache:
        axil_cache = AxiLiteMaster(AxiLiteBus.from_prefix(dut, "CACHE"), 
                                dut.ACLK, 
                                dut.ARESETn, 
                                reset_active_level=False)
        pass

    dut.ARESETn.value = 0
    # wait for first rising edge
    await RisingEdge(dut.ACLK)

    # enter reset, note that it's active-low
    dut.ARESETn.value = 0
    await ClockCycles(dut.ACLK, 2)
    
    # leave reset
    dut.ARESETn.value = 1
    await ClockCycles(dut.ACLK, 1)

    return axil_cache
    

#########################
## TEST CASES ARE HERE ##
#########################

# NB: for these tests, cache contents are initialized with a fixed test pattern so that we can query the 
# cache without any misses (and the complexity of talking to a memory). See INIT_WITH_TEST_PATTERN in AxilCache.sv.

@cocotb.test(timeout_time=TIMEOUT_NS, timeout_unit="ns")
async def testRead(dut):
    axil_cache = await preTestSetup(dut)

    addr = 0
    expected_value = 0x1111_1111

    # read the data from the cache
    cache_value = await axil_cache.read_dword(addr)

    assertEquals(expected_value, cache_value, f'expected {expected_value:#x} but was {cache_value:#x}')

@cocotb.test(timeout_time=TIMEOUT_NS, timeout_unit="ns")
async def testReadMany(dut):
    axil_cache = await preTestSetup(dut)

    block_size_bytes = int(dut.BLOCK_SIZE_BITS.value / 8)
    base_value = 0x1111_1111
    for a in range(0, dut.BLOCKS_PER_WAY.value * block_size_bytes, block_size_bytes):
        cache_value = await axil_cache.read_dword(a)
        block_index = (a / 4) + 1
        expected_value = int(block_index * base_value)
        assertEquals(expected_value, cache_value, f'expected {expected_value:#x} but was {cache_value:#x}')
        pass

@cocotb.test(timeout_time=TIMEOUT_NS, timeout_unit="ns")
async def testWriteRead(dut):
    axil_cache = await preTestSetup(dut)

    addr = 0x4
    expected_value = 0x1234_5678

    # write to the cache
    await axil_cache.write_dword(addr, expected_value)
    # read it back
    cache_value = await axil_cache.read_dword(addr)

    # check that write occurred
    assertEquals(expected_value, cache_value, f'expected {expected_value:#x} but was {cache_value:#x}')

@cocotb.test(timeout_time=2*TIMEOUT_NS, timeout_unit="ns")
async def testConsecutiveReads(dut):
    axil_cache = await preTestSetup(dut)

    addr = 0x0
    extent = 16
    scale = 0x1111_1111

    reads = []
    # dut._log.warn(f'{get_sim_time()} ns @ before read requests')
    for a in range(addr,addr+extent,4):
        reads.append(axil_cache.init_read(a, 4))
        await ClockCycles(dut.ACLK, 1)
        pass
    start_nanos = get_sim_time()
    # dut._log.warn(f'{get_sim_time()} ns @ read requests done')
    for a in range(addr,addr+extent,4):
        r = reads.pop(0)
        await r.wait()
        expected = int(((a/4)+1) * scale)
        actual = int.from_bytes(r.data.data, byteorder='little')
        # dut._log.info(f"{expected:#x} == {actual:#x}")
        assertEquals(expected, actual)
        pass
    elapsed_nanos = get_sim_time() - start_nanos
    # dut._log.warn(f'{get_sim_time()} ns @ read responses done')
    # should be 2 cycles from when last read request is sent to when last read response arrives
    # 1st cycle is the last read request
    # 2nd cycle is the response to that last read request
    assertEquals(2*CLOCK_PERIOD_NS, elapsed_nanos, f'{elapsed_nanos} ns elapsed')

@cocotb.test(timeout_time=2*TIMEOUT_NS, timeout_unit="ns")
async def testConsecutiveWrites(dut):
    axil_cache = await preTestSetup(dut)

    addr = 0x0
    extent = 16
    base = 0x5555_5555
    scale = 0x1111_1111

    writes = []
    for a in range(addr,addr+extent,4):
        value_to_write = int(base + (scale * (a/4)))
        writes.append(axil_cache.init_write(a, value_to_write.to_bytes(4, byteorder='little')))
        await ClockCycles(dut.ACLK, 1)
        pass
    start_nanos = get_sim_time()
    for a in range(addr,addr+extent,4):
        w = writes.pop(0)
        await w.wait()
        # dut._log.warn(w.data.resp)
        assertEquals(0, w.data.resp)
        pass
    elapsed_nanos = get_sim_time() - start_nanos
    # should be 2 cycles from when last write request is sent to when last write response arrives
    # 1st cycle is the last write request
    # 2nd cycle is the response to that last write request
    assertEquals(2*CLOCK_PERIOD_NS, elapsed_nanos, f'{elapsed_nanos} ns elapsed')

    # check that writes occurred
    for a in range(addr,addr+extent,4):
        cache_value = await axil_cache.read_dword(a)
        expected_value = int(base + (scale * (a/4)))
        assertEquals(expected_value, cache_value, f'expected {expected_value:#x} but was {cache_value:#x}')
        pass

@cocotb.test(timeout_time=TIMEOUT_NS, timeout_unit="ns")
async def testLazyManager1(dut):
    "manager takes a long time to be ready for read response"
    await preTestSetup(dut, setupAxilCache=False)

    # send single read request
    dut.CACHE_ARVALID.value = 1
    dut.CACHE_ARADDR.value = 0x4
    # manager isn't ready for response
    dut.CACHE_RREADY.value = 0
    await ClockCycles(dut.ACLK, 1)
    dut.CACHE_ARVALID.value = 0
    dut.CACHE_ARADDR.value = 0

    await ClockCycles(dut.ACLK, 4)
    assertEquals(1, dut.CACHE_RVALID.value)
    assertEquals(0x2222_2222, dut.CACHE_RDATA.value)
    dut.CACHE_RREADY.value = 1
    await ClockCycles(dut.ACLK, 1)
    dut.CACHE_RREADY.value = 0
    await ClockCycles(dut.ACLK, 1)
    assertEquals(0, dut.CACHE_RVALID.value)

@cocotb.test(timeout_time=TIMEOUT_NS, timeout_unit="ns")
async def testLazyManager2(dut):
    "manager takes a long time to be ready for read response"
    await preTestSetup(dut, setupAxilCache=False)

    # send back-to-back read requests
    assertEquals(1, dut.CACHE_ARREADY.value)
    dut.CACHE_ARVALID.value = 1
    dut.CACHE_ARADDR.value = 0x4
    # manager isn't ready for response
    dut.CACHE_RREADY.value = 0
    await ClockCycles(dut.ACLK, 1)
    assertEquals(1, dut.CACHE_ARREADY.value)
    dut.CACHE_ARVALID.value = 1
    dut.CACHE_ARADDR.value = 0x8
    await ClockCycles(dut.ACLK, 1)
    dut.CACHE_ARVALID.value = 0
    dut.CACHE_ARADDR.value = 0

    await ClockCycles(dut.ACLK, 4)
    assertEquals(1, dut.CACHE_RVALID.value)
    assertEquals(0x2222_2222, dut.CACHE_RDATA.value)
    dut.CACHE_RREADY.value = 1
    await ClockCycles(dut.ACLK, 1)
    dut.CACHE_RREADY.value = 0
    await ClockCycles(dut.ACLK, 1)
    assertEquals(0, dut.CACHE_RVALID.value)
    assertEquals(1, dut.CACHE_ARREADY.value)
