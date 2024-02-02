import cocotb
import json
import os
import re
import shutil
import subprocess

from pathlib import Path
from cocotb.clock import Clock
from cocotb.regression import TestFactory
from cocotb.result import SimTimeoutError
from cocotb.runner import get_runner, get_results
from cocotb.triggers import RisingEdge, ClockCycles
from cocotb.triggers import Timer

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

TIMEOUT_CYCLES = 1_000

def getSectionInfo(binaryPath):
    """Returns information about the sections in the binary given at `binaryPath`. Returns a dictionary with
     a key for each section name. The values are also dicts containing information (offset, size, etc) for that section."""
    bp = Path(binaryPath)
    assert bp.exists(), bp
    cmd = [READELF,'--sections',bp]
    process = subprocess.run(cmd, capture_output=True, check=False, text=True)
    if process.returncode != 0:
        print(f"Error: {process.stderr}")
        process.check_returncode() # throws
        pass

    section_headers = {}
    header_pattern = re.compile(r'\[\s*(\d+)\]\s+([.]\S+)\s+(\S*)\s+([0-9a-fA-F]+)\s+([0-9a-fA-F]+)\s+([0-9a-fA-F]+)\s+(\S*)')

    for line in process.stdout.splitlines():
        match = header_pattern.search(line)
        if match:
            index, name, type_, addr, offset, size, es = match.groups()
            section_headers[name] = {
                'name': name,
                'type': type_,
                'address': int(addr, 16),
                'offset': int(offset, 16),
                'size': int(size, 16),
                'ES': int(es, 16),
                #'flags': flags,
                #'Lk': int(lk),
                #'Inf': int(inf),
                #'Al': int(al)
            }
            pass
        pass

    return section_headers

def extractDataFromBinary(binaryPath, offset, length):
    """read the given chunk of the binary, returning a list of ints (4B words)"""
    assert 0 == length % 4, f"can only read multiples of 4B words, but section length is {length} bytes"

    with open(binaryPath, 'rb') as file:
        # Seek to the start of the .text section
        file.seek(offset)
        # read the bytes, one 4B word at a time
        words = []
        for _ in range(int(length / 4)):
            insnBytes = file.read(4)
            words.append(int.from_bytes(insnBytes, 'little'))
            pass
        return words

def asm(dut, assemblyCode):
    """Assembles the given RISC-V code, returning the machine code as a list of numbers"""

    # avoid assembler warning about missing trailing newline
    if not assemblyCode.endswith('\n'):
        assemblyCode += '\n'
        pass

    # Use subprocess to run the assembler command
    command = [ASSEMBLER, "-march=rv32i", "-o", TEMP_MACHINE_CODE_FILE]
    process = subprocess.run(command, input=assemblyCode, capture_output=True, text=True, check=False)
    if process.returncode != 0:
        dut._log.error(f"Error: {process.stderr}")
        process.check_returncode() # throws
        pass

    loadBinaryIntoMemory(dut, TEMP_MACHINE_CODE_FILE)

def loadBinaryIntoMemory(dut, binaryPath):
    """Read the given binary's .text and .data sections, and load them into memory at the appropriate addresses."""
    sectionInfo = getSectionInfo(binaryPath)

    # load .text or .text.init section
    textKey = '.text'
    if '.text' in sectionInfo:
        pass
    else:
        assert '.text.init' in sectionInfo, sectionInfo
        textKey = '.text.init'
        pass
    offset = sectionInfo[textKey]['offset']
    length = sectionInfo[textKey]['size']
    words = extractDataFromBinary(binaryPath, offset, length)
    memBaseAddr = sectionInfo[textKey]['address']
    if memBaseAddr >= BIN_2_MEMORY_ADDRESS_OFFSET:
        memBaseAddr -= BIN_2_MEMORY_ADDRESS_OFFSET
        pass
    memBaseAddr >>= 2 # convert to word address
    dut._log.info(f"loading {len(words)} words into memory starting at 0x{memBaseAddr:x}")
    for i in range(len(words)):
        dut.mem.mem[memBaseAddr + i].value = words[i]
        pass

    # load .data section (if it exists)
    if '.data' in sectionInfo:
        offset = sectionInfo['.data']['offset']
        length = sectionInfo['.data']['size']

        words = extractDataFromBinary(binaryPath, offset, length)
        memBaseAddr = sectionInfo['.data']['address']
        if memBaseAddr >= BIN_2_MEMORY_ADDRESS_OFFSET:
            memBaseAddr -= BIN_2_MEMORY_ADDRESS_OFFSET
            pass
        memBaseAddr >>= 2 # convert to word address
        dut._log.info(f"loading {len(words)} words into memory starting at 0x{memBaseAddr:x}")
        for i in range(len(words)):
            dut.mem.mem[memBaseAddr + i].value = words[i]
            pass
        pass


