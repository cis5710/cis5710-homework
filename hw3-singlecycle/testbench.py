import cocotb
import json
import os
import sys
import subprocess

from pathlib import Path
from cocotb.clock import Clock
from cocotb.regression import TestFactory
from cocotb.result import SimTimeoutError
from cocotb.runner import get_runner, get_results
from cocotb.triggers import RisingEdge, ClockCycles
from cocotb.triggers import Timer

p = Path.cwd() / '..' / 'common' / 'python'
sys.path.append(str(p))
import riscv_binary_utils
import cocotb_utils as cu
from cocotb_utils import assertEquals

# directory for this homework
PROJECT_PATH = Path(__file__).resolve().parent

TIMEOUT_CYCLES = 1_000

TRACING_MODE = 'compare' # compare against the solution trace
#TRACING_MODE = None # don't compare against or generate a trace
#TRACING_MODE = 'generate' # generate a new trace (for staff only)

def runCocotbTestsRegisterFile(pytestconfig):
    """run register file tests"""

    verilog_sources = [ PROJECT_PATH / "DatapathSingleCycle.sv" ]
    toplevel_module = "RegFile"

    runr = get_runner(cu.SIM)
    runr.build(
        verilog_sources=verilog_sources,
        vhdl_sources=[],
        hdl_toplevel=toplevel_module,
        waves=cu.shouldGenerateWaveforms(),
        includes=[PROJECT_PATH],
        build_dir=cu.SIM_BUILD_DIR,
        build_args=cu.VERILATOR_FLAGS,
    )

    runr.test(
        seed=12345,
        waves=cu.shouldGenerateWaveforms(),
        hdl_toplevel=toplevel_module, 
        test_module="testbench_regfile", # use tests from testbench_refile.py
        testcase=pytestconfig.option.tests, # filter tests via the `--tests` command-line flag
    )
    pass

def runCocotbTestsProcessor(pytestconfig):
    """run processor tests"""

    verilog_sources = [ PROJECT_PATH / "DatapathSingleCycle.sv" ]
    toplevel_module = "Processor"

    runr = get_runner(cu.SIM)
    runr.build(
        verilog_sources=verilog_sources,
        vhdl_sources=[],
        hdl_toplevel=toplevel_module,
        waves=cu.shouldGenerateWaveforms(),
        includes=[PROJECT_PATH],
        build_dir=cu.SIM_BUILD_DIR,
        build_args=cu.VERILATOR_FLAGS,
    )

    runr.test(
        seed=12345,
        waves=cu.shouldGenerateWaveforms(),
        hdl_toplevel=toplevel_module, 
        test_module=Path(__file__).stem, # use tests from the current file
        testcase=pytestconfig.option.tests, # filter tests via the `--tests` command-line flag
    )
    pass

def runCocotbTests(pytestconfig):
    """calculate scores for autograder"""
    test_results = cu.aggregateTestResults(
        get_results(Path(cu.SIM_BUILD_DIR,'runCocotbTestsRegisterFile.None')),
        get_results(Path(cu.SIM_BUILD_DIR,'runCocotbTestsProcessor.None')),
    )
    # 1 point per cocotb test
    points = { 'pointsEarned': test_results['tests_passed'], 'pointsPossible': test_results['tests_total'] }
    with open(cu.POINTS_FILE, 'w') as f:
        json.dump(points, f, indent=2)
        pass
    pass

async def memClock(dut):
    # pre-construct triggers for performance
    high_time = Timer(2, units="ns")
    low_time = Timer(2, units="ns")
    await Timer(1, units="ns") # phase shift by 90°
    while True:
        dut.clock_mem.value = 1
        await high_time
        dut.clock_mem.value = 0
        await low_time
        pass
    pass

import inspect
from cocotb.binary import BinaryValue

