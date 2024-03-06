import cocotb
import json
import os
import shutil
import subprocess

from pathlib import Path
from cocotb.clock import Clock
from cocotb.regression import TestFactory
from cocotb.result import SimTimeoutError
from cocotb.runner import get_runner, get_results
from cocotb.triggers import RisingEdge, ClockCycles
from cocotb.triggers import Timer

import sys

p = Path.cwd() / '..' / 'common' / 'python'
sys.path.append(str(p))
import riscv_binary_utils

# directory where our simulator will compile our tests + code
SIM_BUILD_DIR = "sim_build"

# temporary file used to hold assembler output
TEMP_MACHINE_CODE_FILE = ".tmp.riscv.o"

# offset to map from standard Linux/ELF addresses to what our processor's memory uses
BIN_2_MEMORY_ADDRESS_OFFSET = 0x80000000

# assembler program
ASSEMBLER = 'riscv64-unknown-elf-as'

# readelf program
READELF = 'riscv64-unknown-elf-readelf'

RISCV_TESTS_PATH = Path('../../riscv-tests/isa')
RISCV_BENCHMARKS_PATH = Path('../../riscv-tests/benchmarks')

TIMEOUT_CYCLES = 1_000

def asm(dut, assemblyCode):
    """Assembles the given RISC-V code, returning the machine code as a list of numbers"""

    # avoid assembler warning about missing trailing newline
    if not assemblyCode.endswith('\n'):
        assemblyCode += '\n'
        pass

    # Use subprocess to run the assembler command
    command = [ASSEMBLER, "-march=rv32im", "-o", TEMP_MACHINE_CODE_FILE]
    process = subprocess.run(command, input=assemblyCode, capture_output=True, text=True, check=False)
    if process.returncode != 0:
        dut._log.error(f"Error: {process.stderr}")
        process.check_returncode() # throws
        pass

    loadBinaryIntoMemory(dut, TEMP_MACHINE_CODE_FILE)

def loadBinaryIntoMemory(dut, binaryPath):
    """Read the given binary's sections, and load them into memory at the appropriate addresses."""
    
    sectionInfo = riscv_binary_utils.getSectionInfo(binaryPath)
    #dut._log.info(sectionInfo)
    sectionsToLoad = ['.text.init','.text','.text.startup','.data','.tohost','.rodata','.rodata.str1.4','.sbss','.bss','.tbss']

    for sectionName in sectionsToLoad:
        if sectionName not in sectionInfo:
            continue
        offset = sectionInfo[sectionName]['offset']
        length = sectionInfo[sectionName]['size']
        words = riscv_binary_utils.extractDataFromBinary(binaryPath, offset, length + (length % 4))
        memBaseAddr = sectionInfo[sectionName]['address']
        if memBaseAddr >= BIN_2_MEMORY_ADDRESS_OFFSET:
            memBaseAddr -= BIN_2_MEMORY_ADDRESS_OFFSET
            pass
        memBaseAddr >>= 2 # convert to word address
        dut._log.info(f"loading {sectionName} section ({len(words)} words) into memory starting at 0x{memBaseAddr:x}")
        for i in range(len(words)):
            dut.mem.mem[memBaseAddr + i].value = words[i]
            pass
        pass
    pass


def oneTimeSetup():
    """This runs once, before any of the tests. Performs global setup."""

    # check that tools are accessible
    assert shutil.which(ASSEMBLER) is not None, f"Couldn't find assembler program {ASSEMBLER}"
    assert shutil.which(READELF) is not None, f"Couldn't find readelf program {READELF}"
    assert RISCV_TESTS_PATH.relative_to('..').exists(), f"Couldn't read riscv-tests from {RISCV_TESTS_PATH}"
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

async def preTestSetup(dut):
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
    await ClockCycles(dut.clock_proc, 2)
    # lower `rst` signal
    dut.rst.value = 0
    # design should be reset now
    return

