"""
 * Copyright (c) 2024 WAT.ai Chip Team
 * Author: Brian Ibitoye
 * SPDX-License-Identifier: Apache-2.0
 * Tests cache for output stationary dataflow
 * (spec: https://docs.google.com/document/d/1bwynsWdD87AS_AJQEDSaEcCtV5cUac0pMMwL_9xpX6k/edit?tab=t.0#heading=h.qhw9ph8pgjln)
"""

import json
import cocotb
from cocotb.clock import Clock
from cocotb.triggers import RisingEdge, Timer

with open("parameters.json") as f:
    params = json.load(f)

COCOTB_CLOCK = params["COCOTB_CLOCK_NS"]
OUT_MEM_NUM_ROWS = params["OUT_MEM_NUM_ROWS"]


def not_resolvable(value: str) -> bool:
    """Returns True if 'x' or 'z' appears in the binary string."""
    return ("x" in value.lower()) or ("z" in value.lower())


@cocotb.coroutine
async def initialize_dut(dut):
    """
    Reset-like phase: drive w_ready=0 so that DUT clears internal registers
    and outputs. Keep w_state=7 (idle). Then wait a bit.
    """
    dut.w_clk.value = 0
    dut.w_ready.value = 0
    dut.w_state.value = 7
    dut.w_bus_in.value = 0
    dut.w_glb_in.value = 0
    dut.w_w_addr.value = 0
    dut.w_a_addr.value = 0

    await Timer(int(COCOTB_CLOCK / 2), units="ns")


@cocotb.test()
async def test_reset_state(dut):
    """When w_ready=0, registers should clear and outputs should drive high-Z."""
    cocotb.start_soon(Clock(dut.w_clk, COCOTB_CLOCK, units="ns").start())
    await initialize_dut(dut)

    # Wait a couple of clock edges
    for _ in range(2):
        await RisingEdge(dut.w_clk)
        await Timer(1, units="ns")

    # Check outputs
    assert not_resolvable(dut.r_wout.value.binstr), "r_wout should be high-Z"
    assert not_resolvable(dut.r_aout.value.binstr), "r_aout should be high-Z"
    assert not_resolvable(dut.r_bus_out.value.binstr), "r_bus_out should be high-Z"

    # Optionally confirm registers are zeroed
    try:
        for i in range(OUT_MEM_NUM_ROWS):
            wval = int(dut.r_w[i].value)
            aval = int(dut.r_a[i].value)
            pval = int(dut.r_p[i].value)
            assert wval == 0, f"r_w[{i}] != 0"
            assert aval == 0, f"r_a[{i}] != 0"
            assert pval == 0, f"r_p[{i}] != 0"
    except AttributeError:
        dut._log.warning("Direct reg array access not supported in this simulator.")


@cocotb.test()
async def test_load_and_send_weights(dut):
    """Load weights (state=0) then read them back (state=2)."""
    cocotb.start_soon(Clock(dut.w_clk, COCOTB_CLOCK, units="ns").start())
    await initialize_dut(dut)
    dut.w_ready.value = 1
    await RisingEdge(dut.w_clk)

    # Some test weights
    test_values = {0x00: 0x12, 0x0F: 0x34, 0xA0: 0xAB}

    # Load weights (S=0 => bus_in -> r_w)
    for addr, val in test_values.items():
        dut.w_state.value = 0
        dut.w_w_addr.value = addr
        dut.w_bus_in.value = val

        await RisingEdge(dut.w_clk)
        await Timer(1, units="ns")

        # Outputs should be high-Z while loading
        assert not_resolvable(dut.r_wout.value.binstr), "r_wout high-Z in load"
        assert not_resolvable(dut.r_aout.value.binstr), "r_aout high-Z in load"
        assert not_resolvable(dut.r_bus_out.value.binstr), "r_bus_out high-Z in load"

    # Send them (S=2 => r_w -> r_wout)
    for addr, expected in test_values.items():
        dut.w_state.value = 2
        dut.w_w_addr.value = addr

        await RisingEdge(dut.w_clk)
        await Timer(2, units="ns")

        read_val = dut.r_wout.value.integer
        assert (
            read_val == expected
        ), f"At addr=0x{addr:02X}, got 0x{read_val:02X}, expected 0x{expected:02X}"
        # Other outputs remain high-Z
        assert not_resolvable(dut.r_aout.value.binstr), "r_aout remains high-Z"
        assert not_resolvable(dut.r_bus_out.value.binstr), "r_bus_out remains high-Z"


@cocotb.test()
async def test_load_and_send_activations(dut):
    """Load activations (state=1) then send them (state=3)."""
    cocotb.start_soon(Clock(dut.w_clk, COCOTB_CLOCK, units="ns").start())
    await initialize_dut(dut)
    dut.w_ready.value = 1
    await RisingEdge(dut.w_clk)

    test_values = {0x10: 0x56, 0x20: 0x78, 0xE0: 0xCD}

    # Load activations (S=1)
    for addr, val in test_values.items():
        dut.w_state.value = 1
        dut.w_a_addr.value = addr
        dut.w_bus_in.value = val

        await RisingEdge(dut.w_clk)
        await Timer(1, units="ns")

    # Send them (S=3 => r_a -> r_aout)
    for addr, expected in test_values.items():
        dut.w_state.value = 3
        dut.w_a_addr.value = addr

        await RisingEdge(dut.w_clk)
        await Timer(2, units="ns")

        read_val = dut.r_aout.value.integer
        assert (
            read_val == expected
        ), f"At addr=0x{addr:02X}, got 0x{read_val:02X}, expected 0x{expected:02X}"
        # Other outputs remain high-Z
        assert not_resolvable(dut.r_wout.value.binstr), "r_wout high-Z"
        assert not_resolvable(dut.r_bus_out.value.binstr), "r_bus_out high-Z"


