import cocotb
from cocotb.triggers import Timer

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

