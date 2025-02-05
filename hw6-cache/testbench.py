import cocotb
import json
import os
import subprocess

from pathlib import Path
from cocotb.clock import Clock
from cocotb.regression import TestFactory
from cocotb.result import SimTimeoutError
from cocotb.runner import get_runner, get_results
from cocotb.triggers import RisingEdge, FallingEdge, ClockCycles
from cocotb.triggers import Timer

from cocotbext.axi import AxiLiteBus, AxiLiteRam

import logging
loggerMemA = logging.getLogger('cocotb.Processor.MEMA')
loggerMemA.setLevel(logging.WARNING)
loggerMemB = logging.getLogger('cocotb.Processor.MEMB')
loggerMemB.setLevel(logging.WARNING)

import sys

p = Path.cwd() / '..' / 'common' / 'python'
sys.path.append(str(p))
import riscv_binary_utils
import cocotb_utils as cu
from cocotb_utils import assertEquals

# the number of stages the divider is split into
DIVIDER_STAGES = 8

# directory for this homework
PROJECT_PATH = Path(__file__).resolve().parent

TIMEOUT_CYCLES = 4_500

#TRACING_MODE = 'compare' # compare against the solution trace
#TRACING_MODE = None # don't compare against or generate a trace
TRACING_MODE = 'generate' # generate a new trace (for staff only)


async def preTestSetup(dut):
    """Setup the DUT. MUST be called at the start of EACH test."""
    # Create clock
    proc_clock = Clock(dut.clk, 4, units="ns")
    # Start the clocks
    cocotb.start_soon(proc_clock.start(start_high=True))

    # connect memory
    axil_imem = AxiLiteRam(AxiLiteBus.from_prefix(dut, "MEMA"), 
                            dut.clk, 
                            dut.rst, 
                            reset_active_level=True,
                            size=2**16)
    axil_dmem = AxiLiteRam(AxiLiteBus.from_prefix(dut, "MEMB"), 
                            dut.clk, 
                            dut.rst, 
                            reset_active_level=True,
                            mem=axil_imem.mem)

    # AxiLiteBus.log.setLevel(logging.WARNING)
    # axil_dmem.log.setLevel(logging.WARNING)

    # wait for first rising edge
    await RisingEdge(dut.clk)
    # raise `rst` signal for 2 cycles
    dut.rst.value = 1
    await ClockCycles(dut.clk, 2)
    # lower `rst` signal
    dut.rst.value = 0
    # design should be reset now

    return (axil_imem, axil_dmem)

def runCocotbTestsDmCacheHit(pytestconfig):
    """run direct-mapped cache hit tests"""

    verilog_sources = [ PROJECT_PATH / "AxilCache.sv" ]
    toplevel_module = "AxilCacheTester"

    runr = get_runner(cu.SIM)
    runr.build(
        verilog_sources=verilog_sources,
        vhdl_sources=[],
        hdl_toplevel=toplevel_module,
        waves=True,
        parameters={'WAYS':1, 'TEST_PATTERN_ON_RESET':1},
        includes=[PROJECT_PATH],
        build_dir=cu.SIM_BUILD_DIR,
        build_args=cu.VERILATOR_FLAGS,
    )

    runr.test(
        seed=12345,
        waves=True,
        hdl_toplevel=toplevel_module, 
        test_module='testbench_dmcache_hit', # use tests from this file
        testcase=pytestconfig.option.tests, # filter tests via the `--tests` command-line flag
    )
    pass

def runCocotbTestsDmCacheMiss(pytestconfig):
    """run direct-mapped cache miss tests"""

    verilog_sources = [ PROJECT_PATH / "AxilCache.sv" ]
    toplevel_module = "AxilCacheTester"

    runr = get_runner(cu.SIM)
    runr.build(
        verilog_sources=verilog_sources,
        vhdl_sources=[],
        hdl_toplevel=toplevel_module,
        waves=True,
        parameters={'WAYS':1, 'CLEAR_ON_RESET':1},
        includes=[PROJECT_PATH],
        build_dir=cu.SIM_BUILD_DIR,
        build_args=cu.VERILATOR_FLAGS,
    )

    runr.test(
        seed=12345,
        waves=True,
        hdl_toplevel=toplevel_module, 
        test_module='testbench_dmcache_miss', # use tests from this file
        testcase=pytestconfig.option.tests, # filter tests via the `--tests` command-line flag
    )
    pass