async def preTestSetup(dut, insns_or_path):
    """Setup the DUT. MUST be called at the start of EACH test."""
    # Create processor clock
    proc_clock = Clock(dut.clock_proc, 4, units="ns")
    # Start the clocks
    cocotb.start_soon(proc_clock.start(start_high=True))
    cocotb.start_soon(memClock(dut))
    # wait for first rising edge
    await RisingEdge(dut.clock_proc)

    # raise `rst` signal for one rising edge
    dut.rst.value = 1
    await ClockCycles(dut.clock_proc, 1)
    # load the code
    if isinstance(insns_or_path,Path):
        riscv_binary_utils.loadBinaryIntoMemory(dut,insns_or_path)
    else:
        riscv_binary_utils.asm(dut,insns_or_path)
        pass
    await ClockCycles(dut.clock_proc, 1)
        
    # lower `rst` signal
    dut.rst.value = 0
    # design should be reset now

    # set test_case wire
    caller_name = inspect.stack()[1].function
    if caller_name == 'riscvTest':
        caller_frame = inspect.currentframe().f_back
        caller_name = os.path.basename(caller_frame.f_locals['binaryPath'])
        pass
    caller_name_binary = ''.join(format(ord(char), '08b') for char in caller_name.ljust(32))
    dut.test_case.value = BinaryValue(caller_name_binary, n_bits=len(caller_name_binary))

    return


########################
## TEST CASES GO HERE ##
########################

@cocotb.test()
async def testLui(dut):
    "Run one lui insn"
    await preTestSetup(dut, 'lui x1,0x12345')

    await ClockCycles(dut.clock_proc, 2)
    assertEquals(0x12345000, dut.datapath.rf.regs[1].value, f'failed at cycle {dut.datapath.cycles_current.value.integer}')

@cocotb.test()
async def testAddi(dut):
    "Run one addi insn"
    await preTestSetup(dut, 'addi x1,x0,9')

    await ClockCycles(dut.clock_proc, 2)
    assertEquals(9, dut.datapath.rf.regs[1].value, f'failed at cycle {dut.datapath.cycles_current.value.integer}')

@cocotb.test()
async def testLuiAddi(dut):
    "Run two insns to check PC incrementing"
    await preTestSetup(dut, '''
        lui x1,0x12345
        addi x1,x1,0x678''')

    await ClockCycles(dut.clock_proc, 3)
    assertEquals(0x12345678, dut.datapath.rf.regs[1].value, f'failed at cycle {dut.datapath.cycles_current.value.integer}')

@cocotb.test()
async def testAddiAll(dut):
    "Check all immediate values for addi x1,x0,IMM"
    code = ""
    for imm in range(-2048,2048):
        code += f'addi x1,x0,{imm}\n'
        pass
    await preTestSetup(dut, code)
    await RisingEdge(dut.clock_proc)

    for imm in range(-2048,2047):
        await RisingEdge(dut.clock_proc)
        expected = imm & 0xFFFFFFFF # convert to unsigned, to match cocotb
        assertEquals(expected, dut.datapath.rf.regs[1].value.integer, f'failed at cycle {dut.datapath.cycles_current.value.integer} with imm = {imm}')
        pass
    pass

@cocotb.test()
async def testSlli(dut):
    "Run slli"
    await preTestSetup(dut, '''
    addi x1,x0,8
    slli x1,x1,2''')

    await ClockCycles(dut.clock_proc, 3)
    assertEquals(32, dut.datapath.rf.regs[1].value, f'failed at cycle {dut.datapath.cycles_current.value.integer}')

@cocotb.test()
async def testOri(dut):
    "Run ori"
    await preTestSetup(dut, '''
    addi x1,x0,8
    ori x1,x1,7''')

    await ClockCycles(dut.clock_proc, 3)
    assertEquals(15, dut.datapath.rf.regs[1].value, f'failed at cycle {dut.datapath.cycles_current.value.integer}')

@cocotb.test()
async def testOriSext(dut):
    "Test ori sign-extension"
    await preTestSetup(dut, '''
    addi x1,x0,3
    ori x1,x1,-4''')

    await ClockCycles(dut.clock_proc, 3)
    assertEquals(0xFFFF_FFFF, dut.datapath.rf.regs[1].value, f'failed at cycle {dut.datapath.cycles_current.value.integer}')

