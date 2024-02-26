# clock period/frequency converter

import sys

args = " ".join(sys.argv[1:]).lower()

if "mhz" in args:
    # frequency to period
    f = float(args.replace("mhz",""))
    p = 1.0 / (f * 1_000_000) # mhz to seconds
    p *= 1_000_000_000 # seconds to nanoseconds
    print(f"period is {p:0.3f} ns")
elif "ns" in args:
    # period to frequency
    p = float(args.replace("ns",""))
    p /= 1_000_000_000 # nanoseconds to seconds
    f = 1.0 / p
    f /= 1_000_000 # Hz to MHz
    print(f"frequency is {f:0.3f} MHz")
    pass
else:
    print(f'Clock frequency <-> clock period converter. Usage: {sys.argv[0]} X mhz or Y ns')
    pass
