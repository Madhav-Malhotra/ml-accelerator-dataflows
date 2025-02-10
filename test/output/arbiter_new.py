"""
 * Copyright (c) 2024 WAT.ai Chip Team
 * Author: Mariam El-Sahhar
 * SPDX-License-Identifier: Apache-2.0
 * Tests arbiter for output stationary dataflow
 * (spec: https://docs.google.com/document/d/1bwynsWdD87AS_AJQEDSaEcCtV5cUac0pMMwL_9xpX6k/edit?tab=t.0#heading=h.qnfirgtr5osr)
"""


import cocotb
from cocotb.clock import Clock
from cocotb.triggers import RisingEdge, Timer, ClockCycles
from cocotb.binary import BinaryValue

class ArbiterDriver:
    def __init__(self, dut):
        self.dut = dut
        self.clock = Clock(self.dut.w_clock, 10, units="ns")  # Hardcoded timing for debug
        cocotb.start_soon(self.clock.start())

    async def reset(self):
        self.dut.w_ready.value = 0
        self.dut.w_req.value = 0
        await ClockCycles(self.dut.w_clock, 5)  # Longer reset
        self.dut.w_ready.value = 1
        await ClockCycles(self.dut.w_clock, 5)  # Wait after reset

@cocotb.test()
async def test_basic_operation(dut):
    """Basic test to check state transitions and signal values"""
    # Initialize driver
    driver = ArbiterDriver(dut)
    
    # Reset
    await driver.reset()
    
    # Debug current state
    dut._log.info(f"After reset - State: {dut.r_state.value}")
    
    # Drive a single request
    dut.w_req.value = 1  # Request from first core
    
    # Monitor state transitions
    for i in range(10):  # Watch 10 cycles
        await RisingEdge(dut.w_clock)
        dut._log.info(f"""
        Cycle {i}:
        State: {dut.r_state.value}
        Request: {dut.w_req.value}
        Grant: {dut.r_grant.value}
        Burst: {dut.w_burst.value if hasattr(dut.w_burst, 'value') else 'N/A'}
        """)

@cocotb.test()
async def test_single_request(dut):
    """Test single request handling with detailed logging"""
    driver = ArbiterDriver(dut)
    await driver.reset()
    
    # Drive request and monitor
    dut.w_req.value = 1
    
    # Wait for full cycle
    cycles_waited = 0
    while cycles_waited < 20:  # Prevent infinite loop
        await RisingEdge(dut.w_clock)
        dut._log.info(f"""
        State: {dut.r_state.value}
        Request: {dut.w_req.value}
        Grant: {dut.r_grant.value}
        Load: {dut.r_load.value}
        """)
        cycles_waited += 1
        
        # Check if we completed a transfer
        if hasattr(dut, 'r_burst_done') and dut.r_burst_done.value == 1:
            break

@cocotb.test()
async def test_signal_visibility(dut):
    """Test to verify which signals are accessible"""
    driver = ArbiterDriver(dut)
    await driver.reset()
    
    # List all available signals
    signals = []
    for name, obj in dut._sub_handles.items():
        try:
            value = obj.value
            signals.append(f"{name}: {value}")
        except Exception as e:
            signals.append(f"{name}: <error reading value: {str(e)}>")
    
    dut._log.info("\nAvailable signals:\n" + "\n".join(signals))