@cocotb.test()
async def testBneNotTaken(dut):
    "bne which is not taken"
    await preTestSetup(dut, '''
        lui x1,0x12345
        bne x0,x0,target
        lui x1,0x54321
        target: lui x0,0''')

    await ClockCycles(dut.clock_proc, 4)
    assertEquals(0x54321000, dut.datapath.rf.regs[1].value, f'failed at cycle {dut.datapath.cycles_current.value.integer}')
    pass

@cocotb.test()
async def testBeqNotTaken(dut):
    "beq which is not taken"
    await preTestSetup(dut, '''
        lui x1,0x12345
        beq x1,x0,target
        lui x1,0x54321
        target: lui x0,0''')

    await ClockCycles(dut.clock_proc, 4)
    assertEquals(0x54321000, dut.datapath.rf.regs[1].value, f'failed at cycle {dut.datapath.cycles_current.value.integer}')
    pass

@cocotb.test()
async def testBneTaken(dut):
    "bne which is taken"
    await preTestSetup(dut, '''
        lui x1,0x12345
        bne x1,x0,target
        lui x1,0x54321
        target: lui x0,0''')

    await ClockCycles(dut.clock_proc, 4)
    assertEquals(0x12345000, dut.datapath.rf.regs[1].value, f'failed at cycle {dut.datapath.cycles_current.value.integer}')
    pass

@cocotb.test()
async def testBeqTaken(dut):
    "beq which is taken"
    await preTestSetup(dut, '''
        lui x1,0x12345
        beq x1,x1,target
        lui x1,0x54321
        target: lui x0,0''')

    await ClockCycles(dut.clock_proc, 4)
    assertEquals(0x12345000, dut.datapath.rf.regs[1].value, f'failed at cycle {dut.datapath.cycles_current.value.integer}')
    pass

@cocotb.test()
async def testEcall(dut):
    "ecall insn causes processor to halt"
    await preTestSetup(dut, '''
        lui x1,0x12345
        ecall
        lui x1,0xABCDE''')

    await ClockCycles(dut.clock_proc, 2) # check for halt *during* ecall
    assertEquals(1, dut.datapath.halt.value, f'failed at cycle {dut.datapath.cycles_current.value.integer}')
    await ClockCycles(dut.clock_proc, 1) # ensure halt goes back down after ecall is done
    assertEquals(0, dut.datapath.halt.value, f'failed at cycle {dut.datapath.cycles_current.value.integer}')
    pass

@cocotb.test()
async def testTraceRvLui(dut):
    "Use the LUI riscv-test with trace comparison"
    await riscvTest(dut, cu.RISCV_TESTS_PATH / 'rv32ui-p-lui', TRACING_MODE)

@cocotb.test()
async def testTraceRvBeq(dut):
    "Use the BEQ riscv-test with trace comparison"
    await riscvTest(dut, cu.RISCV_TESTS_PATH / 'rv32ui-p-beq', TRACING_MODE)


#########################
## FULL ISA TEST CASES ##
#########################

@cocotb.test(skip='RVTEST_ALUBR' in os.environ)
async def testStoreLoad(dut):
    "Check that a load can read a previously-stored value."
    await preTestSetup(dut, '''
        lui x1,0x12345
        sw x1,32(x0) # store x1 to address [32]. NB: code starts at address 0, don't overwrite it!
        lw x2,32(x0) # load address [32] into x2
        ''')

    await ClockCycles(dut.clock_proc, 4)
    assertEquals(0x12345000, dut.datapath.rf.regs[2].value, f'failed at cycle {dut.datapath.cycles_current.value.integer}')

@cocotb.test(skip='RVTEST_ALUBR' in os.environ)
async def testTraceRvLw(dut):
    "Use the LW riscv-test with trace comparison"
    await riscvTest(dut, cu.RISCV_TESTS_PATH / 'rv32ui-p-lw', TRACING_MODE)
    
