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


class ArbiterDriver:
    def __init__(self, dut):
        self.dut = dut
        self.clock = Clock(dut.w_clock, COCOTB_CLOCK, units="ns")
        cocotb.start_soon(self.clock.start())

    async def reset(self):
        self.dut.w_ready.value = 0
        await RisingEdge(self.dut.w_clock)
        await RisingEdge(self.dut.w_clock)
        self.dut.w_ready.value = 1
        await RisingEdge(self.dut.w_clock)

    async def drive_requests(self, requests):
        """
        Drive the request signal with the correct width.
        """
        if isinstance(requests, str):
            # Convert binary string to integer
            requests = int(requests, 2)
        # Ensure the request value has the correct width
        self.dut.w_req.value = requests & ((1 << NUM_CORES) - 1)  # Mask to ensure correct width
        await RisingEdge(self.dut.w_clock)

    async def check_grants(self, expected_grants):
        """
        Wait for the grant signal to be asserted and check its value.
        """
        # Wait for the grant signal to be valid
        for _ in range(10):  # Wait for up to 10 clock cycles
            await RisingEdge(self.dut.w_clock)
            if self.dut.r_grant.value.integer == expected_grants:
                break
        else:
            # If the loop completes without finding the expected grant, fail the test
            observed_grants = self.dut.r_grant.value.integer
            assert False, f"Grants mismatch. Expected {expected_grants}, got {observed_grants}"


@cocotb.test()
async def test_round_robin_arbitration(dut):
    arbiter = ArbiterDriver(dut)
    await arbiter.reset()

    # Test case 1: Single request
    await arbiter.drive_requests("0001")
    await arbiter.check_grants(1)  # Wait for grant to be asserted

    # Test case 2: Multiple requests
    await arbiter.drive_requests("0101")
    await arbiter.check_grants(4)  # Wait for grant to be asserted

    # Test case 3: All requests
    await arbiter.drive_requests("1111")
    await arbiter.check_grants(8)  # Wait for grant to be asserted

    # Test case 4: No requests
    await arbiter.drive_requests("0000")
    await arbiter.check_grants(0)  # Wait for grant to be asserted

    # Test case 5: Rotating priority
    await arbiter.drive_requests("0011")
    await arbiter.check_grants(2)  # Wait for grant to be asserted
    await arbiter.drive_requests("0011")
    await arbiter.check_grants(1)  # Wait for grant to be asserted


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
    