"""
 * Copyright (c) 2024 WAT.ai Chip Team
 * Author: Madhav Malhotra
 * SPDX-License-Identifier: Apache-2.0
 * Tests non-cached controller for PE array
 * Spec: https://docs.google.com/document/d/1bwynsWdD87AS_AJQEDSaEcCtV5cUac0pMMwL_9xpX6k/edit?tab=t.0#heading=h.2psj995hbk8u
"""

import json
import cocotb
from math import log2
from cocotb.clock import Clock
from cocotb.binary import BinaryValue
from cocotb.triggers import RisingEdge, Timer

# Load parameters from parameters.json
with open("parameters.json") as f:
    params = json.load(f)

NUM_MEMS = params.get("OUT_CTL_NUM_MEMS")
NUM_PES = NUM_MEMS * NUM_MEMS
BURST_WIDTH = params.get("OUT_ARB_BURST_WIDTH")
MEM_ADDR_WIDTH = log2(params.get("OUT_MEM_NUM_ROWS"))
GLB_ADDR_WIDTH = log2(params.get("OUT_GLB_NUM_ROWS"))
COCOTB_CLOCK = params["COCOTB_CLOCK_NS"]


# Helper functions
def not_resolvable(value: str) -> bool:
    """Check if a value is not resolvable"""
    return "x" in value.lower() or "z" in value.lower()


class ControlTest:
    def __init__(self, dut):
        self.dut = dut
        self.log = dut._log
        self.clock = Clock(dut.w_clock, COCOTB_CLOCK, units="ns")
        cocotb.start_soon(self.clock.start())

    async def reset(self):
        self.dut.w_ready.value = 0
        await RisingEdge(self.dut.w_clock)
        await Timer(1, units="ns")

        self.dut.w_ready.value = 1
        self.dut.w_grant = 0
        self.dut.w_burst = 0
        await RisingEdge(self.dut.w_clock)
        await Timer(1, units="ns")


# Test reset state
@cocotb.test()
async def test_reset_state(dut):
    tb = ControlTest(dut)
    await tb.reset()

    # Check internal signals in the reset state
    assert dut.r_state.value == 0, f"Expected r_state to be 0, got {dut.r_state.value}"
    assert dut.r_req.value == 1, f"Expected r_req to be 1, got {dut.r_req.value}"

    # Check memory outputs in reset
    for i in range(NUM_MEMS):
        assert (
            dut.r_mem_weight_ready[i].value == 0
        ), f"Expected r_mem_weight_ready[{i}] to be 0, got {dut.r_mem_weight_ready[i].value}"
        assert (
            dut.r_mem_input_ready[i].value == 0
        ), f"Expected r_mem_input_ready[{i}] to be 0, got {dut.r_mem_input_ready[i].value}"
        assert (
            dut.r_glb_ready[i].value == 0
        ), f"Expected r_glb_ready[{i}] to be 0, got {dut.r_glb_ready[i].value}"

    # Check PE outputs in reset
    for i in range(NUM_PES):
        assert (
            dut.r_pe_ready[i].value == 0
        ), f"Expected r_pe_ready[{i}] to be 0, got {dut.r_pe_ready[i].value}"


# Test load state
@cocotb.test()
def test_load_state(dut):
    pass


# Test distribute state
@cocotb.test()
def test_distribute_state(dut):
    pass


# Test compute state
@cocotb.test()
def test_compute_state(dut):
    pass


# Test cleanup state
@cocotb.test()
def test_cleanup_state(dut):
    pass


# Test unload state
def test_unload_state(dut):
    pass