# tracingMode argument is one of `generate`, `compare` or None
async def riscvTest(dut, binaryPath=None, tracingMode=None):
    "Run the official RISC-V test whose binary lives at `binaryPath`"
    assert binaryPath is not None
    assert binaryPath.exists(), f'Could not find RV test binary {binaryPath}, have you built riscv-tests?'
    await preTestSetup(dut, binaryPath)

    trace = []
    if tracingMode == 'compare':
        # use ../ since we run from the sim_build directory
        with open(f'../trace-{binaryPath.name}.json', 'r', encoding='utf-8') as f:
            trace = json.load(f)
            pass
        pass

    dut._log.info(f'Running RISC-V test at {binaryPath} with tracingMode == {tracingMode}')
    for cycles in range(TIMEOUT_CYCLES):
        await RisingEdge(dut.clock_proc)

        cu.handleTrace(dut, trace, cycles, tracingMode)
        if dut.halt.value == 1:
            # see RVTEST_PASS and RVTEST_FAIL macros in riscv-tests/env/p/riscv_test.h
            assertEquals(93, dut.datapath.rf.regs[17].value.integer) # magic value from pass/fail functions
            resultCode = dut.datapath.rf.regs[10].value.integer
            assert 0 == resultCode, f'failed test {resultCode >> 1} at cycle {dut.datapath.cycles_current.value.integer}'
            if tracingMode == 'generate':
                with open(f'trace-{binaryPath.name}.json', 'w', encoding='utf-8') as f:
                    json.dump(trace, f, indent=2)
                    pass
            return
        pass
    raise SimTimeoutError()

RV_TEST_BINARIES = [
    cu.RISCV_TESTS_PATH / 'rv32ui-p-simple', # 1
    cu.RISCV_TESTS_PATH / 'rv32ui-p-lui',
    
    cu.RISCV_TESTS_PATH / 'rv32ui-p-and', # 3
    cu.RISCV_TESTS_PATH / 'rv32ui-p-or',
    cu.RISCV_TESTS_PATH / 'rv32ui-p-xor',
    cu.RISCV_TESTS_PATH / 'rv32ui-p-sll',
    cu.RISCV_TESTS_PATH / 'rv32ui-p-sra',
    cu.RISCV_TESTS_PATH / 'rv32ui-p-srl',
    cu.RISCV_TESTS_PATH / 'rv32ui-p-slt',
    cu.RISCV_TESTS_PATH / 'rv32ui-p-add',
    cu.RISCV_TESTS_PATH / 'rv32ui-p-sub',
    
    cu.RISCV_TESTS_PATH / 'rv32ui-p-andi', # 12
    cu.RISCV_TESTS_PATH / 'rv32ui-p-ori',
    cu.RISCV_TESTS_PATH / 'rv32ui-p-slli',
    cu.RISCV_TESTS_PATH / 'rv32ui-p-srai',
    cu.RISCV_TESTS_PATH / 'rv32ui-p-srli',
    cu.RISCV_TESTS_PATH / 'rv32ui-p-xori',
    cu.RISCV_TESTS_PATH / 'rv32ui-p-slti',
    cu.RISCV_TESTS_PATH / 'rv32ui-p-sltiu',
    cu.RISCV_TESTS_PATH / 'rv32ui-p-sltu',
    cu.RISCV_TESTS_PATH / 'rv32ui-p-addi',
    
    cu.RISCV_TESTS_PATH / 'rv32ui-p-beq', # 22
    cu.RISCV_TESTS_PATH / 'rv32ui-p-bge',
    cu.RISCV_TESTS_PATH / 'rv32ui-p-bgeu',
    cu.RISCV_TESTS_PATH / 'rv32ui-p-blt',
    cu.RISCV_TESTS_PATH / 'rv32ui-p-bltu',
    cu.RISCV_TESTS_PATH / 'rv32ui-p-bne',

    cu.RISCV_TESTS_PATH / 'rv32ui-p-jal', # 28
    cu.RISCV_TESTS_PATH / 'rv32ui-p-jalr',
    cu.RISCV_TESTS_PATH / 'rv32ui-p-auipc', # needs JAL

    cu.RISCV_TESTS_PATH / 'rv32ui-p-lb', # 31
    cu.RISCV_TESTS_PATH / 'rv32ui-p-lbu',
    cu.RISCV_TESTS_PATH / 'rv32ui-p-lh',
    cu.RISCV_TESTS_PATH / 'rv32ui-p-lhu',
    cu.RISCV_TESTS_PATH / 'rv32ui-p-lw',
    
    cu.RISCV_TESTS_PATH / 'rv32ui-p-sb', # 36
    cu.RISCV_TESTS_PATH / 'rv32ui-p-sh',
    cu.RISCV_TESTS_PATH / 'rv32ui-p-sw',

    cu.RISCV_TESTS_PATH / 'rv32um-p-mul', # 39
    cu.RISCV_TESTS_PATH / 'rv32um-p-mulh',
    cu.RISCV_TESTS_PATH / 'rv32um-p-mulhsu',
    cu.RISCV_TESTS_PATH / 'rv32um-p-mulhu',
    cu.RISCV_TESTS_PATH / 'rv32um-p-div', # 43
    cu.RISCV_TESTS_PATH / 'rv32um-p-divu',
    cu.RISCV_TESTS_PATH / 'rv32um-p-rem',
    cu.RISCV_TESTS_PATH / 'rv32um-p-remu',

    # unsupported tests

    # self-modifying code and fence.i insn
    # cu.RISCV_TESTS_PATH / 'rv32ui-p-fence_i',
    # misaligned accesses
    #cu.RISCV_TESTS_PATH / 'rv32ui-p-ma_data',
]