def oneTimeSetup():
    """This runs once, before any of the tests. Performs global setup."""

    # check that tools are accessible
    assert shutil.which(ASSEMBLER) is not None, f"Couldn't find assembler program {ASSEMBLER}"
    assert shutil.which(READELF) is not None, f"Couldn't find readelf program {READELF}"
    assert RISCV_TESTS_PATH.relative_to('..').exists(), f"Couldn't read riscv-tests from {RISCV_TESTS_PATH}"
    pass

async def preTestSetup(dut):
    """Setup the DUT. MUST be called at the start of EACH test."""
    # Create a 2ns period clock on port clk
    clock = Clock(dut.clk, 2, units="ns")
    # Start the clock. Start it low to avoid issues on the first RisingEdge
    cocotb.start_soon(clock.start(start_high=False))
    # wait for first rising edge
    await RisingEdge(dut.clk)

    # raise `rst` signal for 2 cycles
    dut.rst.value = 1
    await ClockCycles(dut.clk, 2)
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
    verilog_sources = [proj_path / "DatapathSingleCycle.sv" ]
    toplevel_module = "RiscvProcessor"

    pointsEarned = 0
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
            testcase=pytestconfig.option.tests, # filter tests via the `--tests` command-line flag
        )
    finally:
        total_failed = get_results(Path(SIM_BUILD_DIR,'runCocotbTests.results.xml'))
        # 1 point per test
        pointsEarned += total_failed[0] - total_failed[1]
        pointsPossible = total_failed[0]     
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

    await ClockCycles(dut.clk, 2)
    assert dut.datapath.rf.reg_outs[1].value == 0x12345000, f'failed at cycle {dut.datapath.cycles_current.value.integer}'

@cocotb.test()
async def testAddi(dut):
    "Run one addi insn"
    asm(dut, 'addi x1,x0,9')
    await preTestSetup(dut)

    await ClockCycles(dut.clk, 2)
    assert dut.datapath.rf.reg_outs[1].value == 9, f'failed at cycle {dut.datapath.cycles_current.value.integer}'

@cocotb.test()
async def testLuiAddi(dut):
    "Run two insns to check PC incrementing"
    asm(dut, '''
        lui x1,0x12345
        addi x1,x1,0x678''')
    await preTestSetup(dut)

    await ClockCycles(dut.clk, 3)
    assert dut.datapath.rf.reg_outs[1].value == 0x12345678, f'failed at cycle {dut.datapath.cycles_current.value.integer}'

@cocotb.test()
async def testAddiAll(dut):
    "Check all immediate values for addi x1,x0,IMM"
    code = ""
    for imm in range(-2048,2047):
        code += f'addi x1,x0,{imm}\n'
        pass
    asm(dut, code)
    await preTestSetup(dut)
    await RisingEdge(dut.clk)

    for imm in range(-2048,2047):
        await RisingEdge(dut.clk)
        expected = imm & 0xFFFFFFFF # convert to unsigned, to match cocotb
        assert expected == dut.datapath.rf.reg_outs[1].value.integer, f'failed at cycle {dut.datapath.cycles_current.value.integer} with imm = {imm}'
        pass
    pass

@cocotb.test()
async def testBneNotTaken(dut):
    "bne which is not taken"
    asm(dut, '''
        lui x1,0x12345
        bne x0,x0,target
        lui x1,0x54321
        target: lui x0,0''')
    await preTestSetup(dut)

    await ClockCycles(dut.clk, 4)
    assert dut.datapath.rf.reg_outs[1].value == 0x54321000, f'failed at cycle {dut.datapath.cycles_current.value.integer}'
    pass

@cocotb.test()
async def testBeqNotTaken(dut):
    "beq which is not taken"
    asm(dut, '''
        lui x1,0x12345
        beq x1,x0,target
        lui x1,0x54321
        target: lui x0,0''')
    await preTestSetup(dut)

    await ClockCycles(dut.clk, 4)
    assert dut.datapath.rf.reg_outs[1].value == 0x54321000, f'failed at cycle {dut.datapath.cycles_current.value.integer}'
    pass

@cocotb.test()
async def testBneTaken(dut):
    "bne which is taken"
    asm(dut, '''
        lui x1,0x12345
        bne x1,x0,target
        lui x1,0x54321
        target: lui x0,0''')
    await preTestSetup(dut)

    await ClockCycles(dut.clk, 4)
    assert dut.datapath.rf.reg_outs[1].value == 0x12345000, f'failed at cycle {dut.datapath.cycles_current.value.integer}'
    pass

