import cocotb
from cocotb.clock import Clock
from cocotb.triggers import RisingEdge, Timer
from cocotb.result import TestFailure

# Initialize the DUT signals
@cocotb.coroutine
def initialize_dut(dut):
    dut.w_clk <= 0
    dut.w_ready <= 0
    dut.w_rw <= 0
    dut.w_address <= 0
    dut.w_data_in <= 0
    yield Timer(10, units='ns')

# Testbench for the output stationary glb
@cocotb.test()
def glb_tb(dut):
    # Start the clock
    cocotb.fork(Clock(dut.w_clk, 20, units="ns").start())  # 50 MHz clock

    # Initialize signals
    yield initialize_dut(dut)

    # Test 1: When not ready
    dut.w_ready <= 0
    yield RisingEdge(dut.w_clk)
    cocotb.log.info("Test 1: ready = 0, output should be z")
    if dut.r_data_out.value != "z" * 16:
        raise TestFailure("Test 1 failed: data_out != z")

    # Test 2: When ready = 1, rw = 1, read address
    dut.w_ready <= 1
    dut.w_rw <= 1
    dut.w_address <= 0b000000
    dut.w_data_in <= 0b0000000001000001  # A in binary
    yield RisingEdge(dut.w_clk)
    cocotb.log.info("Test 2: ready = 1, rw = 1, address = 0, output should be z")
    if dut.r_data_out.value != "z" * 16:
        raise TestFailure("Test 2 failed: data_out != z")

    # Test 3: Read address = 1
    dut.w_address <= 0b000001
    dut.w_data_in <= 0b0000000001000010  # B in binary
    yield RisingEdge(dut.w_clk)
    cocotb.log.info("Test 3: reading address = 1, output should be z")
    if dut.r_data_out.value != "z" * 16:
        raise TestFailure("Test 3 failed: data_out != z")

    # Test 4: rw = z
    dut.w_rw <= "z"
    yield RisingEdge(dut.w_clk)
    cocotb.log.info("Test 4: rw = z, output should be z, and Q should be held from previous state")
    if dut.r_data_out.value != "z" * 16:
        raise TestFailure("Test 4 failed: data_out != z")

    # Read more values
    dut.w_rw <= 1
    dut.w_address <= 0b000010
    dut.w_data_in <= 0b0000000001000011 # C
    yield RisingEdge(dut.w_clk)
    cocotb.log.info("Reading C")
    if dut.r_data_out.value != "z" * 16:
        raise TestFailure("Reading failed: data_out != z")
    
    dut.w_address <= 0b000011
    dut.w_data_in <= 0b0000000001000100 # D
    yield RisingEdge(dut.w_clk)
    cocotb.log.info("Reading D")
    if dut.r_data_out.value != "z" * 16:
        raise TestFailure("Reading failed: data_out != z")
    
    dut.w_address <= 0b000100
    dut.w_data_in <= 0b0000000001000101 # E
    yield RisingEdge(dut.w_clk)
    cocotb.log.info("Reading E")
    if dut.r_data_out.value != "z" * 16:
        raise TestFailure("Reading failed: data_out != z")
    

    # Test 5: rw = 0, read address = 4
    dut.w_rw <= 0
    dut.w_address <= 0b000100 
    yield RisingEdge(dut.w_clk)
    cocotb.log.info("Test 5: rw = 0, address = 4, output should be 0x0045")
    if dut.r_data_out.value != 0b0000000001000101:
        raise TestFailure("Test 5 failed: data_out != 0b0000000001000101")

    # Write more values
    dut.address <= 0b000011
    yield RisingEdge(dut.w_clk)
    cocotb.log.info("Writing D")
    if dut.r_data_out.value != 0b0000000001000100:
        raise TestFailure("Writing failed: data_out != 0b0000000001000100")
    
    dut.address <= 0b000010
    yield RisingEdge(dut.w_clk)
    cocotb.log.info("Writing C")
    if dut.r_data_out.value != 0b0000000001000011:
        raise TestFailure("Writing failed: data_out != 0b0000000001000011")
    
    dut.address <= 0b000001
    yield RisingEdge(dut.w_clk)
    cocotb.log.info("Writing B")
    if dut.r_data_out.value != 0b0000000001000010:
        raise TestFailure("Writing failed: data_out != 0b0000000001000010")

    dut.w_address <= 0b000000
    yield RisingEdge(dut.w_clk)
    cocotb.log.info("Writing A")
    if dut.r_data_out.value != 0b0000000010000001: 
        raise TestFailure("Writing failed: data_out != 0b0000000001000001")

    # Test 6: Reset when ready = 0
    dut.w_ready <= 0
    yield RisingEdge(dut.w_clk)
    cocotb.log.info("Test 6: ready = 0, output should be z")
    if dut.r_data_out.value != "z" * 16:
        raise TestFailure("Test 6 failed: data_out != z")
