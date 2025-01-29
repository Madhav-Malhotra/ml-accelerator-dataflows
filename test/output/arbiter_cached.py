"""
 * Copyright (c) 2024 WAT.ai Chip Team
 * Author: Madhav Malhotra
 * SPDX-License-Identifier: Apache-2.0
 * Tests cached arbiter for output stationary dataflow
 * (spec: https://docs.google.com/document/d/1bwynsWdD87AS_AJQEDSaEcCtV5cUac0pMMwL_9xpX6k/edit?tab=t.0#heading=h.onnj5tjg6vwi)
 * WARNING: Hardcoded config data for now. Replace with FIFO lookup later
"""

import cocotb
from cocotb.clock import Clock
from cocotb.triggers import RisingEdge, FallingEdge, Timer
from cocotb.result import TestFailure
from cocotb.binary import BinaryValue

# Constants matching the Verilog parameters
NUM_CORES = 4
MAIN_MEM_ADDR_WIDTH = 32
BURST_WIDTH = 6
CONFIG_WIDTH = 16

# State encoding from Verilog
RESET = 0
IDLE = 1
LOCK = 2
ARBITRATE = 3
WRITE = 4
READ = 5


async def initialize_dut(dut):
    """Set up clock and initialize inputs"""
    clock = Clock(dut.w_clock, 100, units="ns")
    cocotb.start_soon(clock.start())

    # Initialize inputs
    dut.w_ready.value = 0
    dut.w_req.value = 0

    # Wait for initial reset
    await Timer(200, units="ns")
    return clock


async def reset_dut(dut):
    """Reset the DUT"""
    dut.w_ready.value = 0
    await RisingEdge(dut.w_clock)


@cocotb.test()
async def test_reset_state(dut):
    """Test reset state behavior"""

    _ = await initialize_dut(dut)

    await reset_dut(dut)

    # Verify reset state outputs
    assert dut.w_grant.value == 0, "Grant signals should be 0 in reset"
    assert dut.w_burst.value.is_z, "Burst should be high impedance in reset"
    assert dut.w_addr.value.is_z, "Address should be high impedance in reset"
    assert dut.w_rw.value.is_z, "RW should be high impedance in reset"

    # Verify internal device signals like the `r_req` register
    assert dut.r_req.value == 0, "Request register should be 0 in reset"
    assert dut.r_load.value == 0, "Load register should be 0 in reset"
    assert dut.r_state.value == RESET, "State should be reset after reset"


@cocotb.test()
async def test_idle_to_lock_transition(dut):
    """Test transition from idle to lock state"""
    clock = await initialize_dut(dut)
    await reset_dut(dut)

    # Set request from core 0
    dut.w_req.value = 1
    await RisingEdge(dut.w_clock)

    # Verify lock state behavior
    await RisingEdge(dut.w_clock)
    assert dut.w_grant.value == 0, "Grant should be 0 during lock state"


@cocotb.test()
async def test_write_operation(dut):
    """Test complete write operation for one core"""
    clock = await initialize_dut(dut)
    await reset_dut(dut)

    # Set request from core 0
    dut.w_req.value = 1

    # Wait for arbitration and write state
    for _ in range(4):
        await RisingEdge(dut.w_clock)

    # Check write signal assertions
    assert dut.w_rw.value == 0, "RW should be 0 for write operation"
    assert not dut.w_grant.value == 0, "Grant should be active for writing core"

    # Wait for burst completion
    for _ in range(16):
        await RisingEdge(dut.w_clock)
        if not dut.w_addr.value.is_z:
            prev_addr = dut.w_addr.value
            await RisingEdge(dut.w_clock)
            if not dut.w_addr.value.is_z:
                assert dut.w_addr.value == (
                    prev_addr + 1
                ), "Address should increment during burst"


@cocotb.test()
async def test_read_operation(dut):
    """Test complete read operation through all stages"""
    clock = await initialize_dut(dut)
    await reset_dut(dut)

    # Start with no load (read operation)
    dut.w_req.value = 1

    # Wait for arbitration
    for _ in range(3):
        await RisingEdge(dut.w_clock)

    # Check read stages (config, weights, activations)
    for stage in range(3):
        assert dut.w_rw.value == 1, f"RW should be 1 for read stage {stage}"

        # Wait for burst completion
        for _ in range(16):
            await RisingEdge(dut.w_clock)
            if not dut.w_addr.value.is_z:
                prev_addr = dut.w_addr.value
                await RisingEdge(dut.w_clock)
                if not dut.w_addr.value.is_z:
                    assert dut.w_addr.value == (
                        prev_addr + 1
                    ), f"Address should increment during burst in stage {stage}"


@cocotb.test()
async def test_multiple_core_arbitration(dut):
    """Test arbitration between multiple requesting cores"""
    clock = await initialize_dut(dut)
    await reset_dut(dut)

    # Set requests from multiple cores
    dut.w_req.value = 0b1111  # All cores requesting

    # Wait for arbitration
    await RisingEdge(dut.w_clock)
    await RisingEdge(dut.w_clock)

    # Verify only one core gets granted
    grant_val = dut.w_grant.value
    assert bin(grant_val).count("1") == 1, "Only one core should be granted at a time"


@cocotb.test()
async def test_burst_length(dut):
    """Test correct burst length assignment"""
    clock = await initialize_dut(dut)
    await reset_dut(dut)

    # Initiate a transfer
    dut.w_req.value = 1

    # Wait for burst length to be set
    for _ in range(4):
        await RisingEdge(dut.w_clock)

    # Check burst length value
    if not dut.w_burst.value.is_z:
        assert dut.w_burst.value == 16, "Burst length should match configured value"


# Add this to your Makefile:
#
# VERILOG_SOURCES = arbiter_cached.v
# TOPLEVEL = arbiter_cached
# MODULE = test_arbiter
#
# include $(shell cocotb-config --makefiles)/Makefile.sim
