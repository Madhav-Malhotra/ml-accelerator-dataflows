"""
 * Copyright (c) 2024 WAT.ai Chip Team
 * Author: Mariam El-Sahhar
 * SPDX-License-Identifier: Apache-2.0
 * Tests arbiter for output stationary dataflow
 * (spec: https://docs.google.com/document/d/1bwynsWdD87AS_AJQEDSaEcCtV5cUac0pMMwL_9xpX6k/edit?tab=t.0#heading=h.qnfirgtr5osr)
"""

import json
import cocotb
from cocotb.clock import Clock
from cocotb.triggers import RisingEdge, Timer
from cocotb.binary import BinaryValue

# Load parameters from parameters.json
with open("parameters.json") as f:
    params = json.load(f)

# Extract NUM_CORES from parameters
NUM_CORES = params.get("OUT_ARB_NUM_CORES")
COCOTB_CLOCK = params["COCOTB_CLOCK_NS"]


# Helper functions
def msb(n: int) -> int:
    if n == 0:
        return 0
    msb_value = 1 << (n.bit_length() - 1)
    return msb_value


class ArbiterDriver:
    def __init__(self, dut):
        self.dut = dut
        self.clock = Clock(dut.w_clock, COCOTB_CLOCK, units="ns")
        cocotb.start_soon(self.clock.start())

    async def reset(self):
        self.dut.w_ready.value = 0
        await RisingEdge(self.dut.w_clock)
        await Timer(1, units="ns")
        self.dut.w_ready.value = 1
        await RisingEdge(self.dut.w_clock)
        await Timer(1, units="ns")

    async def drive_requests(self, requests: str | int):
        """
        Drive the request signal with the correct width.
        """
        if isinstance(requests, str):
            # Convert binary string to integer
            requests = int(requests, 2)

        # Mask to ensure correct width
        self.dut.w_req.value = requests & ((1 << NUM_CORES) - 1)
        await RisingEdge(self.dut.w_clock)
        await Timer(1, units="ns")  # Tiny delay for r_state non-blocking update

    async def check_grants(self, expected_grants: int):
        """
        Wait for the grant signal to be asserted and check its value.
        """
        observed_grants = self.dut.r_grant.value.integer
        assert (
            observed_grants == expected_grants
        ), f"Grants mismatch. Expected {expected_grants}, got {observed_grants}"


@cocotb.test()
async def test_round_robin_arbitration(dut):
    arbiter = ArbiterDriver(dut)

    # Why is the i = 0 case working?
    # Why did I have to reverse the for loop direction in find_msb?

    for i in range(2**NUM_CORES):
        i_bin = "{0:b}".format(i).zfill(NUM_CORES)
        expected_grant = msb(i)

        # Start test from IDLE
        await arbiter.reset()

        # Drive requests
        await arbiter.drive_requests(i_bin)

        # Wait for r_req to capture w_req
        await RisingEdge(dut.w_clock)
        await Timer(1, units="ns")
        # Wait for r_state to transition to arbitrate
        await RisingEdge(dut.w_clock)
        await Timer(1, units="ns")
        # Grant/sel don't update until end of arbitrate state (transfer state)
        await RisingEdge(dut.w_clock)
        await Timer(1, units="ns")

        await arbiter.check_grants(expected_grant)

    # Test case 5: Rotating priority
    # await arbiter.drive_requests("0011")
    # await arbiter.check_grants(2)  # Wait for grant to be asserted
    # await arbiter.drive_requests("0011")
    # await arbiter.check_grants(1)  # Wait for grant to be asserted


@cocotb.test()
async def test_loading_behavior(dut):
    arbiter = ArbiterDriver(dut)
    await arbiter.reset()

    # Test loading behavior
    await arbiter.drive_requests("0001")
    await arbiter.check_grants(1)  # Wait for grant to be asserted
    await Timer(20, units="ns")  # Simulate some processing time
    await arbiter.drive_requests("0010")
    await arbiter.check_grants(2)  # Wait for grant to be asserted

    # Check if the load register is updated correctly
    assert (
        dut.r_load.value.integer == 3
    ), f"Load register mismatch. Expected 3, got {dut.r_load.value.integer}"


@cocotb.test()
async def test_unloading_behavior(dut):
    arbiter = ArbiterDriver(dut)
    await arbiter.reset()

    # Simulate loading of all cores
    for i in range(NUM_CORES):
        await arbiter.drive_requests(1 << i)
        await arbiter.check_grants(1 << i)  # Wait for grant to be asserted

    # Test unloading behavior
    await arbiter.drive_requests("1" * NUM_CORES)  # Drive all requests
    for i in range(NUM_CORES):
        expected_grant = 1 << ((i + NUM_CORES - 1) % NUM_CORES)  # Rotate priority
        await arbiter.check_grants(expected_grant)  # Wait for grant to be asserted
        await Timer(20, units="ns")  # Simulate some unloading time

    # Check if the load register is updated correctly
    assert (
        dut.r_load.value.integer == 0
    ), f"Load register mismatch after unloading. Expected 0, got {dut.r_load.value.integer}"
