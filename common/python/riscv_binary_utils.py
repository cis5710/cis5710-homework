from pathlib import Path
import subprocess
import re
import sys

# readelf program
READELF = 'riscv64-unknown-elf-readelf'

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