

import cocotb
from cocotb.clock import Clock
from cocotb.triggers import RisingEdge, Timer
from cocotb.binary import BinaryValue

class ArbiterDriver:
    def __init__(self, dut):
        self.dut = dut
        self.clock = Clock(dut.clk, 10, units="ns")
        cocotb.start_soon(self.clock.start())

    async def reset(self):
        self.dut.reset.value = 1
        await RisingEdge(self.dut.clk)
        await RisingEdge(self.dut.clk)
        self.dut.reset.value = 0
        await RisingEdge(self.dut.clk)

    async def drive_requests(self, requests):
        self.dut.req_w.value = BinaryValue(requests)
        await RisingEdge(self.dut.clk)

    async def check_grants(self, expected_grants):
        await RisingEdge(self.dut.clk)
        observed_grants = self.dut.grant.value.integer
        assert observed_grants == expected_grants, f"Grants mismatch. Expected {expected_grants}, got {observed_grants}"

@cocotb.test()
async def test_round_robin_arbitration(dut):
    arbiter = ArbiterDriver(dut)
    await arbiter.reset()

    # Test case 1: Single request
    await arbiter.drive_requests("0001")
    await arbiter.check_grants(1)

    # Test case 2: Multiple requests
    await arbiter.drive_requests("0101")
    await arbiter.check_grants(4)

    # Test case 3: All requests
    await arbiter.drive_requests("1111")
    await arbiter.check_grants(8)

    # Test case 4: No requests
    await arbiter.drive_requests("0000")
    await arbiter.check_grants(0)

    # Test case 5: Rotating priority
    await arbiter.drive_requests("0011")
    await arbiter.check_grants(2)
    await arbiter.drive_requests("0011")
    await arbiter.check_grants(1)

@cocotb.test()
async def test_loading_behavior(dut):
    arbiter = ArbiterDriver(dut)
    await arbiter.reset()

    # Test loading behavior
    await arbiter.drive_requests("0001")
    await arbiter.check_grants(1)
    await Timer(20, units="ns")  # Simulate some processing time
    await arbiter.drive_requests("0010")
    await arbiter.check_grants(2)

    # Check if the load register is updated correctly
    assert dut.load.value.integer == 3, f"Load register mismatch. Expected 3, got {dut.load.value.integer}"

@cocotb.test()
async def test_unloading_behavior(dut):
    arbiter = ArbiterDriver(dut)
    await arbiter.reset()

    # Simulate loading of all cores
    for i in range(4):
        await arbiter.drive_requests(1 << i)
        await arbiter.check_grants(1 << i)

    # Test unloading behavior
    await arbiter.drive_requests("1111")
    for i in range(4):
        expected_grant = 1 << ((i + 3) % 4)  # Rotate priority
        await arbiter.check_grants(expected_grant)
        await Timer(20, units="ns")  # Simulate some unloading time

    # Check if the load register is updated correctly
    assert dut.load.value.integer == 0, f"Load register mismatch after unloading. Expected 0, got {dut.load.value.integer}"
