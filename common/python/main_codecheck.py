# This is run by the autograder before the tests, to determine if the
# submission is valid. E.g., we check if any disallowed SystemVerilog
# operators were used.

import json, sys, subprocess

# objectIsLegal() returns a tuple.
# First element is True if this object describes a legal code construct, False if an illegal one. 
# Second element is True if we should continue to iterate into descendent objects, False if we should not.

FOUND_ILLEGAL_CODE = False

def traverseSyntaxTree(filename, obj, newlineIndices, objectIsLegal, parent_key=''):
    global FOUND_ILLEGAL_CODE
    if isinstance(obj, dict):

        legalConstruct,descendInto = objectIsLegal(filename, obj)
        if not legalConstruct:
            FOUND_ILLEGAL_CODE = True
            tag = obj['tag']
            text = obj.get('text', None)
            linenum = '??'
            if 'start' in obj:
                linenum = 1 + len([i for i in newlineIndices if i < obj['start']])
                pass
            if text is None:
                print(f'[codecheck] ERROR: found illegal code "{tag}" at line {linenum} of {filename}')
            else:
                print(f'[codecheck] ERROR: found illegal code "{text}" at line {linenum} of {filename}')
                pass
            pass
        if not descendInto:
            return

        for key, value in obj.items():
            traverseSyntaxTree(filename, value, newlineIndices, objectIsLegal, f"{parent_key}.{key}" if parent_key else key)
            pass
    elif isinstance(obj, list):
        for i, item in enumerate(obj):
            traverseSyntaxTree(filename, item, newlineIndices, objectIsLegal, f"{parent_key}[{i}]")
            pass
    else:
        #print(f"{parent_key}: {obj}")
        pass
    pass

# def custom_sort(obj):
#     return sorted(obj.items(), key=lambda x: x[0], reverse=True)

def runCodecheck(objectIsLegal, filesToCheck):
    if len(sys.argv) > 1:
        print(f'usage: {sys.argv[0]}')
        sys.exit(1)

    for filename in filesToCheck:
        parsedFile = f'.{filename}.parsed.json'
        parsedSortedFile = f'.{filename}.parsed.sorted.json'
        try:
            subprocess.run(['bash','-c',f'verible-verilog-syntax --export_json --printtree {filename} > {parsedFile}'], check=True)
        except subprocess.CalledProcessError as e:
            subprocess.run(['bash','-c',f'verible-verilog-syntax {filename}'], check=True)
            pass

        # compute the index of each newline, to convert character offsets to line numbers
        newlineIndices = []
        with open(filename) as svf:
            newlineIndices = [index for index, char in enumerate(svf.read()) if char == '\n']

        with open(parsedFile) as jf:
            syntaxTree = json.load(jf)
            # with open(parsedSortedFile, 'w') as json_file:
            #     json.dump(syntaxTree, json_file, indent=2, sort_keys=True, default=custom_sort)
            #     pass

            traverseSyntaxTree(filename, syntaxTree, newlineIndices, objectIsLegal)
            if FOUND_ILLEGAL_CODE:
                sys.exit(1)
            else:
                print("[codecheck] codecheck ok")
                pass
            pass
        pass

if __name__ == "__main__":
    runCodecheck()
    pass
