import cocotb, math, sys
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
                          size=0x2000)
    emptyCache(dut)

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

def emptyCache(dut):
    "initialize the cache with all zeroes"
    for i in range(dut.cache.NUM_SETS.value):
        dut.cache.data[i].value  = 0
        dut.cache.tag[i].value   = 0
        dut.cache.valid[i].value = 0
        dut.cache.dirty[i].value = 0
        pass
    pass

def makeConflictingAddr(dut, addr):
    block_offset_bits = math.log2(dut.cache.BLOCK_SIZE_BITS.value/8)
    index_bits = math.log2(dut.cache.NUM_SETS.value)
    return addr + (1 << int(block_offset_bits + index_bits))

#########################
## TEST CASES ARE HERE ##
#########################

@cocotb.test(timeout_time=TIMEOUT_NS, timeout_unit="ns")
async def testReadMiss(dut):
    "single read miss"
    axil_cache, axil_ram = await preTestSetup(dut)

    addr = 0x4
    expected_value = 0x1234_5678
    axil_ram.write_dword(addr, expected_value)

    cache_value = await axil_cache.read_dword(addr)

    assertEquals(expected_value, cache_value)

@cocotb.test(timeout_time=2*TIMEOUT_NS, timeout_unit="ns")
async def testReadMissHit(dut):
    "read miss, then hit"
    axil_cache, axil_ram = await preTestSetup(dut)

    addr = 0x4
    expected_value = 0x1234_5678
    axil_ram.write_dword(addr, expected_value)

    cache_value = await axil_cache.read_dword(addr)
    assertEquals(expected_value, cache_value)

    # ensure that hit is faster
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
    "write miss"
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
    "write miss, then read miss that triggers writeback"
    axil_cache, axil_ram = await preTestSetup(dut)

    addr = 0x4
    value0 = 0x1234_5678
    axil_ram.write_dword(addr, value0)

    # write miss, fill from memory and overwrite
    value1 = 0xB0BA_CAFE
    await axil_cache.write_dword(addr, value1)

    # conflicting read miss, triggers writeback
    conflicting_addr = makeConflictingAddr(dut, addr)
    await axil_cache.read_dword(conflicting_addr)

    # check that dirty value was written back to memory
    mem_value = axil_ram.read_dword(addr)

    assertEquals(value1, mem_value)

@cocotb.test(timeout_time=2*TIMEOUT_NS, timeout_unit="ns")
async def testWriteMissWriteback(dut):
    "write miss, then another write miss that triggers writeback"
    axil_cache, axil_ram = await preTestSetup(dut)

    addr = 0x4
    value0 = 0x1234_5678
    axil_ram.write_dword(addr, value0)

    # write miss, fill from memory and overwrite
    value1 = 0xB0BA_CAFE
    await axil_cache.write_dword(addr, value1)

    # conflicting write miss, triggers writeback
    conflicting_addr = makeConflictingAddr(dut, addr)
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
        dut._log.info(f"{value0+a:#x} == {actual:#x}")
        assertEquals((a * scale), actual)
        pass

@cocotb.test(timeout_time=2*TIMEOUT_NS, timeout_unit="ns")
async def testConsecutiveWriteMisses(dut):
    axil_cache, axil_ram = await preTestSetup(dut)

    addr = 0x4
    extent = 16
    scale = 0x0101_0101  

    writes = []
    for a in range(addr, addr + extent, 4):
        new_value = a * scale 
        writes.append(axil_cache.init_write(a, new_value.to_bytes(4, byteorder='little')))
        await ClockCycles(dut.ACLK, 1)

    for a in range(addr, addr + extent, 4):
        w = writes.pop(0)
        await w.wait()

    for a in range(addr, addr + extent, 4):
        r = axil_cache.init_read(a, 4)
        await ClockCycles(dut.ACLK, 1)
        await r.wait()
        mem_value = int.from_bytes(r.data.data, byteorder='little')

        dut._log.info(f"Checking cache at {a:#x}: Expected {a * scale:#x}, Got {mem_value:#x}")
        assertEquals(a * scale, mem_value)


@cocotb.test(timeout_time=4*TIMEOUT_NS, timeout_unit="ns")
async def testConsecutiveWriteMissesWriteBack(dut):
    "consecutive write misses, then conflicting write misses that trigger writebacks"
    axil_cache, axil_ram = await preTestSetup(dut)

    addr = 0x4
    step = int(dut.cache.BLOCK_SIZE_BITS.value / 8)
    scale = 0x0101_0101

    written_data = {}

    # init RAM
    for i in range(4):
        dut._log.warning(f'JLD {addr + i * step}')
        axil_ram.write_dword(addr + i * step, 0xDEADBEEF) 
    
    # write operation to cache, overwrite happens, dirty cache line
    for i in range(4):
        value = (i + 1) * scale
        written_data[addr + i * step] = value

        dut._log.warning(f"Write miss {i+1}: Writing {value:#x} to {(addr + i * step):#x}")
        await axil_cache.write_dword(addr + i * step, value)
        await ClockCycles(dut.ACLK, 1)

    # write again, same index but different tag, to force a writeback 
    for i in range(4):
        confict_addr = makeConflictingAddr(dut, addr + i * step)
        await axil_cache.write_dword(confict_addr, 0xB0BA_CAFE)
        await ClockCycles(dut.ACLK, 1)

    for addr, expected_value in written_data.items():
        actual_value = axil_ram.read_dword(addr)
        dut._log.info(f"RAM[{addr:#x}] = {actual_value:#x}, expected {expected_value:#x}")
        assertEquals(expected_value, actual_value)

@cocotb.test(timeout_time=4*TIMEOUT_NS, timeout_unit="ns")
async def testConsecutiveReadMissesWriteBack(dut):
    "consecutive write misses, then conflicting read misses that trigger writebacks"
    axil_cache, axil_ram = await preTestSetup(dut)

    addr = 0x4
    step = int(dut.cache.BLOCK_SIZE_BITS.value / 8)
    scale = 0x0101_0101

    written_data = {}

    for i in range(4):
        axil_ram.write_dword(addr + i * step, 0xDEADBEEF)

    for i in range(4):
        value = (i + 1) * scale
        written_data[addr + i * step] = value

        dut._log.info(f"Write {i+1}: Writing {value:#x} to {addr + i * step:#x}")
        await axil_cache.write_dword(addr + i * step, value)
        await ClockCycles(dut.ACLK, 1)

    # READ again, same index but different tag, still write miss and have write back here! 
    for i in range(4):
        conflict_addr = makeConflictingAddr(dut, addr + i*step) #addr + 0x100 + i * step  
        await axil_cache.read_dword(conflict_addr)
        await ClockCycles(dut.ACLK, 1)

    for a, expected_value in written_data.items():
        actual_value = axil_ram.read_dword(a)
        dut._log.warning(f"RAM[{a:#x}] = {actual_value:#x}, expected {expected_value:#x}")
        assertEquals(expected_value, actual_value)
