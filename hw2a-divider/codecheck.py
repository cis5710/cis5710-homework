"""This is run by the autograder before the tests, to determine if the
submission is valid. We check, e.g., if any disallowed SystemVerilog
operators were used. See common/python/main_codecheck.py."""

from pathlib import Path
import sys

p = Path.cwd() / '..' / 'common' / 'python'
sys.path.append(str(p))
import main_codecheck

def objectIsLegal(filename, obj):
    
    if 'tag' not in obj:
        return (True,True)
    tag = obj['tag']
    text = obj.get('text', None)
    if tag == "kTimescaleDirective":
        # ignore "/" symbol inside `timescale
        return (True,False)
    if (tag == "SystemTFIdentifier" and text == "$fopen") or tag == "/":
        return (False,True)
    return (True,True)

main_codecheck.runCodecheck(objectIsLegal, ['divider_unsigned.sv'])
