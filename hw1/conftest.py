import pytest

def pytest_addoption(parser):
    parser.addoption("--tests", action="store", default="", help="Comma-separated list of cocotb tests to run. Default: run all tests")

def pytest_assertrepr_compare(config, op, left, right):
    # TODO: this isn't working, perhaps because it only intercepts pytest tests, not cocotb tests?
    print(f'pytest_assertrepr_compare hook running:: ${left} ${op} ${right}')
    return ['my custom explanation']