def runCocotbTests(pytestconfig):
    """setup cocotb tests, based on https://docs.cocotb.org/en/stable/runner.html"""

    hdl_toplevel_lang = os.getenv("HDL_TOPLEVEL_LANG", "verilog")
    sim = os.getenv("SIM", "verilator")
    proj_path = Path(__file__).resolve().parent
    assert hdl_toplevel_lang == "verilog"
    verilog_sources = [ proj_path / "DatapathMultiCycle.sv" ]
    toplevel_module = "RiscvProcessor"

    try:
        runr = get_runner(sim)
        runr.build(
            verilog_sources=verilog_sources,
            vhdl_sources=[],
            hdl_toplevel=toplevel_module,
            includes=[proj_path],
            build_dir=SIM_BUILD_DIR,
            always=True,
            # NB: --trace-max-array must be the size of the memory (in 4B words) for memory to appear in the waveforms
            build_args=['--assert','--trace','--trace-fst','--trace-structs','--trace-max-array',str(2**18)]
        )

        oneTimeSetup()

        runr.test(
            seed=12345,
            waves=True,
            hdl_toplevel=toplevel_module, 
            test_module=Path(__file__).stem, # use tests from this file
            results_xml='multicycle_datapath.results.xml',
            testcase=pytestconfig.option.tests, # filter tests via the `--tests` command-line flag
        )
    finally:
        pointsEarned = 0
        pointsPossible = 0
        div_path = Path(SIM_BUILD_DIR,'runCocotbTests.divider_pipelined.results.xml')
        proc_path = Path(SIM_BUILD_DIR,'runCocotbTests.multicycle_datapath.results.xml')
        if div_path.exists() and proc_path.exists():
            div_total_failed = get_results(div_path)
            proc_total_failed = get_results(proc_path)
            # 1 point per test
            pointsEarned += (div_total_failed[0] - div_total_failed[1]) + (proc_total_failed[0] - proc_total_failed[1])
            pointsPossible = div_total_failed[0] + proc_total_failed[0]
            pass
        points = { 'pointsEarned': pointsEarned, 'pointsPossible': pointsPossible }
        with open('points.json', 'w') as f:
            json.dump(points, f, indent=2)
            pass
        pass


if __name__ == "__main__":
    runCocotbTests()
    pass



########################
## TEST CASES GO HERE ##
########################

@cocotb.test()
async def testLui(dut):
    "Run one lui insn"
    asm(dut, 'lui x1,0x12345')
    await preTestSetup(dut)

    await ClockCycles(dut.clock_proc, 2)
    assert dut.datapath.rf.regs[1].value == 0x12345000, f'failed at cycle {dut.datapath.cycles_current.value.integer}'

@cocotb.test()
async def testLuiAddi(dut):
    "Run two insns to check PC incrementing"
    asm(dut, '''
        lui x1,0x12345
        addi x1,x1,0x678''')
    await preTestSetup(dut)

    await ClockCycles(dut.clock_proc, 3)
    assert dut.datapath.rf.regs[1].value == 0x12345678, f'failed at cycle {dut.datapath.cycles_current.value.integer}'

@cocotb.test()
async def testDivu(dut):
    "Run divu insn"
    asm(dut, '''
        lui x1,0x12345
        divu x2,x1,x1''')
    await preTestSetup(dut)

    await ClockCycles(dut.clock_proc, 4)
    assert dut.datapath.rf.regs[2].value == 1, f'failed at cycle {dut.datapath.cycles_current.value.integer}'

@cocotb.test()
async def test2Divu(dut):
    "Run back-to-back divu insns"
    asm(dut, '''
        li x16,16
        li x8,8
        li x2,2
        divu x3,x16,x2
        divu x3,x8,x2''')
    await preTestSetup(dut)

    await ClockCycles(dut.clock_proc, 6)
    assert dut.datapath.rf.regs[3].value == 8, f'failed at cycle {dut.datapath.cycles_current.value.integer}'
    await ClockCycles(dut.clock_proc, 2)
    assert dut.datapath.rf.regs[3].value == 4, f'failed at cycle {dut.datapath.cycles_current.value.integer}'