rvTestFactory = TestFactory(test_function=riscvTest)
if 'RVTEST_ALUBR' in os.environ:
    RV_TEST_BINARIES = RV_TEST_BINARIES[:27]
    pass
rvTestFactory.add_option(name='binaryPath', optionlist=RV_TEST_BINARIES)
rvTestFactory.generate_tests()

@cocotb.test(skip='RVTEST_ALUBR' in os.environ)
async def dhrystone(dut, tracingMode=TRACING_MODE):
    "Run dhrystone benchmark from riscv-tests"
    dsBinary = cu.RISCV_BENCHMARKS_PATH / 'dhrystone.riscv' 
    assert dsBinary.exists(), f'Could not find Dhrystone binary {dsBinary}, have you built riscv-tests?'
    await preTestSetup(dut, dsBinary)

    trace = []
    if tracingMode == 'compare':
        # use ../ since we run from the sim_build directory
        with open(f'../trace-{dsBinary.name}.json', 'r', encoding='utf-8') as f:
            trace = json.load(f)
            pass
        pass

    dut._log.info(f'Running Dhrystone benchmark (takes 193k cycles)... with tracingMode == {tracingMode}')
    for cycles in range(210_000):
        await RisingEdge(dut.clock_proc)

        cu.handleTrace(dut, trace, cycles, tracingMode)
        if cycles > 0 and 0 == cycles % 10_000:
            dut._log.info(f'ran {int(cycles/1000)}k cycles...')
            pass
        if dut.halt.value == 1:
            # there are 22 output checks, each sets 1 bit
            expectedValue = (1<<22) - 1
            assertEquals(expectedValue, dut.datapath.rf.regs[5].value.integer)
            latency_millis = (cycles / 15_000_000) * 1000
            dut._log.info(f'dhrystone passed after {cycles} cycles, {latency_millis} milliseconds with 15MHz clock')
            
            if tracingMode == 'generate':
                with open(f'trace-{dsBinary.name}.json', 'w', encoding='utf-8') as f:
                    json.dump(trace, f, indent=2)
                    pass
            
            return
        pass
    raise SimTimeoutError()
