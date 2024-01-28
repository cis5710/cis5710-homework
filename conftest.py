# This adds support for the `--tests` flag to the `pytest-3` command, to filter 
# the set of cocotb tests to run. We place this file here in the root directory
# so that the flag is integrated into the test suites for all homeworks.

import pytest

def pytest_addoption(parser):
    parser.addoption("--tests", action="store", default="", 
                     help="Comma-separated list of cocotb tests to run. Default: run all tests")

def pytest_assertrepr_compare(config, op, left, right):
    # TODO: not working, perhaps because it only intercepts pytest tests, not cocotb tests?
    print(f'pytest_assertrepr_compare hook running:: ${left} ${op} ${right}')
    return ['my custom explanation']
