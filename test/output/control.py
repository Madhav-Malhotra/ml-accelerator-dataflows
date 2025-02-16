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
BURST_WRITE = params.get("OUT_ARB_FIXED_BURST_WRITE")
MEM_ADDR_WIDTH = log2(params.get("OUT_MEM_NUM_ROWS"))
GLB_ADDR_WIDTH = log2(params.get("OUT_GLB_NUM_ROWS"))
COCOTB_CLOCK = params["COCOTB_CLOCK_NS"]


# Helper functions
def not_resolvable(value: str) -> bool:
    """Check if a value is not resolvable"""
    return "x" in value.lower() or "z" in value.lower()


def stoi(name: str) -> int:
    """Maps state names to integer codes for assertions"""
    return {
        "RESET": 0,
        "LOAD": 1,
        "DISTRIBUTE": 2,
        "COMPUTE": 3,
        "CLEANUP": 4,
        "UNLOAD": 5,
    }[name]


def itos(num: int) -> str:
    """Maps integer state codes to state names"""
    return {
        0: "RESET",
        1: "LOAD",
        2: "DISTRIBUTE",
        3: "COMPUTE",
        4: "CLEANUP",
        5: "UNLOAD",
    }[num]


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

    def log_signals(
        self,
        debug_info: str = "",
        show_glb: bool = False,
        show_w_mem: bool = False,
        show_i_mem: bool = False,
        show_pe: bool = False,
        idx: int = -1,
    ):
        """
        Logs all control signals for debugging

        Args:
            debug_info: str - Debug information to append to log
            show_glb: bool - Show GLB signals
            show_w_mem: bool - Show weight memory signals
            show_i_mem: bool - Show input memory signals
            idx: int - Index of memory/GLB/PE to show signals for
        """
        log_str = f"{debug_info}\nr_state: {itos(self.dut.r_state.value.integer)}\nr_count: {self.dut.r_count.value.integer}\nr_req: {self.dut.r_req.value}\nw_grant: {self.dut.w_grant.value}\nr_done: {self.dut.r_transfer_done.value}\nr_burst: {self.dut.r_burst.value.integer}\n"

        if show_glb:
            if idx > -1:
                log_str += f"r_glb_ready[{idx}]: {self.dut.r_glb_ready[idx].value}\nr_glb_rw[{idx}]: {self.dut.r_glb_rw[idx].value}\nr_glb_addr[{idx}]: {self.dut.r_glb_addr[idx].value}\n"
            else:
                for i in range(NUM_MEMS):
                    log_str += f"r_glb_ready[{i}]: {self.dut.r_glb_ready[i].value}\nr_glb_rw[{i}]: {self.dut.r_glb_rw[i].value}\nr_glb_addr[{i}]: {self.dut.r_glb_addr[i].value}\n"

        if show_w_mem:
            if idx > -1:
                log_str += f"r_mem_weight_ready[{idx}]: {self.dut.r_mem_weight_ready[idx].value}\nr_mem_weight_rw[{idx}]: {self.dut.r_mem_weight_rw[idx].value}\nr_mem_weight_addr[{idx}]: {self.dut.r_mem_weight_addr[idx].value}\n"
            else:
                for i in range(NUM_MEMS):
                    log_str += f"r_mem_weight_ready[{i}]: {self.dut.r_mem_weight_ready[i].value}\nr_mem_weight_rw[{i}]: {self.dut.r_mem_weight_rw[i].value}\nr_mem_weight_addr[{i}]: {self.dut.r_mem_weight_addr[i].value}\n"

        if show_i_mem:
            if idx > -1:
                log_str += f"r_mem_input_ready[{idx}]: {self.dut.r_mem_input_ready[idx].value}\nr_mem_input_rw[{idx}]: {self.dut.r_mem_input_rw[idx].value}\nr_mem_input_addr[{idx}]: {self.dut.r_mem_input_addr[idx].value}\n"
            else:
                for i in range(NUM_MEMS):
                    log_str += f"r_mem_input_ready[{i}]: {self.dut.r_mem_input_ready[i].value}\nr_mem_input_rw[{i}]: {self.dut.r_mem_input_rw[i].value}\nr_mem_input_addr[{i}]: {self.dut.r_mem_input_addr[i].value}\n"

        if show_pe:
            if idx > -1:
                log_str += f"r_pe_ready[{idx}]: {self.dut.r_pe_ready[idx].value}\nr_pe_rw[{idx}]: {self.dut.r_pe_rw[idx].value}\nr_pe_stream[{idx}]: {self.dut.r_pe_stream[idx].value}\n"
            else:
                for i in range(NUM_PES):
                    log_str += f"r_pe_ready[{i}]: {self.dut.r_pe_ready[i].value}\nr_pe_rw[{i}]: {self.dut.r_pe_rw[i].value}\nr_pe_stream[{i}]: {self.dut.r_pe_stream[i].value}\n"

        self.dut._log.info(log_str)

    def check_state(self, state: str, debug_info: str = ""):
        """
        Checks if the state of the controller is as expected

        Args:
            state: str - Expected state
            debug_info: str - Debug information to append to assert error
        """
        assert self.dut.r_state.value == stoi(
            state
        ), f"Expected r_state to be {state} ({stoi(state)}), got {itos(self.dut.r_state.value.integer)} ({self.dut.r_state.value}). {debug_info}"

    def check_reset(self, module: str, idx: int, debug_info: str = ""):
        """
        Checks if module at specified idx is reset

        Args:
            module: str - Module to check (M = mems, G = GLB, P = PEs)
            idx: int - Index of module
            debug_info: str - Debug information to append to assert error
        """

        if module == "M":
            assert (
                self.dut.r_mem_weight_ready[idx].value == 0
            ), f"Expected r_mem_weight_ready[{idx}] to be 0, got {self.dut.r_mem_weight_ready[idx].value}. {debug_info}"
            assert (
                self.dut.r_mem_input_ready[idx].value == 0
            ), f"Expected r_mem_input_ready[{idx}] to be 0, got {self.dut.r_mem_input_ready[idx].value}. {debug_info}"
        elif module == "G":
            assert (
                self.dut.r_glb_ready[idx].value == 0
            ), f"Expected r_glb_ready[{idx}] to be 0, got {self.dut.r_glb_ready[idx].value}. {debug_info}"
        elif module == "P":
            assert (
                self.dut.r_pe_ready[idx].value == 0
            ), f"Expected r_pe_ready[{idx}] to be 0, got {self.dut.r_pe_ready[idx].value}. {debug_info}"
        else:
            raise ValueError(f"Module must be one of 'M', 'G', 'P'. Got {module}")

    def check_mem_control(
        self, module: str, idx: int, rw: bool, addr: int, debug_info: str = ""
    ):
        """
        Checks if memory/glb control signals are as expected

        Args
            module: str - Module to check (M = mems, G = GLB)
            idx: int - Index of module
            rw: bool - Read/Write signal
            addr: int - Address signal
            debug_info: str - Debug information to append to assert error
        """

        if module == "M":
            assert (
                self.dut.r_mem_weight_ready[idx].value == 1
            ), f"Expected r_mem_weight_ready[{idx}] to be 1, got {self.dut.r_mem_weight_ready[idx].value}. {debug_info}"
            assert self.dut.r_mem_weight_rw[idx].value == int(
                rw
            ), f"Expected r_mem_weight_rw[{idx}] to be {int(rw)}, got {self.dut.r_mem_weight_rw[idx].value}. {debug_info}"
            assert (
                self.dut.r_mem_weight_addr[idx].value == addr
            ), f"Expected r_mem_weight_addr[{idx}] to be {addr}, got {self.dut.r_mem_weight_addr[idx].value}. {debug_info}"

            assert (
                self.dut.r_mem_input_ready[idx].value == 1
            ), f"Expected r_mem_input_ready[{idx}] to be 1, got {self.dut.r_mem_input_ready[idx].value}. {debug_info}"
            assert self.dut.r_mem_input_rw[idx].value == int(
                rw
            ), f"Expected r_mem_input_rw[{idx}] to be {int(rw)}, got {self.dut.r_mem_input_rw[idx].value}. {debug_info}"
            assert (
                self.dut.r_mem_input_addr[idx].value == addr
            ), f"Expected r_mem_input_addr[{idx}] to be {addr}, got {self.dut.r_mem_input_addr[idx].value}. {debug_info}"

        elif module == "G":
            assert (
                self.dut.r_glb_ready[idx].value == 1
            ), f"Expected r_glb_ready[{idx}] to be 1, got {self.dut.r_glb_ready[idx].value}. {debug_info}"
            assert self.dut.r_glb_rw[idx].value == int(
                rw
            ), f"Expected r_glb_rw[{idx}] to be {int(rw)}, got {self.dut.r_glb_rw[idx].value}. {debug_info}"
            assert (
                self.dut.r_glb_addr[idx].value == addr
            ), f"Expected r_glb_addr[{idx}] to be {addr}, got {self.dut.r_glb_addr[idx].value}. {debug_info}"

        else:
            raise ValueError(f"Module must be one of 'M', 'G'. Got {module}")

    def check_pe_control(self, idx: int, rw: bool, stream: bool, debug_info: str = ""):
        """
        Checks if PE control signals are as expected

        Args
            idx: int - Index of PE
            rw: bool - Read/Write signal
            stream: bool - Stream signal
            debug_info: str - Debug information to append to assert error
        """

        assert (
            self.dut.r_pe_ready[idx].value == 1
        ), f"Expected r_pe_ready[{idx}] to be 1, got {self.dut.r_pe_ready[idx].value}. {debug_info}"
        assert self.dut.r_pe_rw[idx].value == int(
            rw
        ), f"Expected r_pe_rw[{idx}] to be {int(rw)}, got {self.dut.r_pe_rw[idx].value}. {debug_info}"
        assert self.dut.r_pe_stream[idx].value == int(
            stream
        ), f"Expected r_pe_stream[{idx}] to be {int(stream)}, got {self.dut.r_pe_stream[idx].value}. {debug_info}"