def runCocotbTestsProcessor(pytestconfig):
    """run processor tests"""

    verilog_sources = [ PROJECT_PATH / "DatapathPipelinedCache.sv" ]
    toplevel_module = "Processor"

    runr = get_runner(cu.SIM)
    runr.build(
        verilog_sources=verilog_sources,
        vhdl_sources=[],
        hdl_toplevel=toplevel_module,
        waves=True,
        includes=[PROJECT_PATH],
        build_dir=cu.SIM_BUILD_DIR,
        build_args=cu.VERILATOR_FLAGS+[f'-DDIVIDER_STAGES={DIVIDER_STAGES}'],
    )

    runr.test(
        seed=12345,
        waves=True,
        hdl_toplevel=toplevel_module, 
        test_module=Path(__file__).stem, # use tests from this file
        testcase=pytestconfig.option.tests, # filter tests via the `--tests` command-line flag
    )
    pass

def runCocotbTestsSystem(pytestconfig):
    """run system tests"""

    verilog_sources = [ PROJECT_PATH / "system" / "System.sv" ]
    toplevel_module = "SystemSim"

    runr = get_runner(cu.SIM)
    runr.build(
        verilog_sources=verilog_sources,
        vhdl_sources=[],
        hdl_toplevel=toplevel_module,
        waves=True,
        includes=[PROJECT_PATH],
        build_dir=cu.SIM_BUILD_DIR,
        build_args=cu.VERILATOR_FLAGS+[f'-DDIVIDER_STAGES={DIVIDER_STAGES}'],
    )

    runr.test(
        seed=12345,
        waves=True,
        hdl_toplevel=toplevel_module, 
        test_module="testbench_system", # use tests from this file
        testcase=pytestconfig.option.tests, # filter tests via the `--tests` command-line flag
    )
    pass

def runCocotbTestsHdmi(pytestconfig):
    """run hdmi tests"""

    verilog_sources = [ PROJECT_PATH / "SystemSim.v" ]
    toplevel_module = "System"

    runr = get_runner('icarus')
    runr.build(
        verilog_sources=verilog_sources,
        vhdl_sources=[],
        hdl_toplevel=toplevel_module,
        waves=True,
        includes=[PROJECT_PATH],
        build_dir=cu.SIM_BUILD_DIR,
        build_args=['-Wall'],
    )

    runr.test(
        seed=12345,
        waves=True,
        hdl_toplevel=toplevel_module, 
        test_module="testbench_system", # use tests from this file
        testcase=pytestconfig.option.tests, # filter tests via the `--tests` command-line flag
    )
    pass

def runCocotbTests(pytestconfig):
    """calculate scores for autograder"""
    test_results = cu.aggregateTestResults(
        get_results(Path(cu.SIM_BUILD_DIR,'runCocotbTestsDmCacheHit.None')),
        get_results(Path(cu.SIM_BUILD_DIR,'runCocotbTestsDmCacheMiss.None')),
        get_results(Path(cu.SIM_BUILD_DIR,'runCocotbTestsProcessor.None')),
    )
    # 1 point per cocotb test
    points = { 'pointsEarned': test_results['tests_passed'], 'pointsPossible': test_results['tests_total'] }
    with open('points.json', 'w') as f:
        json.dump(points, f, indent=2)
        pass
    pass



########################
## TEST CASES GO HERE ##
########################

INSN_LATENCY = 5
MISS_LATENCY = 4
CHECK_LATENCY = 1
MISPRED_LATENCY = 4 # 2 cycles to clear F/D, then +2 cycles for current I$ miss to resolve

START_LATENCY = 10 # TODO: deprecated

@cocotb.test()
async def testLui(dut):
    "Run one lui insn"
    axil_imem, _ = await preTestSetup(dut)
    riscv_binary_utils.asm(axil_imem, 'lui x1,0x12345')

    await ClockCycles(dut.clk, INSN_LATENCY + MISS_LATENCY + CHECK_LATENCY)
    assertEquals(0x12345000, dut.datapath.rf.regs[1].value, f'failed at cycle {dut.datapath.cycles_current.value.integer}')

@cocotb.test()
async def testLuiLui(dut):
    "Run two lui independent insns"
    axil_imem, _ = await preTestSetup(dut)
    riscv_binary_utils.asm(axil_imem, '''lui x1,0x12345
        lui x2,0x6789A''')

    # lui x2's miss latency is hidden by lui x1's trip through the pipeline
    await ClockCycles(dut.clk, INSN_LATENCY + MISS_LATENCY + INSN_LATENCY + CHECK_LATENCY)
    assertEquals(0x12345000, dut.datapath.rf.regs[1].value, f'failed at cycle {dut.datapath.cycles_current.value.integer}')
    assertEquals(0x6789A000, dut.datapath.rf.regs[2].value, f'failed at cycle {dut.datapath.cycles_current.value.integer}')

