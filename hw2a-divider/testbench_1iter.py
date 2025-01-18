import cocotb, sys, random
from pathlib import Path

# from cocotb.runner import get_runner, get_results
from cocotb.triggers import Timer

p = Path.cwd() / '..' / 'common' / 'python'
sys.path.append(str(p))
from cocotb_utils import assertEquals


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
    assertEquals(0, dut.o_dividend.value)
    assertEquals(16, dut.o_quotient.value)
    assertEquals(1, dut.o_remainder.value)
    pass

@cocotb.test()
async def test_rem_gte_divisor(dut):
    await Timer(1, "ns")
    dut.i_dividend.value = 0x8000_0000
    dut.i_divisor.value = 1
    dut.i_remainder.value = 0
    dut.i_quotient.value = 8
    await Timer(1, "ns")
    assertEquals(0, dut.o_dividend.value)
    assertEquals(16+1, dut.o_quotient.value)
    assertEquals(0, dut.o_remainder.value)
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
        assertEquals(exp_dividend, dut.o_dividend.value, msg)
        assertEquals(exp_quotient, dut.o_quotient.value, msg)
        assertEquals(exp_remainder, dut.o_remainder.value, msg)
        pass
    pass
