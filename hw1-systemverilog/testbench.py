import cocotb, json, os

from pathlib import Path
from cocotb.runner import get_runner, get_results
from cocotb.triggers import Timer

# directory where our simulator will compile our tests + code
SIM_BUILD_DIR = "sim_build"


def runCocotbTests(pytestconfig):
    """setup cocotb tests, based on https://docs.cocotb.org/en/stable/runner.html"""

    hdl_toplevel_lang = os.getenv("HDL_TOPLEVEL_LANG", "verilog")
    sim = os.getenv("SIM", "verilator")
    proj_path = Path(__file__).resolve().parent
    assert hdl_toplevel_lang == "verilog"
    verilog_sources = [proj_path / "rca.sv" ]

    # by default, run all tests
    all_tests = ["halfadder", "fulladder", "fulladder2", "rca4"]
    tests_to_run = all_tests

    if pytestconfig.option.tests != "":
        tests_to_run = []
        # filter the tests to run
        tests_requested = pytestconfig.option.tests.split(",")
        for tr in tests_requested:
            assert tr in all_tests, f'Invalid test "{tr}" requested, expecting a comma-separated list from {all_tests}'
            tests_to_run.append(tr)
            pass
        pass

    pointsEarned = 0
    try:
        for top_module in tests_to_run:
            runr = get_runner(sim)
            runr.build(
                verilog_sources=verilog_sources,
                vhdl_sources=[],
                hdl_toplevel=top_module,
                includes=[proj_path],
                build_dir=SIM_BUILD_DIR,
                always=True,
                build_args=['--assert','-Wall','-Wno-DECLFILENAME','--trace','--trace-fst','--trace-structs']
            ),

            results_file = runr.test(
                seed=12345,
                waves=True,
                hdl_toplevel=top_module, 
                test_module="testbench",
                testcase="test_"+top_module,
            )
            total_failed = get_results(results_file)
            # 1 point per test
            pointsEarned += total_failed[0] - total_failed[1]
            pass
    finally:
        points = { 'pointsEarned': pointsEarned, 'pointsPossible': len(all_tests) }
        with open('points.json', 'w') as f:
            json.dump(points, f, indent=2)
            pass
        pass


if __name__ == "__main__":
    runCocotbTests()
    pass


#########################
## TEST CASES ARE HERE ##
#########################

@cocotb.test()
async def test_halfadder(dut):
    for a in [0,1]:
        for b in [0,1]:
            await Timer(1, "ns")
            dut.a.value = a
            dut.b.value = b
            await Timer(1, "ns")
            if a == 0 and b == 0:
                # 0 + 0 == 0
                assert 0 == dut.s.value
                assert 0 == dut.cout.value
            elif a == 1 and b == 1:
                # 1 + 1 == 2'b10
                assert 0 == dut.s.value
                assert 1 == dut.cout.value
            else:
                # 1+0 (or 0+1) == 1
                assert 1 == dut.s.value
                assert 0 == dut.cout.value
                pass
            pass
        pass
    pass

@cocotb.test()
async def test_fulladder(dut):
    for a in [0,1]:
        for b in [0,1]:
            for c in [0,1]:
                await Timer(1, "ns")
                dut.a.value = a
                dut.b.value = b
                dut.cin.value = c
                await Timer(1, "ns")
                sum = a + b + c
                if 0 == sum:
                    assert 0 == dut.s.value
                    assert 0 == dut.cout.value
                elif 1 == sum:
                    assert 1 == dut.s.value
                    assert 0 == dut.cout.value
                elif 2 == sum:
                    assert 0 == dut.s.value
                    assert 1 == dut.cout.value
                else:
                    assert 1 == dut.s.value
                    assert 1 == dut.cout.value
                    pass
                pass
            pass
        pass
    pass

@cocotb.test()
async def test_fulladder2(dut):
    for a in range(4):
        for b in range(4):
            for c in [0,1]:
                await Timer(1, "ns")
                dut.a.value = a
                dut.b.value = b
                dut.cin.value = c
                await Timer(1, "ns")
                expected_sum = a + b + c
                actual_sum = dut.s.value + (dut.cout.value << 2)
                assert expected_sum == actual_sum, f'expected {a}+{b}+{c} == {expected_sum} but it was {dut.s.value} + {dut.cout.value} == {actual_sum}'
                pass
            pass
        pass
    pass

@cocotb.test()
async def test_rca4(dut):
    for a in range(16):
        for b in range(16):
            for c in [0,1]:
                await Timer(1, "ns")
                dut.SWITCH.value = a + (b << 4)
                await Timer(1, "ns")
                expected_sum = (a + b) & 0x0F # truncate to 4 bits
                actual_sum = dut.LED.value
                assert expected_sum == actual_sum, f'expected {a}+{b} == {expected_sum} but it was {actual_sum}'
                pass
            pass
        pass
    pass