@cocotb.test()
async def testLui3(dut):
    "Run three lui independent insns"
    axil_imem, _ = await preTestSetup(dut)
    riscv_binary_utils.asm(axil_imem, '''lui x1,0x12345
        lui x2,0x6789A
        lui x3,0xBCDEF''')

    await ClockCycles(dut.clk, INSN_LATENCY + MISS_LATENCY + 2*INSN_LATENCY + CHECK_LATENCY)
    assertEquals(0x12345000, dut.datapath.rf.regs[1].value, f'failed at cycle {dut.datapath.cycles_current.value.integer}')
    assertEquals(0x6789A000, dut.datapath.rf.regs[2].value, f'failed at cycle {dut.datapath.cycles_current.value.integer}')
    assertEquals(0xBCDEF000, dut.datapath.rf.regs[3].value, f'failed at cycle {dut.datapath.cycles_current.value.integer}')

# TODO: include bypassing tests from HW5

# TODO: include cache hit tests

@cocotb.test()
async def testAddi3(dut):
    "Run three addi insns"
    axil_imem, _ = await preTestSetup(dut)
    riscv_binary_utils.asm(axil_imem, '''addi x1,x1,1
        addi x1,x1,2
        addi x1,x1,3 # stop executing after this insn
        addi x1,x1,4 # add extra insns to see ensure we don't over-fetch
        addi x1,x1,5
        addi x1,x1,6
        addi x1,x1,7
        addi x1,x1,8''')

    await ClockCycles(dut.clk, INSN_LATENCY + MISS_LATENCY + 2*INSN_LATENCY + CHECK_LATENCY)
    assertEquals(6, dut.datapath.rf.regs[1].value, f'failed at cycle {dut.datapath.cycles_current.value.integer}')

@cocotb.test()
async def testBneTaken(dut):
    "bne which is taken"
    axil_imem, _ = await preTestSetup(dut)

    riscv_binary_utils.asm(axil_imem, '''
        lui x1,0x12345
        bne x1,x0,target
        lui x1,0x54321 # still waiting on I$ miss when branch is taken, should get cleared
        lui x1,0xABCDE # should never get fetched
        target: addi x1,x1,1
        addi x0,x0,0
        ''')

    await ClockCycles(dut.clk, INSN_LATENCY + MISS_LATENCY + 2*INSN_LATENCY + MISPRED_LATENCY + CHECK_LATENCY)
    assertEquals(0x12345001, dut.datapath.rf.regs[1].value, f'failed at cycle {dut.datapath.cycles_current.value.integer}')
    pass

@cocotb.test()
async def testBeqTaken(dut):
    "beq which is taken"
    axil_imem, _ = await preTestSetup(dut)
    riscv_binary_utils.asm(axil_imem, '''
        lui x1,0x12345
        beq x1,x1,target
        lui x1,0x54321 # in Decode when branch is taken, should get cleared
        lui x1,0xABCDE # in Fetch when branch is taken, should get cleared
        target: addi x0,x0,0
        addi x0,x0,0
        ''')

    await ClockCycles(dut.clk, INSN_LATENCY + MISS_LATENCY + 2*INSN_LATENCY + MISPRED_LATENCY + CHECK_LATENCY)
    assertEquals(0x12345000, dut.datapath.rf.regs[1].value, f'failed at cycle {dut.datapath.cycles_current.value.integer}')
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

# TODO: load D$ with test pattern so we can check hit timing

@cocotb.test(skip='RVTEST_ALUBR' in os.environ)
async def testLoad(dut):
    "test lw insn"
    axil_imem, _ = await preTestSetup(dut)
    riscv_binary_utils.asm(axil_imem, '''
        lw x1,0(x0) # loads bits of the lw insn itself
        ''')

    await ClockCycles(dut.clk, INSN_LATENCY + 2*MISS_LATENCY + CHECK_LATENCY)
    assertEquals(0x0000_2083, dut.datapath.rf.regs[1].value, f'failed at cycle {dut.datapath.cycles_current.value.integer}')
    pass

@cocotb.test(skip='RVTEST_ALUBR' in os.environ)
async def testLoadUse1(dut):
    "load to use in rs1"
    axil_imem, _ = await preTestSetup(dut)
    riscv_binary_utils.asm(axil_imem, '''
        lw x1,0(x0) # loads bits of the lw insn itself
        add x2,x1,x0
        ''')

    # -1 because add's I$ miss overlaps a bit with lw's d$ miss
    await ClockCycles(dut.clk, INSN_LATENCY + 2*MISS_LATENCY + INSN_LATENCY + CHECK_LATENCY - 1)
    assertEquals(0x0000_2083, dut.datapath.rf.regs[2].value, f'failed at cycle {dut.datapath.cycles_current.value.integer}')
    pass