# Test reset state
@cocotb.test()
async def test_reset_state(dut):
    tb = ControlTest(dut)
    await tb.reset()

    # Check internal signals in the reset state
    tb.check_state("RESET")
    assert dut.r_req.value == 1, f"Expected r_req to be 1, got {dut.r_req.value}"

    # Check memory outputs in reset
    for i in range(NUM_MEMS):
        tb.check_reset("M", i)
        tb.check_reset("G", i)

    # Check PE outputs in reset
    for i in range(NUM_PES):
        tb.check_reset("P", i)


# Test load state
@cocotb.test()
async def test_load_state(dut):
    tb = ControlTest(dut)
    await tb.reset()

    # Transition from reset to load state
    dut.w_grant.value = 1
    dut.w_burst.value = BURST_WRITE - 1
    await RisingEdge(dut.w_clock)
    await Timer(1, units="ns")

    # Check internal signals
    tb.check_state("LOAD")
    assert dut.r_req.value == 1, f"Expected r_req to be 1, got {dut.r_req.value}"

    # First clock cycle - burst capture
    await RisingEdge(dut.w_clock)
    await Timer(1, units="ns")

    # Check memory outputs in burst capture
    for i in range(NUM_MEMS):
        tb.check_reset("M", i)
        tb.check_reset("G", i)

    # Check PE outputs in burst capture
    for i in range(NUM_PES):
        tb.check_reset("P", i)

    dut.w_burst.value = 0

    # Continue iterating on clock cycles until end of load state
    for i in range(BURST_WRITE):
        await RisingEdge(dut.w_clock)
        await Timer(1, units="ns")

        # Check internal signals
        tb.check_state("LOAD", f"Cycle {i}")
        assert (
            dut.r_req.value == 1
        ), f"Expected r_req to be 1, got {dut.r_req.value}. Cycle {i}"

        # Check memory outputs
        for j in range(NUM_MEMS):
            tb.check_mem_control("M", j, 1, i, f"Cycle {i}")
            tb.check_reset("G", j, f"Cycle {i}")

        # Check PE outputs
        for j in range(NUM_PES):
            tb.check_reset("P", j, f"Cycle {i}")

    # Check if state transitions to distribute
    dut.w_grant.value = 0
    await RisingEdge(dut.w_clock)
    await Timer(1, units="ns")
    tb.check_state("DISTRIBUTE")


