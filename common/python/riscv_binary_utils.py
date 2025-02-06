from pathlib import Path
import subprocess
import re
import shutil
import sys
import logging
import cocotb, cocotbext

# readelf program
READELF = 'riscv64-unknown-elf-readelf'

# assembler program
ASSEMBLER = 'riscv64-unknown-elf-as'

# temporary file used to hold assembler output
TEMP_MACHINE_CODE_FILE = ".tmp.riscv.o"

# offset to map from standard Linux/ELF addresses to what our processor's memory uses
BIN_2_MEMORY_ADDRESS_OFFSET = 0x80000000

assert shutil.which(ASSEMBLER) is not None, f"Couldn't find assembler program {ASSEMBLER}"
assert shutil.which(READELF) is not None, f"Couldn't find readelf program {READELF}"

LOG = logging.getLogger('riscv_binary_utils')
LOG.setLevel(logging.INFO)

def asm(dut, assemblyCode):
    """Assembles the given RISC-V code, and loads it into memory via cocotb"""

    # avoid assembler warning about missing trailing newline
    if not assemblyCode.endswith('\n'):
        assemblyCode += '\n'
        pass

    # Use subprocess to run the assembler command
    command = [ASSEMBLER, "-march=rv32im", "-o", TEMP_MACHINE_CODE_FILE]
    process = subprocess.run(command, input=assemblyCode, capture_output=True, text=True, check=False)
    if process.returncode != 0:
        LOG.error(f"Error: {process.stderr}")
        process.check_returncode() # throws
        pass

    loadBinaryIntoMemory(dut, TEMP_MACHINE_CODE_FILE)

def loadBinaryIntoMemory(dut, binaryPath):
    """Read the given binary's sections, and load them into memory at the appropriate addresses."""
    
    sectionInfo = getSectionInfo(binaryPath)
    sectionsToLoad = ['.text.init','.text','.text.startup','.data','.tohost','.rodata','.rodata.str1.4','.sbss','.bss','.tbss']

    for sectionName in sectionsToLoad:
        if sectionName not in sectionInfo:
            continue
        offset = sectionInfo[sectionName]['offset']
        length = sectionInfo[sectionName]['size']
        words = extractDataFromBinary(binaryPath, offset, length + (length % 4))
        memBaseAddr = sectionInfo[sectionName]['address']
        if memBaseAddr >= BIN_2_MEMORY_ADDRESS_OFFSET:
            memBaseAddr -= BIN_2_MEMORY_ADDRESS_OFFSET
            pass
        if isinstance(dut, cocotb.handle.HierarchyObject):
            memBaseAddr >>= 2 # convert to word address
            pass
        LOG.info(f"loading {sectionName} section ({len(words)} words) into memory starting at 0x{memBaseAddr:x}")
        for i in range(len(words)):
            if isinstance(dut, cocotb.handle.HierarchyObject):
                # NB: doesn't work if we try to pass dut.memory.mem_array as an argument, need top-level dut
                dut.memory.mem_array[memBaseAddr + i].value = words[i]
            elif isinstance(dut, cocotbext.axi.axil_ram.AxiLiteRam):
                dut.write_dword(memBaseAddr + (i*4), words[i])
            else:
                assert False, f"cannot load into memory of type {type(dut)}"
            pass
        pass
    pass

def loadBinaryIntoHexFile(binaryPath, hexfilePath, maxWords=0):
    """Read the given binary's sections, and write them out to a file for $readmemh"""
    
    sectionInfo = getSectionInfo(binaryPath)
    # print(sectionInfo)
    sectionsToLoad = ['.start', '.text', '.rodata', '.eh_frame']

    with open(hexfilePath,'w') as fd:
        micByteOffset = 0

        for sectionName in sectionsToLoad:
            if sectionName not in sectionInfo:
                continue
            offset = sectionInfo[sectionName]['offset']
            length = sectionInfo[sectionName]['size']
            words = extractDataFromBinary(binaryPath, offset, length + (length % 4))
            # if sectionName == '.rodata':
            #     print(['0x%x' % w for w in words])
            #     pass
            memBaseAddr = sectionInfo[sectionName]['address']
            if memBaseAddr + len(words) > maxWords:
                print(f"code reaches address {memBaseAddr + len(words)} but we can only handle up to {maxWords}")
                sys.exit(1)

            print(f"loading {sectionName} section ({len(words)} words) into memory starting at 0x{memBaseAddr:x}")
            if memBaseAddr > 0 and memBaseAddr != micByteOffset:
                fd.write(f'@{memBaseAddr:x}\n')
                pass
            for i in range(len(words)):
                fd.write(f'{words[i]:08x}\n')
                micByteOffset += 4
                pass
            pass
        pass
    pass

def getSectionInfo(binaryPath):
    """Returns information about the sections in the binary given at `binaryPath`. Returns a dictionary with
     a key for each section name. The values are also dicts containing information (offset, size, etc) for that section."""
    bp = Path(binaryPath)
    assert bp.exists(), bp
    cmd = [READELF,'--wide','--sections',bp]
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

def binaryToHex(binPath):
    sectionInfo = getSectionInfo(binPath)
    sectionsToLoad = ['.text']

    # TODO: multiple sections won't be contiguous in the hexfile, could use @address markers...

    for sectionName in sectionsToLoad:
        if sectionName not in sectionInfo:
            continue
        offset = sectionInfo[sectionName]['offset']
        length = sectionInfo[sectionName]['size']
        words = extractDataFromBinary(binPath, offset, length + (length % 4))
        for w in words:
            print(format(w, '08x'))
            pass
        pass

if __name__ == '__main__':
    binaryToHex(Path(sys.argv[1]))
    pass