@cocotb.test()
async def testDivuEtAl(dut):
    "Run back-to-back divu insns"
    asm(dut, '''
        li x16,16
        li x2,2
        divu x8,x16,x2
        addi x9,x8,1''')
    await preTestSetup(dut)

    # Since divu takes 2 cycles, li,li,divu takes 4 cycles to complete
    # and result is available in the 5th cycle.
    await ClockCycles(dut.clock_proc, 5)
    assert dut.datapath.rf.regs[8].value == 8, f'failed at cycle {dut.datapath.cycles_current.value.integer}'
    await ClockCycles(dut.clock_proc, 1) # wait one more cycle for addi's result
    assert dut.datapath.rf.regs[9].value == 9, f'failed at cycle {dut.datapath.cycles_current.value.integer}'

@cocotb.test()
async def testEcall(dut):
    "ecall insn causes processor to halt"
    asm(dut, '''
        lui x1,0x12345
        ecall''')
    await preTestSetup(dut)

    await ClockCycles(dut.clock_proc, 2) # check for halt *during* ecall, not afterwards
    assert dut.datapath.halt.value == 1, f'failed at cycle {dut.datapath.cycles_current.value.integer}'
    pass

@cocotb.test(skip='RVTEST_ALUBR' in os.environ)
async def dhrystone(dut):
    "Run dhrystone benchmark from riscv-tests"
    dsBinary = RISCV_BENCHMARKS_PATH / 'dhrystone.riscv' 
    assert dsBinary.exists(), f'Could not find Dhrystone binary {dsBinary}, have you built riscv-tests?'
    loadBinaryIntoMemory(dut, dsBinary)
    await preTestSetup(dut)

    dut._log.info(f'Running Dhrystone benchmark (takes 193k cycles)...')
    for cycles in range(210_000):
        await RisingEdge(dut.clock_proc)
        if cycles > 0 and 0 == cycles % 10_000:
            dut._log.info(f'ran {int(cycles/1000)}k cycles...')
            pass
        if dut.halt.value == 1:
            # there are 22 output checks, each sets 1 bit
            expectedValue = (1<<22) - 1
            assert expectedValue == dut.datapath.rf.regs[5].value.integer
            latency_millis = (cycles / 10_000_000) * 1000
            dut._log.info(f'dhrystone passed after {cycles} cycles, {latency_millis} milliseconds with 10MHz clock')
            return
        pass
    raise SimTimeoutError()

async def riscvTest(dut, binaryPath=None):
    "Run the official RISC-V test whose binary lives at `binaryPath`"
    assert binaryPath is not None
    assert binaryPath.exists(), f'Could not find RV test binary {binaryPath}, have you built riscv-tests?'
    loadBinaryIntoMemory(dut, binaryPath)
    await preTestSetup(dut)

    dut._log.info(f'Running RISC-V test at {binaryPath}')
    for cycles in range(TIMEOUT_CYCLES):
        await RisingEdge(dut.clock_proc)
        if dut.halt.value == 1:
            # see RVTEST_PASS and RVTEST_FAIL macros in riscv-tests/env/p/riscv_test.h
            assert 93 == dut.datapath.rf.regs[17].value.integer # magic value from pass/fail functions
            resultCode = dut.datapath.rf.regs[10].value.integer
            assert 0 == resultCode, f'failed test {resultCode >> 1} at cycle {dut.datapath.cycles_current.value.integer}'
            return
        pass
    raise SimTimeoutError()

