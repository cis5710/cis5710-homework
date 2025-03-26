import cocotb, math, random, sys
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
    
def setCacheValue(dut, address, contents, dirty=False):
    dut._log.info(f'setCacheValue() {address=:#x} <= {contents:#x}')
    tag_index = address >> int(math.log2(dut.cache.BLOCK_SIZE_BITS.value/8))
    index = tag_index % dut.cache.NUM_SETS.value
    dut.cache.data[index].value = contents & 0x0000_FFFF_FFFF
    dut.cache.tag[index].value = tag_index >> int(math.log2(dut.cache.NUM_SETS.value))
    dut.cache.valid[index].value = 1
    dut.cache.dirty[index].value = dirty
    pass

def initCacheContents1234(dut):
    "initialize the cache with a fixed pattern: 1st block is 0x1111_1111, 2nd is 0x2222_2222, etc."
    block_size_bytes = int(dut.cache.BLOCK_SIZE_BITS.value / 8)
    for i in range(dut.cache.NUM_SETS.value):
        setCacheValue(dut, i*block_size_bytes, 0x1111_1111*(i+1))
        pass
    pass

#########################
## TEST CASES ARE HERE ##
#########################

@cocotb.test
async def testReadReset(dut):
    "Test that read-port values are sensible after reset"
    dut.CACHE_ARREADY.value = 0
    dut.CACHE_RVALID.value = 1
    dut.CACHE_RDATA.value = 1
    _ = await preTestSetup(dut)
    assertEquals(1, dut.CACHE_ARREADY.value, 'cache should be ready for read requests')
    assertEquals(0, dut.CACHE_RVALID.value, 'cache should not have a read response yet')
    assertEquals(0, dut.CACHE_RDATA.value, 'cache should not have a read response yet')

@cocotb.test(timeout_time=TIMEOUT_NS, timeout_unit="ns")
async def testRead(dut):
    "One read hit"
    axil_cache = await preTestSetup(dut)

    addr = 0
    expected_value = 0x1111_1111
    setCacheValue(dut, addr, expected_value)

    # read the data from the cache
    cache_value = await axil_cache.read_dword(addr)

    assertEquals(expected_value, cache_value, f'expected {expected_value:#x} but was {cache_value:#x}')

@cocotb.test(timeout_time=1600*CLOCK_PERIOD_NS, timeout_unit="ns")
async def testReadMany(dut):
    "Multiple read hits, no timing requirements"
    axil_cache = await preTestSetup(dut)

    initCacheContents1234(dut)

    # read all the blocks
    block_size_bytes = int(dut.cache.BLOCK_SIZE_BITS.value / 8)
    for a in range(0, dut.cache.NUM_SETS.value * block_size_bytes, block_size_bytes):
        cache_value = await axil_cache.read_dword(a)
        block_index = (a / 4) + 1
        expected_value = int(block_index * 0x1111_1111) & 0x0000_FFFF_FFFF
        assertEquals(expected_value, cache_value, f'expected {expected_value:#x} but was {cache_value:#x}')
        pass

@cocotb.test
async def testWriteReset(dut):
    "Test that write-port values are sensible after reset"
    dut.CACHE_AWREADY.value = 0
    dut.CACHE_WREADY.value = 0
    dut.CACHE_BVALID.value = 1
    _ = await preTestSetup(dut)
    assertEquals(1, dut.CACHE_AWREADY.value, 'cache should be ready for write address')
    assertEquals(1, dut.CACHE_WREADY.value, 'cache should be ready for write data')
    assertEquals(0, dut.CACHE_BVALID.value, 'cache should not have a write response yet')

@cocotb.test(timeout_time=TIMEOUT_NS, timeout_unit="ns")
async def testWriteRead(dut):
    "Write to the cache and read it back, no timing requirements"
    axil_cache = await preTestSetup(dut)

    addr = 0x4
    expected_value = 0x1234_5678
    setCacheValue(dut, addr, 0x1111_1111) # fill cache so the write will hit

    # write to the cache
    await axil_cache.write_dword(addr, expected_value)
    assertEquals(1, dut.cache.dirty[1].value, 'dirty bit should have been set')

    # read it back
    cache_value = await axil_cache.read_dword(addr)

    # check that write occurred
    assertEquals(expected_value, cache_value, f'expected {expected_value:#x} but was {cache_value:#x}')

