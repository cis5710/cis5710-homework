"""This is run by the autograder before the tests, to determine if the
submission is valid. We check, e.g., if any disallowed SystemVerilog
operators were used. See common/python/main_codecheck.py."""

from pathlib import Path
import sys

p = Path.cwd() / '..' / 'common' / 'python'
sys.path.append(str(p))
import main_codecheck

def objectIsLegal(filename, obj):
    """Returns a tuple. First parameter is True if this object describes a legal code construct, False if an illegal one. 
Second parameter is True if we should continue to iterate into descendent objects, False if we should not."""
    
    if 'tag' not in obj:
        return (True,True)
    tag = obj['tag']
    text = obj.get('text', None)
    if (tag == "SystemTFIdentifier" and text == "$fopen") or tag == "+":
        return (False,True)
    return (True,True)

main_codecheck.runCodecheck(objectIsLegal, ['rca.sv'])