# Test distribute state
@cocotb.test()
async def test_distribute_state(dut):
    tb = ControlTest(dut)
    await tb.reset()

    # Transition from reset to load state
    dut.w_grant.value = 1
    dut.w_burst.value = BURST_WRITE - 1
    await RisingEdge(dut.w_clock)
    await Timer(1, units="ns")

    # Transition from load to distribute state
    for i in range(BURST_WRITE + 1):
        await RisingEdge(dut.w_clock)
        await Timer(1, units="ns")

        if i == BURST_WRITE:
            tb.log_signals()

    await RisingEdge(dut.w_clock)  # extra delay for first cycle of distribute
    await Timer(1, units="ns")
    tb.log_signals()

    await RisingEdge(dut.w_clock)  # extra delay for first cycle of distribute
    await Timer(1, units="ns")
    tb.log_signals()

    # Verify 6 cycles of distribute state
    # All GLBs should be stalled
    # Memories should activate one at a time.
    # Verify each delay group of PEs

    assert 1 == 0, "Temporary placeholder"


# Test compute state
@cocotb.test()
async def test_compute_state(dut):
    tb = ControlTest(dut)
    await tb.reset()
    assert 0 == 0, "Temporary placeholder"


# Test cleanup state
@cocotb.test()
async def test_cleanup_state(dut):
    tb = ControlTest(dut)
    await tb.reset()
    assert 0 == 0, "Temporary placeholder"


# Test unload state
@cocotb.test()
async def test_unload_state(dut):
    tb = ControlTest(dut)
    await tb.reset()
    assert 0 == 0, "Temporary placeholder"