@cocotb.test(timeout_time=2*TIMEOUT_NS, timeout_unit="ns")
async def testConsecutiveReads(dut):
    "Ensure consecutive read hits are handled without stalls"
    axil_cache = await preTestSetup(dut)

    addr = 0x0
    extent = 16
    scale = 0x1111_1111

    initCacheContents1234(dut)

    reads = []
    for a in range(addr,addr+extent,4):
        reads.append(axil_cache.init_read(a, 4))
        await ClockCycles(dut.ACLK, 1)
        pass
    start_nanos = get_sim_time()
    for a in range(addr,addr+extent,4):
        r = reads.pop(0)
        await r.wait()
        expected = int(((a/4)+1) * scale)
        actual = int.from_bytes(r.data.data, byteorder='little')
        assertEquals(expected, actual)
        pass
    elapsed_nanos = get_sim_time() - start_nanos
    # should be 2 cycles from when last read request is sent to when last read response arrives
    # 1st cycle is the last read request
    # 2nd cycle is the response to that last read request
    assertEquals(2*CLOCK_PERIOD_NS, elapsed_nanos, f'{elapsed_nanos} ns elapsed')

@cocotb.test(timeout_time=2*TIMEOUT_NS, timeout_unit="ns")
async def testConsecutiveWrites(dut):
    "Ensure consecutive write hits are handled without stalls"
    axil_cache = await preTestSetup(dut)

    addr = 0x0
    extent = 16
    base = 0x5555_5555
    scale = 0x1111_1111

    initCacheContents1234(dut)

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
    "send single read request, manager initially isn't ready for response"
    await preTestSetup(dut, setupAxilCache=False)
    addr = 0x4
    expected_value = 0x2222_2222
    setCacheValue(dut, addr, expected_value)

    # send single read request
    dut.CACHE_ARVALID.value = 1
    dut.CACHE_ARADDR.value = addr
    # manager isn't ready for response
    dut.CACHE_RREADY.value = 0
    await ClockCycles(dut.ACLK, 1)
    dut.CACHE_ARVALID.value = 0
    dut.CACHE_ARADDR.value = 0

    await ClockCycles(dut.ACLK, 4)
    assertEquals(1, dut.CACHE_RVALID.value)
    assertEquals(expected_value, dut.CACHE_RDATA.value)
    dut.CACHE_RREADY.value = 1
    await ClockCycles(dut.ACLK, 1)
    dut.CACHE_RREADY.value = 0
    await ClockCycles(dut.ACLK, 1)
    assertEquals(0, dut.CACHE_RVALID.value)