@cocotb.test(skip='RVTEST_ALUBR' in os.environ)
async def testLoadUse2(dut):
    "load to use in rs1"
    axil_imem, _ = await preTestSetup(dut)
    riscv_binary_utils.asm(axil_imem, '''
        lw x1,0(x0) # loads bits of the lw insn itself
        add x2,x0,x1
        ''')

    # -1 because add's I$ miss overlaps a bit with lw's d$ miss
    await ClockCycles(dut.clk, INSN_LATENCY + 2*MISS_LATENCY + INSN_LATENCY + CHECK_LATENCY - 1)
    assertEquals(0x0000_2083, dut.datapath.rf.regs[2].value, f'failed at cycle {dut.datapath.cycles_current.value.integer}')
    pass

@cocotb.test(skip='RVTEST_ALUBR' in os.environ)
async def testLoadFalseUse(dut):
    "load followed by insn that doesn't actually use load result"
    axil_imem, _ = await preTestSetup(dut)
    riscv_binary_utils.asm(axil_imem, '''
        lw x0,0(x0) # loads bits of the lw insn itself
        lui x1,0xFE007
        ''')

    # -1 because lui's I$ miss overlaps a bit with lw's d$ miss
    await ClockCycles(dut.clk, INSN_LATENCY + 2*MISS_LATENCY + INSN_LATENCY + CHECK_LATENCY - 1)
    assertEquals(0xFE00_7000, dut.datapath.rf.regs[1].value, f'failed at cycle {dut.datapath.cycles_current.value.integer}')
    pass

# TODO: tests below here have not had their latencies updated

@cocotb.test(skip='RVTEST_ALUBR' in os.environ)
async def testWMData(dut):
    "WM bypass"
    axil_imem, _ = await preTestSetup(dut)
    riscv_binary_utils.asm(axil_imem, '''
        lw x1,0(x0) # loads bits of the lw insn itself
        sw x1,12(x0)
        ''')

    await ClockCycles(dut.clk, (START_LATENCY + 2*MISS_LATENCY) - 1)
    assertEquals(0x0000_2083, dut.mem.mem_array[3].value, f'failed at cycle {dut.datapath.cycles_current.value.integer}')
    pass

@cocotb.test(skip='RVTEST_ALUBR' in os.environ)
async def testWMAddress(dut):
    "WM bypass"
    axil_imem, _ = await preTestSetup(dut)
    riscv_binary_utils.asm(axil_imem, '''
        lw x1,0(x0) # loads bits of the lw insn itself
        sb x1,0(x1) # use sb since x1 is not 2B or 4B aligned
        ''')
    loadValue = 0x2083

    await ClockCycles(dut.clk, 5) # sb in X stage
    assertEquals(0, dut.mem.mem_array[int(loadValue / 4)].value, f'failed at cycle {dut.datapath.cycles_current.value.integer}')
    await ClockCycles(dut.clk, 2) # sb reaches W stage, memory write complete
    assertEquals(0x8300_0000, dut.mem.mem_array[int(loadValue / 4)].value, f'failed at cycle {dut.datapath.cycles_current.value.integer}')
    pass

# @cocotb.test(skip='RVTEST_ALUBR' in os.environ)
# async def testFence(dut):
#     "Test fence insn"
#     axil_imem, _ = await preTestSetup(dut)
#     riscv_binary_utils.asm(axil_imem, '''
#         li x2,0xfffff0b7 # machine code for `lui x1,0xfffff`. NB: li needs 2 insn lui+addi sequence
#         # addi part of li goes here
#         sw x2,16(x0) # overwrite lui below
#         fence # should stall until sw reaches Writeback
#         lui x1,0x12345
#         ''')

#     await ClockCycles(dut.clk, 12)
#     assertEquals(0xFFFF_F000, dut.datapath.rf.regs[1].value, f'failed at cycle {dut.datapath.cycles_current.value.integer}')
#     pass

@cocotb.test(skip='RVTEST_ALUBR' in os.environ)
async def testDiv(dut):
    "Run div insn"
    axil_imem, _ = await preTestSetup(dut)
    riscv_binary_utils.asm(axil_imem, '''
        lui x1,0x12345
        div x2,x1,x1''')

    await ClockCycles(dut.clk, INSN_LATENCY + 2*MISS_LATENCY + DIVIDER_STAGES + CHECK_LATENCY)
    assertEquals(1, dut.datapath.rf.regs[2].value, f'failed at cycle {dut.datapath.cycles_current.value.integer}')

