"""This is run by the autograder before the tests, to determine if the
submission is valid. We check, e.g., if any disallowed SystemVerilog
operators were used. See common/python/main_codecheck.py."""

from pathlib import Path
import sys

p = Path.cwd() / '..' / 'common' / 'python'
sys.path.append(str(p))
import main_codecheck

def objectIsLegal(obj):
    "Return true if this object describes a legal code construct, False if an illegal one."
    
    if 'tag' not in obj:
        return True
    tag = obj['tag']
    text = obj.get('text', None)
    if (tag == "SystemTFIdentifier" and text == "$fopen") or tag == "+":
        return False
    return True

main_codecheck.runCodecheck(objectIsLegal)
