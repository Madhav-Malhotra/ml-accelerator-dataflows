"""
 * Copyright (c) 2024 WAT.ai Chip Team
 * Author: Zoe Lussier-Gibbons
 * SPDX-License-Identifier: Apache-2.0
 * Tests memory for output stationary dataflow
 * (spec: https://docs.google.com/document/d/1bwynsWdD87AS_AJQEDSaEcCtV5cUac0pMMwL_9xpX6k/edit?tab=t.0#heading=h.ttrwxbq2s3f6)
"""

import cocotb
from cocotb.clock import Clock
from cocotb.triggers import RisingEdge, Timer
from cocotb.result import TestFailure
from cocotb.binary import BinaryValue
import json

with open("parameters.json") as f:
    params = json.load(f)

OUT_MEM_NUM_ROWS = params["OUT_MEM_NUM_ROWS"]


def not_resolvable(value: str) -> bool:
    """Check if a value is not resolvable"""
    return "x" in value.lower() or "z" in value.lower()


# Initialize the DUT signals
@cocotb.coroutine
async def initialize_dut(dut):
    dut.w_clock = 0
    dut.w_ready = 0
    dut.w_rw = 0
    dut.w_address = 0
    dut.w_data_in = 0
    await Timer(10, units="ns")


@cocotb.test()
async def test_reset_state(dut):
    # Start the clock
    cocotb.start_soon(Clock(dut.w_clock, 20, units="ns").start())  # 50 MHz clock

    # Initialize signals
    await initialize_dut(dut)

    dut.w_ready.value = 0
    await RisingEdge(dut.w_clock)
    # Need a small delay to allow non-blocking assignment to take effect
    await Timer(1, units="ns")

    # Verify reset state outputs
    # Check if output is high-Z
    assert not_resolvable(
        dut.w_data_out.value.binstr
    ), "Output should be high-Z during reset"

    # Check memory contents
    # Note: Not all simulators allow direct access to memory arrays
    try:
        for i in range(OUT_MEM_NUM_ROWS):
            mem_val = int(dut.r_Q[i].value)
            assert mem_val == 0, f"Memory location {i} should be 0 but is {mem_val}"
    except AttributeError:
        dut._log.warning(
            "Cannot directly access memory array - try functional testing instead"
        )


@cocotb.test()
async def test_read_memory(dut):
    """Test how the memory reads data"""
    # Start the clock
    cocotb.start_soon(Clock(dut.w_clock, 20, units="ns").start())

    # Initialize signals
    await initialize_dut(dut)

    # Wait a few clock cycles after reset
    for _ in range(2):
        await RisingEdge(dut.w_clock)

    # Enable memory operations
    dut.w_ready = 1
    dut.w_rw = 1  # Read mode

    # Test reading data into multiple addresses
    test_data = [
        (0x0, 0xAA),  # Address 0, data 0xAA
        (0x1F, 0x55),  # Address 31, data 0x55
        (0x3F, 0xFF),  # Address 63, data 0xFF
    ]

    for addr, data in test_data:
        dut.w_address = addr
        dut.w_data_in = data
        await RisingEdge(dut.w_clock)
        await Timer(1, units="ns")  # small delay for nonblocking assignment

        # Verify data was read into memory (if memory array is accessible)
        try:
            read_val = int(dut.r_Q[addr].value)
            assert (
                read_val == data
            ), f"Memory location {addr} should be {data:02x} but is {read_val:02x}"
        except AttributeError:
            dut._log.info(f"Cannot directly verify write to address {addr}")

    # Check that output remains high-Z while memory reads data
    assert not_resolvable(
        dut.w_data_out.value.binstr
    ), "Output should be high-Z during read operations"


@cocotb.test()
async def test_write_memory(dut):
    """Test writing data from memory to output"""
    # Start the clock
    cocotb.start_soon(Clock(dut.w_clock, 20, units="ns").start())

    # Initialize signals
    await initialize_dut(dut)

    # Wait for reset to work
    await RisingEdge(dut.w_clock)
    await Timer(1, units="ns")

    # Enable memory and read test data into it
    dut.w_ready = 1
    dut.w_rw = 1  # Read mode

    # Write test pattern
    test_data = {
        0x0: 0xAA,  # Address 0, data 0xAA
        0x1F: 0x55,  # Address 31, data 0x55
        0x3F: 0xFF,  # Address 63, data 0xFF
    }

    for addr, data in test_data.items():
        dut.w_address = addr
        dut.w_data_in = data

        await RisingEdge(dut.w_clock)
        await Timer(1, units="ns")  # Small delay to allow memory to update

    # Switch to write mode
    dut.w_rw = 0

    # Write each location of data to the output
    for addr, expected_data in test_data.items():
        dut.w_address = addr

        dut._log.info(f"w_ready: {dut.w_ready.value}")
        dut._log.info(f"w_rw: {dut.w_rw.value}")
        dut._log.info(f"r_data_out: {dut.r_data_out.value}")
        dut._log.info(f"w_data_out: {dut.w_data_out.value.binstr}")

        await RisingEdge(dut.w_clock)
        await Timer(15, units="ns")  # Small delay to allow output to stabilize

        dut._log.info(f"w_ready: {dut.w_ready.value}")
        dut._log.info(f"w_rw: {dut.w_rw.value}")
        dut._log.info(f"r_data_out: {dut.r_data_out.value}")
        dut._log.info(f"w_data_out: {dut.w_data_out.value.binstr}")

        written_val = int(dut.w_data_out.value)
        assert (
            written_val == expected_data
        ), f"Write from address {addr} to output returned {written_val:02x}, expected {expected_data:02x}"


@cocotb.test()
async def test_high_z_behavior(dut):
    """Test behavior when w_rw is in high-Z state"""
    # Start the clock
    cocotb.start_soon(Clock(dut.w_clock, 20, units="ns").start())

    # Initialize signals
    await initialize_dut(dut)

    # Wait a few clock cycles after reset
    for _ in range(3):
        await RisingEdge(dut.w_clock)

    # Enable memory
    dut.w_ready = 1

    # Set w_rw to high-Z
    dut.w_rw = BinaryValue("z")

    # Try different addresses
    test_addresses = [0x0, 0x1F, 0x3F]

    for addr in test_addresses:
        dut.w_address = addr
        dut.w_data_in = 0xAA  # Test data
        await RisingEdge(dut.w_clock)
        await Timer(1, units="ns")

        # Verify output is high-Z when w_rw is high-Z
        assert not_resolvable(
            dut.w_data_out.value.binstr
        ), f"Output should be high-Z when w_rw is high-Z, address: {addr}"

    # Verify memory contents haven't changed
    try:
        for i in test_addresses:
            mem_val = int(dut.r_Q[i].value)
            assert (
                mem_val == 0
            ), f"Memory location {i} should remain 0 when w_rw is high-Z"
    except AttributeError:
        dut._log.warning("Cannot directly access memory array")