@cocotb.test(skip='RVTEST_ALUBR' in os.environ)
async def testDivUse(dut):
    "Run div + dependent insn"
    axil_imem, _ = await preTestSetup(dut)
    riscv_binary_utils.asm(axil_imem, '''
        lui x1,0x12345
        div x2,x1,x1
        add x3,x2,x2 # needs stall + WX bypass
        ''')

    await ClockCycles(dut.clk, 20)
    assertEquals(1, dut.datapath.rf.regs[2].value, f'failed at cycle {dut.datapath.cycles_current.value.integer}')
    assertEquals(2, dut.datapath.rf.regs[3].value, f'failed at cycle {dut.datapath.cycles_current.value.integer}')

@cocotb.test(skip='RVTEST_ALUBR' in os.environ)
async def testDivDivUse(dut):
    "Run div + dependent div insn"
    axil_imem, _ = await preTestSetup(dut)
    riscv_binary_utils.asm(axil_imem, '''
        li x8,0x8
        li x2,0x2
        div x4,x8,x2
        div x1,x4,x2
        ''')

    await ClockCycles(dut.clk, 40)
    assertEquals(4, dut.datapath.rf.regs[4].value, f'failed at cycle {dut.datapath.cycles_current.value.integer}')
    assertEquals(2, dut.datapath.rf.regs[1].value, f'failed at cycle {dut.datapath.cycles_current.value.integer}')


@cocotb.test(skip='RVTEST_ALUBR' in os.environ)
async def testTraceRvLw(dut):
    "Use the LW riscv-test with trace comparison"
    await riscvTest(dut, cu.RISCV_TESTS_PATH / 'rv32ui-p-lw', TRACING_MODE)

# tracingMode argument is one of `generate`, `compare` or None
async def riscvTest(dut, binaryPath=None, tracingMode=None):
    "Run the official RISC-V test whose binary lives at `binaryPath`"
    assert binaryPath is not None
    assert binaryPath.exists(), f'Could not find RV test binary {binaryPath}, have you built riscv-tests?'
    axil_imem, _ = await preTestSetup(dut)
    riscv_binary_utils.loadBinaryIntoMemory(axil_imem, binaryPath)

    trace = []
    if tracingMode == 'compare':
        # use ../ since we run from the sim_build directory
        with open(f'../trace-{binaryPath.name}.json', 'r', encoding='utf-8') as f:
            trace = json.load(f)
            pass
        pass

    dut._log.info(f'Running RISC-V test at {binaryPath} with tracingMode == {tracingMode}')
    for cycles in range(TIMEOUT_CYCLES):
        await RisingEdge(dut.clk)

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
    cu.RISCV_TESTS_PATH / 'rv32ui-p-simple', # test numbers start at 1
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

    cu.RISCV_TESTS_PATH / 'rv32ui-p-lw', # 31
    cu.RISCV_TESTS_PATH / 'rv32ui-p-lh',
    cu.RISCV_TESTS_PATH / 'rv32ui-p-lhu',
    cu.RISCV_TESTS_PATH / 'rv32ui-p-lb',
    cu.RISCV_TESTS_PATH / 'rv32ui-p-lbu',
    
    cu.RISCV_TESTS_PATH / 'rv32ui-p-sw', # 36
    cu.RISCV_TESTS_PATH / 'rv32ui-p-sh',
    cu.RISCV_TESTS_PATH / 'rv32ui-p-sb',

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
    # cu.RISCV_TESTS_PATH / 'rv32ui-p-fence_i', # 39
    # misaligned accesses
    # cu.RISCV_TESTS_PATH / 'rv32ui-p-ma_data',
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
    axil_imem, _ = await preTestSetup(dut)
    riscv_binary_utils.loadBinaryIntoMemory(axil_imem, dsBinary)

    trace = []
    if tracingMode == 'compare':
        # use ../ since we run from the sim_build directory
        with open(f'../trace-{dsBinary.name}.json', 'r', encoding='utf-8') as f:
            trace = json.load(f)
            pass
        pass

    dut._log.info(f'Running Dhrystone benchmark (takes 255k cycles)... with tracingMode == {tracingMode}')
    for cycles in range(280_000):
        await RisingEdge(dut.clk)

        cu.handleTrace(dut, trace, cycles, tracingMode)
        if cycles > 0 and 0 == cycles % 10_000:
            dut._log.warning(f'ran {int(cycles/1000)}k cycles...')
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