@cocotb.test()
async def test_load_and_send_both(dut):
    """
    Load weight and activation, then set w_state=4 to send both.
    (weight => r_wout, activation => r_aout, bus => high-Z)
    """
    cocotb.start_soon(Clock(dut.w_clk, COCOTB_CLOCK, units="ns").start())
    await initialize_dut(dut)
    dut.w_ready.value = 1
    await RisingEdge(dut.w_clk)

    # We'll load a single pair of (weight, activation) for demonstration.

    # 1) Load a weight at address=0x05 with value=0xAB
    dut.w_state.value = 0  # S=0 => load weight
    dut.w_w_addr.value = 0x05
    dut.w_bus_in.value = 0xAB
    await RisingEdge(dut.w_clk)
    await Timer(2, units="ns")

    # 2) Load an activation at address=0xF0 with value=0xCD
    dut.w_state.value = 1  # S=1 => load activation
    dut.w_a_addr.value = 0xF0
    dut.w_bus_in.value = 0xCD
    await RisingEdge(dut.w_clk)
    await Timer(2, units="ns")

    # 3) Send both (S=4 => r_w[w_w_addr] => r_wout, r_a[w_a_addr] => r_aout)
    dut.w_state.value = 4
    dut.w_w_addr.value = 0x05
    dut.w_a_addr.value = 0xF0
    await RisingEdge(dut.w_clk)
    await Timer(2, units="ns")

    # Check the outputs
    weight_out = dut.r_wout.value.integer
    activ_out = dut.r_aout.value.integer
    assert weight_out == 0xAB, f"Expected weight=0xAB, got 0x{weight_out:02X}"
    assert activ_out == 0xCD, f"Expected activation=0xCD, got 0x{activ_out:02X}"

    # psum bus stays high-Z
    assert not_resolvable(dut.r_bus_out.value.binstr), "r_bus_out high-Z in S=4"

    dut._log.info("Send-both test (S=4) passed.")


@cocotb.test()
async def test_store_and_send_psums(dut):
    """Store psums (state=5) in r_p, then send them (state=6) on r_bus_out."""
    cocotb.start_soon(Clock(dut.w_clk, COCOTB_CLOCK, units="ns").start())
    await initialize_dut(dut)
    dut.w_ready.value = 1
    await RisingEdge(dut.w_clk)

    test_values = {0x00: 0x1234, 0x10: 0xABCD, 0x1E: 0xFFFF}

    # S=5 => store psum from w_glb_in -> r_p[w_w_addr]
    for addr, val in test_values.items():
        dut.w_state.value = 5
        dut.w_w_addr.value = addr
        dut.w_glb_in.value = val

        await RisingEdge(dut.w_clk)
        await Timer(1, units="ns")

        # Outputs are high-Z while storing
        assert not_resolvable(dut.r_wout.value.binstr), "r_wout high-Z in psum store"
        assert not_resolvable(dut.r_aout.value.binstr), "r_aout high-Z in psum store"
        assert not_resolvable(
            dut.r_bus_out.value.binstr
        ), "r_bus_out high-Z in psum store"

    # S=6 => r_p[w_w_addr] -> r_bus_out
    for addr, expected in test_values.items():
        dut.w_state.value = 6
        dut.w_w_addr.value = addr

        await RisingEdge(dut.w_clk)
        await Timer(2, units="ns")

        read_val = dut.r_bus_out.value.integer
        assert (
            read_val == expected
        ), f"At addr=0x{addr:02X}, got 0x{read_val:04X}, expected 0x{expected:04X}"
        # Weights/activations high-Z
        assert not_resolvable(dut.r_wout.value.binstr), "r_wout high-Z in psum send"
        assert not_resolvable(dut.r_aout.value.binstr), "r_aout high-Z in psum send"


@cocotb.test()
async def test_idle_state(dut):
    """With w_state=7, all outputs should remain high-Z."""
    cocotb.start_soon(Clock(dut.w_clk, COCOTB_CLOCK, units="ns").start())
    await initialize_dut(dut)

    dut.w_ready.value = 1
    dut.w_state.value = 7
    await RisingEdge(dut.w_clk)
    await Timer(1, units="ns")

    assert not_resolvable(dut.r_wout.value.binstr), "r_wout should be high-Z in idle"
    assert not_resolvable(dut.r_aout.value.binstr), "r_aout should be high-Z in idle"
    assert not_resolvable(
        dut.r_bus_out.value.binstr
    ), "r_bus_out should be high-Z in idle"

    dut._log.info("Idle state test passed.")
