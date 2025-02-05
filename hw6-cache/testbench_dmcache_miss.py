import cocotb, sys
from pathlib import Path

from cocotb.clock import Clock
from cocotb.triggers import RisingEdge, ClockCycles
from cocotbext.axi import AxiLiteBus, AxiLiteMaster, AxiLiteRam
from cocotb.utils import get_sim_time

p = Path.cwd() / '..' / 'common' / 'python'
sys.path.append(str(p))
from cocotb_utils import assertEquals

TIMEOUT_NS = 50
CLOCK_PERIOD_NS = 2

BYTEORDER = 'little' # little-endian

async def preTestSetup(dut):
    """Setup the DUT. MUST be called at the start of EACH test."""
    # Create a clock on port clk
    clock = Clock(dut.ACLK, CLOCK_PERIOD_NS, units="ns")
    # Start the clock. Start it low to avoid issues on the first RisingEdge
    cocotb.start_soon(clock.start(start_high=False))

    axil_cache = AxiLiteMaster(AxiLiteBus.from_prefix(dut, "CACHE"), 
                               dut.ACLK, 
                               dut.ARESETn, 
                               reset_active_level=False)
    axil_ram = AxiLiteRam(AxiLiteBus.from_prefix(dut, "MEM"), 
                          dut.ACLK, 
                          dut.ARESETn, 
                          reset_active_level=False, 
                          size=32)

    dut.ARESETn.value = 0
    # wait for first rising edge
    await RisingEdge(dut.ACLK)

    # enter reset, note that it's active-low
    dut.ARESETn.value = 0
    await ClockCycles(dut.ACLK, 2)
    
    # leave reset
    dut.ARESETn.value = 1
    await ClockCycles(dut.ACLK, 1)

    return (axil_cache, axil_ram)
    

#########################
## TEST CASES ARE HERE ##
#########################

@cocotb.test(timeout_time=TIMEOUT_NS, timeout_unit="ns")
async def testReadMiss(dut):
    axil_cache, axil_ram = await preTestSetup(dut)

    addr = 0x4
    expected_value = 0x1234_5678
    axil_ram.write_dword(addr, expected_value)

    cache_value = await axil_cache.read_dword(addr)

    assertEquals(expected_value, cache_value)

@cocotb.test(timeout_time=2*TIMEOUT_NS, timeout_unit="ns")
async def testReadMissHit(dut):
    axil_cache, axil_ram = await preTestSetup(dut)

    addr = 0x4
    expected_value = 0x1234_5678
    axil_ram.write_dword(addr, expected_value)

    cache_value = await axil_cache.read_dword(addr)
    assertEquals(expected_value, cache_value)

    # cache_value = await axil_cache.read_dword(addr)
    r = axil_cache.init_read(addr, 4)
    await ClockCycles(dut.ACLK, 1)
    start_ns = get_sim_time()
    await r.wait()
    actual = int.from_bytes(r.data.data, byteorder='little')
    assertEquals(expected_value, actual)
    elapsed_ns = get_sim_time() - start_ns
    assertEquals(2*CLOCK_PERIOD_NS, elapsed_ns)

@cocotb.test(timeout_time=TIMEOUT_NS, timeout_unit="ns")
async def testWriteMiss(dut):
    axil_cache, axil_ram = await preTestSetup(dut)

    addr = 0x4
    value0 = 0x1234_5678
    axil_ram.write_dword(addr, value0)

    # cache miss, fill the value from memory, then overwrite 1 byte
    await axil_cache.write_byte(addr, 0xFF)
    cache_value = await axil_cache.read_dword(addr)

    assertEquals(0x1234_56FF, cache_value)

@cocotb.test(timeout_time=2*TIMEOUT_NS, timeout_unit="ns")
async def testReadMissWriteback(dut):
    axil_cache, axil_ram = await preTestSetup(dut)

    addr = 0x4
    value0 = 0x1234_5678
    axil_ram.write_dword(addr, value0)

    # write miss, fill from memory and overwrite
    value1 = 0xB0BA_CAFE
    await axil_cache.write_dword(addr, value1)

    # conflicting read miss, triggers writeback
    conflicting_addr = 0x14
    await axil_cache.read_dword(conflicting_addr)

    # check that dirty value was written back to memory
    mem_value = axil_ram.read_dword(addr)

    assertEquals(value1, mem_value)

@cocotb.test(timeout_time=2*TIMEOUT_NS, timeout_unit="ns")
async def testWriteMissWriteback(dut):
    axil_cache, axil_ram = await preTestSetup(dut)

    addr = 0x4
    value0 = 0x1234_5678
    axil_ram.write_dword(addr, value0)

    # write miss, fill from memory and overwrite
    value1 = 0xB0BA_CAFE
    await axil_cache.write_dword(addr, value1)

    # conflicting write miss, triggers writeback
    conflicting_addr = 0x14
    await axil_cache.write_dword(conflicting_addr, 0xBAAD_C0DE)

    # check that dirty value was written back to memory
    mem_value = axil_ram.read_dword(addr)

    assertEquals(value1, mem_value)

@cocotb.test(timeout_time=2*TIMEOUT_NS, timeout_unit="ns")
async def testConsecutiveReadMisses(dut):
    axil_cache, axil_ram = await preTestSetup(dut)

    addr = 0x4
    value0 = 0x1234_5678
    extent = 16
    scale = 0x0101_0101

    for a in range(addr,addr+extent,4):
        axil_ram.write_dword(a, a * scale)
        pass

    reads = []
    for a in range(addr,addr+extent,4):
        reads.append(axil_cache.init_read(a, 4))
        await ClockCycles(dut.ACLK, 1)
        pass
    for a in range(addr,addr+extent,4):
        r = reads.pop(0)
        await r.wait()
        actual = int.from_bytes(r.data.data, byteorder='little')
        dut._log.warning(f"{value0+a:#x} == {actual:#x}")
        assertEquals((a * scale), actual)
        pass

# TODO: test consecutive writes