@cocotb.test()
async def testEcall(dut):
    "ecall insn causes processor to halt"
    asm(dut, '''
        lui x1,0x12345
        ecall''')
    await preTestSetup(dut)

    await ClockCycles(dut.clk, 2) # check for halt *during* ecall, not afterwards
    assert dut.datapath.halt.value == 1, f'failed at cycle {dut.datapath.cycles_current.value.integer}'
    pass

@cocotb.test()
async def testOneRiscvTest(dut):
    "Use this to run one particular riscv test"
    await riscvTest(dut, RISCV_TESTS_PATH / 'rv32ui-p-simple')

async def riscvTest(dut, binaryPath=None):
    "Run the official RISC-V test whose binary lives at `binaryPath`"
    assert binaryPath is not None
    assert binaryPath.exists(), f'Could not find RV test binary {binaryPath}, have you built riscv-tests?'
    loadBinaryIntoMemory(dut, binaryPath)
    await preTestSetup(dut)

    dut._log.info(f'Running RISC-V test at {binaryPath}')
    for cycles in range(TIMEOUT_CYCLES):
        await RisingEdge(dut.clk)
        if dut.halt.value == 1:
            # see RVTEST_PASS and RVTEST_FAIL macros in riscv-tests/env/p/riscv_test.h
            assert 93 == dut.datapath.rf.reg_outs[17].value.integer # magic value from pass/fail functions
            resultCode = dut.datapath.rf.reg_outs[10].value.integer
            assert 0 == resultCode, f'failed test {resultCode >> 1} at cycle {dut.datapath.cycles_current.value.integer}'
            return
        pass
    raise SimTimeoutError()

# NB: this test is only for HW3B
@cocotb.test()
async def storeLoad(dut):
    "Check that a load can read a previously-stored value."
    if 'RVTEST_ALUBR' in os.environ:
        return
    asm(dut, '''
        lui x1,0x12345
        sw x1,32(x0) # store x1 to address [32]. NB: code starts at address 0, don't overwrite it!
        lw x2,32(x0) # load address [32] into x2
        ''')
    await preTestSetup(dut)

    await ClockCycles(dut.clk, 4)
    assert dut.datapath.rf.reg_outs[2].value == 0x12345000, f'failed at cycle {dut.datapath.cycles_current.value.integer}'

RV_TEST_BINARIES = [
    RISCV_TESTS_PATH / 'rv32ui-p-simple', # 1
    RISCV_TESTS_PATH / 'rv32ui-p-lui',
    RISCV_TESTS_PATH / 'rv32ui-p-auipc',
    
    RISCV_TESTS_PATH / 'rv32ui-p-and', # 4
    RISCV_TESTS_PATH / 'rv32ui-p-or',
    RISCV_TESTS_PATH / 'rv32ui-p-xor',
    RISCV_TESTS_PATH / 'rv32ui-p-sll',
    RISCV_TESTS_PATH / 'rv32ui-p-sra',
    RISCV_TESTS_PATH / 'rv32ui-p-srl',
    RISCV_TESTS_PATH / 'rv32ui-p-slt',
    RISCV_TESTS_PATH / 'rv32ui-p-add',
    RISCV_TESTS_PATH / 'rv32ui-p-sub',
    
    RISCV_TESTS_PATH / 'rv32ui-p-andi', # 13
    RISCV_TESTS_PATH / 'rv32ui-p-ori',
    RISCV_TESTS_PATH / 'rv32ui-p-slli',
    RISCV_TESTS_PATH / 'rv32ui-p-srai',
    RISCV_TESTS_PATH / 'rv32ui-p-srli',
    RISCV_TESTS_PATH / 'rv32ui-p-xori',
    RISCV_TESTS_PATH / 'rv32ui-p-slti',
    RISCV_TESTS_PATH / 'rv32ui-p-sltiu',
    RISCV_TESTS_PATH / 'rv32ui-p-sltu',
    RISCV_TESTS_PATH / 'rv32ui-p-addi',
    
    RISCV_TESTS_PATH / 'rv32ui-p-beq', # 23
    RISCV_TESTS_PATH / 'rv32ui-p-bge',
    RISCV_TESTS_PATH / 'rv32ui-p-bgeu',
    RISCV_TESTS_PATH / 'rv32ui-p-blt',
    RISCV_TESTS_PATH / 'rv32ui-p-bltu',
    RISCV_TESTS_PATH / 'rv32ui-p-bne',

    RISCV_TESTS_PATH / 'rv32ui-p-jal', # 29
    RISCV_TESTS_PATH / 'rv32ui-p-jalr',

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
    RV_TEST_BINARIES = RV_TEST_BINARIES[:28]
    pass
rvTestFactory.add_option(name='binaryPath', optionlist=RV_TEST_BINARIES)
rvTestFactory.generate_tests()
