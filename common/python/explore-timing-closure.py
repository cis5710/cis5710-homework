import subprocess
import shutil
import re

MMCM_FILE = 'system/mmcm.v'
TIMING_REPORT = 'vivado_output/post_route_timing_summary_report.txt'

# increase frequency to next highest level
def bumpFrequency():
    # Open the file for reading
    with open(MMCM_FILE, 'r') as f:
        lines = f.readlines()
        pass

    # Find the uncommented clock frequency line
    for i, line in enumerate(lines):
        if line.startswith('`define CLOCK_'):
            # comment current line
            lines[i] = '//' + lines[i]
            # uncomment the next line
            lines[i+1] = lines[i+1].replace('//','')
            break
        pass
    pass

    # Write the modified content back to the file
    with open(MMCM_FILE, 'w') as f:
        f.writelines(lines)
        pass
    pass

# returns True if search should continue, False otherwise
def doImpl():
    subprocess.run( ['make','impl'], check=True)

    with open(TIMING_REPORT,'r') as f:
        lines = [l.strip() for l in f.readlines()]
        assert len(lines) > 1, f'{TIMING_REPORT} appears to be empty'
        #print(lines)

        frequency = None
        # get frequency, see timing report snippet below:
# ------------------------------------------------------------------------------------------------
# | Clock Summary
# | -------------
# ------------------------------------------------------------------------------------------------

# Clock                 Waveform(ns)       Period(ns)      Frequency(MHz)
# -----                 ------------       ----------      --------------
# CLOCK_100MHz          {0.000 5.000}      10.000          100.000         
#   clk_mem_clk_wiz_0   {22.727 68.182}    90.909          11.000          
#   clk_proc_clk_wiz_0  {0.000 45.455}     90.909          11.000          
#   clkfbout_clk_wiz_0  {0.000 25.000}     50.000          20.000
        pat = re.compile(r'clk_proc_clk_wiz_0\s+[{][\d. ]+[}]\s+(?P<period>[\d.]+)\s+(?P<frequency>[\d.]+)')
        for l in lines:
            match = pat.match(l)
            if match:
                frequency = match.group('frequency')
                break
            pass
        assert frequency is not None, "Couldn't parse frequency from timing report"

        # see if timing was met
        if 'Timing constraints are not met.' in lines:
            print(f'timing NOT MET at {frequency} MHz')
            shutil.copy(TIMING_REPORT, f'timing-report-NOT-MET-{frequency}.txt')
            return False
        elif 'All user specified timing constraints are met.' in lines:
            print(f'timing met at {frequency} MHz')
            shutil.copy(TIMING_REPORT, f'timing-report-met-{frequency}.txt')
            bumpFrequency()
            return True
        else:
            assert False, "Couldn't read timing report"
        pass
    pass

def main():
    keepGoing = True
    while keepGoing:
        keepGoing = doImpl()
        pass
    print('all done')

if __name__ == "__main__":
    main()
    pass