RV_TEST_BINARIES = [
    RISCV_TESTS_PATH / 'rv32ui-p-simple', # 1
    RISCV_TESTS_PATH / 'rv32ui-p-lui',
    
    RISCV_TESTS_PATH / 'rv32ui-p-and', # 3
    RISCV_TESTS_PATH / 'rv32ui-p-or',
    RISCV_TESTS_PATH / 'rv32ui-p-xor',
    RISCV_TESTS_PATH / 'rv32ui-p-sll',
    RISCV_TESTS_PATH / 'rv32ui-p-sra',
    RISCV_TESTS_PATH / 'rv32ui-p-srl',
    RISCV_TESTS_PATH / 'rv32ui-p-slt',
    RISCV_TESTS_PATH / 'rv32ui-p-add',
    RISCV_TESTS_PATH / 'rv32ui-p-sub',
    
    RISCV_TESTS_PATH / 'rv32ui-p-andi', # 12
    RISCV_TESTS_PATH / 'rv32ui-p-ori',
    RISCV_TESTS_PATH / 'rv32ui-p-slli',
    RISCV_TESTS_PATH / 'rv32ui-p-srai',
    RISCV_TESTS_PATH / 'rv32ui-p-srli',
    RISCV_TESTS_PATH / 'rv32ui-p-xori',
    RISCV_TESTS_PATH / 'rv32ui-p-slti',
    RISCV_TESTS_PATH / 'rv32ui-p-sltiu',
    RISCV_TESTS_PATH / 'rv32ui-p-sltu',
    RISCV_TESTS_PATH / 'rv32ui-p-addi',
    
    RISCV_TESTS_PATH / 'rv32ui-p-beq', # 22
    RISCV_TESTS_PATH / 'rv32ui-p-bge',
    RISCV_TESTS_PATH / 'rv32ui-p-bgeu',
    RISCV_TESTS_PATH / 'rv32ui-p-blt',
    RISCV_TESTS_PATH / 'rv32ui-p-bltu',
    RISCV_TESTS_PATH / 'rv32ui-p-bne',

    RISCV_TESTS_PATH / 'rv32ui-p-jal', # 28
    RISCV_TESTS_PATH / 'rv32ui-p-jalr',
    RISCV_TESTS_PATH / 'rv32ui-p-auipc', # needs JAL

    RISCV_TESTS_PATH / 'rv32ui-p-lb', # 31
    RISCV_TESTS_PATH / 'rv32ui-p-lbu',
    RISCV_TESTS_PATH / 'rv32ui-p-lh',
    RISCV_TESTS_PATH / 'rv32ui-p-lhu',
    RISCV_TESTS_PATH / 'rv32ui-p-lw',
    
    RISCV_TESTS_PATH / 'rv32ui-p-sb', # 36
    RISCV_TESTS_PATH / 'rv32ui-p-sh',
    RISCV_TESTS_PATH / 'rv32ui-p-sw',

    # self-modifying code and fence.i insn
    RISCV_TESTS_PATH / 'rv32ui-p-fence_i', # 39

    RISCV_TESTS_PATH / 'rv32um-p-mul', # 40
    RISCV_TESTS_PATH / 'rv32um-p-mulh',
    RISCV_TESTS_PATH / 'rv32um-p-mulhsu',
    RISCV_TESTS_PATH / 'rv32um-p-mulhu',
    RISCV_TESTS_PATH / 'rv32um-p-div', # 44
    RISCV_TESTS_PATH / 'rv32um-p-divu',
    RISCV_TESTS_PATH / 'rv32um-p-rem',
    RISCV_TESTS_PATH / 'rv32um-p-remu',

    # misaligned accesses, we don't support these
    #RISCV_TESTS_PATH / 'rv32ui-p-ma_data',
]

rvTestFactory = TestFactory(test_function=riscvTest)
if 'RVTEST_ALUBR' in os.environ:
    RV_TEST_BINARIES = RV_TEST_BINARIES[:27]
    pass
rvTestFactory.add_option(name='binaryPath', optionlist=RV_TEST_BINARIES)
rvTestFactory.generate_tests()
