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


with open("parameters.json") as f:
    params = json.load(f)

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
        self.dut.w_req.value = BinaryValue(requests)
        await RisingEdge(self.dut.w_clock)

    async def check_grants(self, expected_grants):
        await RisingEdge(self.dut.w_clock)
        observed_grants = self.dut.r_grant.value.integer
        assert (
            observed_grants == expected_grants
        ), f"Grants mismatch. Expected {expected_grants}, got {observed_grants}"


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
    assert (
        dut.r_load.value.integer == 3
    ), f"Load register mismatch. Expected 3, got {dut.r_load.value.integer}"


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
    assert (
        dut.r_load.value.integer == 0
    ), f"Load register mismatch after unloading. Expected 0, got {dut.r_load.value.integer}"
