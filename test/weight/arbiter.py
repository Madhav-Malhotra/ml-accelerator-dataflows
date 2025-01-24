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
        self.dut.req.value = BinaryValue(requests)
        await RisingEdge(self.dut.clk)

    async def check_grants(self, expected_grants):
        await RisingEdge(self.dut.clk)
        observed_grants = self.dut.grant.value.integer
        assert observed_grants == expected_grants, f"Grants mismatch. Expected {expected_grants}, got {observed_grants}"

    async def check_config(self, expected_burst_size, expected_add_enable, expected_unload_enable):
        await RisingEdge(self.dut.clk)
        observed_burst_size = self.dut.burst_size.value.integer
        observed_add_enable = self.dut.add_enable.value.integer
        observed_unload_enable = self.dut.unload_enable.value.integer
        assert observed_burst_size == expected_burst_size, f"Burst size mismatch. Expected {expected_burst_size}, got {observed_burst_size}"
        assert observed_add_enable == expected_add_enable, f"Add enable mismatch. Expected {expected_add_enable}, got {observed_add_enable}"
        assert observed_unload_enable == expected_unload_enable, f"Unload enable mismatch. Expected {expected_unload_enable}, got {observed_unload_enable}"

@cocotb.test()
async def test_round_robin_arbitration(dut):
    arbiter = ArbiterDriver(dut)
    await arbiter.reset()

    # Test case 1: Single request
    dut.data_in.value = 0b01000001  # Burst size: 1, Add enable: 0, Unload enable: 1
    await arbiter.drive_requests("0001")
    await arbiter.check_grants(1)
    await arbiter.check_config(1, 0, 1)

    # Test case 2: Multiple requests
    dut.data_in.value = 0b10100010  # Burst size: 2, Add enable: 1, Unload enable: 0
    await arbiter.drive_requests("0101")
    await arbiter.check_grants(4)
    await arbiter.check_config(2, 1, 0)

    # Test case 3: All requests
    dut.data_in.value = 0b11110100  # Burst size: 4, Add enable: 1, Unload enable: 1
    await arbiter.drive_requests("1111")
    await arbiter.check_grants(8)
    await arbiter.check_config(4, 1, 1)

    # Test case 4: No requests
    await arbiter.drive_requests("0000")
    await arbiter.check_grants(0)

    # Test case 5: Rotating priority
    dut.data_in.value = 0b00010011  # Burst size: 3, Add enable: 0, Unload enable: 0
    await arbiter.drive_requests("0011")
    await arbiter.check_grants(2)
    await arbiter.check_config(3, 0, 0)
    await arbiter.drive_requests("0011")
    await arbiter.check_grants(1)
    await arbiter.check_config(3, 0, 0)

@cocotb.test()
async def test_transfer_behavior(dut):
    arbiter = ArbiterDriver(dut)
    await arbiter.reset()

    # Test loading behavior
    dut.data_in.value = 0b00100010  # Burst size: 2, Add enable: 0, Unload enable: 1
    await arbiter.drive_requests("0001")
    await arbiter.check_grants(1)
    await arbiter.check_config(2, 0, 1)
    
    # Check if the address is incremented correctly during transfer
    for i in range(2):
        await RisingEdge(dut.clk)
        assert dut.addr.value.integer == i, f"Address mismatch. Expected {i}, got {dut.addr.value.integer}"

    # Test unloading behavior
    dut.data_in.value = 0b10010011  # Burst size: 3, Add enable: 1, Unload enable: 0
    await arbiter.drive_requests("0010")
    await arbiter.check_grants(2)
    await arbiter.check_config(3, 1, 0)
    
    # Check if the address is incremented correctly during transfer
    for i in range(3):
        await RisingEdge(dut.clk)
        assert dut.addr.value.integer == i, f"Address mismatch. Expected {i}, got {dut.addr.value.integer}"

@cocotb.test()
async def test_load_unload_sequence(dut):
    arbiter = ArbiterDriver(dut)
    await arbiter.reset()

    # Load core 0
    dut.data_in.value = 0b00100010  # Burst size: 2, Add enable: 0, Unload enable: 1
    await arbiter.drive_requests("0001")
    await arbiter.check_grants(1)
    await arbiter.check_config(2, 0, 1)
    await Timer(20, units="ns")  # Wait for transfer to complete

    # Load core 1
    dut.data_in.value = 0b00110010  # Burst size: 2, Add enable: 1, Unload enable: 1
    await arbiter.drive_requests("0010")
    await arbiter.check_grants(2)
    await arbiter.check_config(2, 1, 1)
    await Timer(20, units="ns")  # Wait for transfer to complete

    # Unload core 0
    dut.data_in.value = 0b10010011  # Burst size: 3, Add enable: 1, Unload enable: 0
    await arbiter.drive_requests("0001")
    await arbiter.check_grants(1)
    await arbiter.check_config(3, 1, 0)
    await Timer(30, units="ns")  # Wait for transfer to complete

    # Unload core 1
    dut.data_in.value = 0b01010011  # Burst size: 3, Add enable: 0, Unload enable: 1
    await arbiter.drive_requests("0010")
    await arbiter.check_grants(2)
    await arbiter.check_config(3, 0, 1)
    await Timer(30, units="ns")  # Wait for transfer to complete

@cocotb.test()
async def test_error_conditions(dut):
    arbiter = ArbiterDriver(dut)
    await arbiter.reset()
    
    # Test early grant deassertion during weight loading
    dut.data_in.value = 0b00100010  # Burst size: 2, Add enable: 0, Unload enable: 1
    await arbiter.drive_requests("0001")
    await RisingEdge(dut.clk)
    dut.grant.value = 0  # Force early deassertion
    await Timer(20, units="ns")
    assert dut.error.value.integer == 1

    # Test early grant deassertion during activation loading
    await arbiter.reset()
    dut.data_in.value = 0b01100010  # Burst size: 2, Add enable: 1, Unload enable: 0
    await arbiter.drive_requests("0010")
    await RisingEdge(dut.clk)
    dut.grant.value = 0
    await Timer(20, units="ns")
    assert dut.error.value.integer == 1

    # Test early request deassertion during weight phase
    await arbiter.reset()
    dut.data_in.value = 0b00100010
    await arbiter.drive_requests("0001")
    await RisingEdge(dut.clk)
    await arbiter.drive_requests("0000")  # Early request removal
    await Timer(20, units="ns")
    assert dut.error.value.integer == 1
    
    # Test incorrect phase transition
    await arbiter.reset()
    dut.data_in.value = 0b00100010
    await arbiter.drive_requests("0001")
    await RisingEdge(dut.clk)
    dut.phase.value = 1  # Force incorrect phase transition
    await Timer(20, units="ns")
    assert dut.error.value.integer == 1

    # Test invalid load/unload combination
    await arbiter.reset()
    dut.data_in.value = 0b00100011  # Invalid: both load and unload enabled
    await arbiter.drive_requests("0001")
    await RisingEdge(dut.clk)
    await Timer(20, units="ns")
    assert dut.error.value.integer == 1