@cocotb.test(timeout_time=TIMEOUT_NS, timeout_unit="ns")
async def testLazyManager2(dut):
    "test read request buffering: send multiple read requests, manager initially isn't ready for response"
    await preTestSetup(dut, setupAxilCache=False)
    addr4 = 0x4
    expected_value4 = 0x2222_2222
    setCacheValue(dut, addr4, expected_value4)
    addr8 = 0x8
    expected_value8 = 0x3333_3333
    setCacheValue(dut, addr8, expected_value8)
    dut.CACHE_BREADY.value = 1

    # send 1st read request
    assertEquals(1, dut.CACHE_ARREADY.value)
    dut.CACHE_ARVALID.value = 1
    dut.CACHE_ARADDR.value = addr4
    dut.CACHE_RREADY.value = 1
    await ClockCycles(dut.ACLK, 1)
    assertEquals(1, dut.CACHE_ARREADY.value)
    # manager isn't ready for response
    dut.CACHE_RREADY.value = 0
    # send 2nd read request
    dut.CACHE_ARVALID.value = 1
    dut.CACHE_ARADDR.value = addr8
    await ClockCycles(dut.ACLK, 1)
    dut.CACHE_ARVALID.value = 0
    dut.CACHE_ARADDR.value = 0
    await ClockCycles(dut.ACLK, 1)
    # subordinate should stop accepting new requests
    assertEquals(0, dut.CACHE_ARREADY.value)

    await ClockCycles(dut.ACLK, 3)
    # ensure cache is still waiting manager to ack 1st response
    assertEquals(1, dut.CACHE_RVALID.value)
    assertEquals(expected_value4, dut.CACHE_RDATA.value)
    # manager accepts (only) 1st response
    dut.CACHE_RREADY.value = 1
    await ClockCycles(dut.ACLK, 1)
    dut.CACHE_RREADY.value = 0
    await ClockCycles(dut.ACLK, 1)

    # cache is sending 2nd response now
    assertEquals(1, dut.CACHE_RVALID.value)
    assertEquals(expected_value8, dut.CACHE_RDATA.value)
    await ClockCycles(dut.ACLK, 1)
    assertEquals(1, dut.CACHE_ARREADY.value)

    dut.CACHE_ARADDR.value = 0
    dut.CACHE_ARVALID.value = 0
    dut.CACHE_RREADY.value = 0

    dut.CACHE_AWADDR.value = 0
    dut.CACHE_AWVALID.value = 0
    dut.CACHE_WVALID.value = 0
    dut.CACHE_WDATA.value = 0
    dut.CACHE_WSTRB.value = 0
    dut.CACHE_BREADY.value = 0
    await ClockCycles(dut.ACLK, 1)

@cocotb.test(timeout_time=1700 * CLOCK_PERIOD_NS, timeout_unit="ns")
async def testRandomReadWrite(dut):
    "perform some random reads and writes against cache, compare with Python model of cache"

    axil_cache = await preTestSetup(dut)

    initCacheContents1234(dut)

    # Compute the accessible address range
    block_size_bytes = int(dut.cache.BLOCK_SIZE_BITS.value // 8)
    blocks = dut.cache.NUM_SETS.value
    total_cache_size_bytes = blocks * block_size_bytes
    dut._log.info(f"Total cache size in bytes: {total_cache_size_bytes}")

    local_model = {}

    #  Initialize cache
    base_val = 0x1111_1111
    for addr in range(0, total_cache_size_bytes, 4):
        dword_index = (addr // 4) + 1
        init_val = dword_index * base_val
        local_model[addr] = init_val
        dut._log.info(f'model init: {addr=:#x} = {init_val:#x}')
        pass

    # main loop
    for i in range(20):
        addr = random.randrange(0, total_cache_size_bytes, 4)
        is_write = random.choice([True, False])

        if is_write:
            new_data_32 = random.getrandbits(32)
            data_bytes = new_data_32.to_bytes(4, byteorder='little')

            # write transaction
            wtrans = axil_cache.init_write(address=addr, data=data_bytes)
            # Wait for 1 to 3 clock cycles to simulate pipeline/concurrent behavior
            await ClockCycles(dut.ACLK, random.randint(1,3))
            await wtrans.wait()

            dut._log.warning(f'{i=} WRITE {addr=:#x} {new_data_32=:#x}')

            # Update the local reference model
            local_model[addr] = new_data_32

        else:
            # read transaction
            rtrans = axil_cache.init_read(addr, 4)
            await ClockCycles(dut.ACLK, random.randint(1,3))
            await rtrans.wait()

            # Retrieve the read value and verify correctness
            actual_bytes = rtrans.data.data

            actual_val = int.from_bytes(actual_bytes, byteorder='little')
            expected_val = local_model[addr] & 0x0000_FFFF_FFFF
            dut._log.warning(f'{i=} READ {addr=:#x} {expected_val=:#x} {actual_val=:#x}')
            assertEquals(expected_val, actual_val, f"[READ] Addr=0x{addr:X} mismatch")
            pass
        pass

    # Perform a full read-back verification on all addresses
    for addr, exp_val in local_model.items():
        read_data = await axil_cache.read_dword(addr)
        assertEquals(exp_val & 0x0000_FFFF_FFFF, read_data, f"[FINAL] Addr=0x{addr:X} mismatch")
        pass
    pass
