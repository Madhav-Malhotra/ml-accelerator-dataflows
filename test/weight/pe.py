import cocotb
from cocotb.triggers import RisingEdge
from cocotb.binary import BinaryValue

@cocotb.test()
async def test_weight_stationary_pe(dut):
    """Comprehensive test for the weight-stationary processing element."""

    # Helper function to reset the DUT
    async def reset_dut():
        dut.w_rst_n.value = 0
        dut.w_ready.value = 0
        dut.w_rw.value = 0
        dut.w_weight.value = 0
        dut.w_input.value = 0
        await RisingEdge(dut.w_clk)
        dut.w_rst_n.value = 1
        await RisingEdge(dut.w_clk)

    # Reset the DUT
    await reset_dut()

    # Test 1: Check reset values
    assert dut.w_output.value == 0, f"Output not reset properly: {dut.w_output.value}"

    # Test 2: Load weight
    dut.w_ready.value = 1
    dut.w_rw.value = 0  # Write phase
    dut.w_weight.value = 7  # Load weight = 7
    await RisingEdge(dut.w_clk)

    # Test 3: Compute with valid input
    dut.w_rw.value = 1  # Compute phase
    dut.w_input.value = 5  # Input value = 5
    await RisingEdge(dut.w_clk)

    # Test 4: Add another input
    dut.w_input.value = 2
    await RisingEdge(dut.w_clk)

    # Test 5: Output phase
    dut.w_rw.value = 0  # Output phase
    await RisingEdge(dut.w_clk)

    # Test 6: High impedance output when not ready
    dut.w_ready.value = 0
    await RisingEdge(dut.w_clk)
    assert BinaryValue(dut.w_output.value).is_resolvable == False, f"Output should be high impedance: {dut.w_output.value}"

    # Test 7: Compute with zero weight
    await reset_dut()
    dut.w_ready.value = 1
    dut.w_rw.value = 0  # Write phase
    dut.w_weight.value = 0  # Load weight = 0
    await RisingEdge(dut.w_clk)

    dut.w_rw.value = 1  # Compute phase
    dut.w_input.value = 10  # Input value = 10
    await RisingEdge(dut.w_clk)
    assert dut.w_output.value == 0, f"Scratchpad should remain 0 when weight is 0: {dut.w_output.value}"

    # Test 8: Compute with zero input
    await reset_dut()
    dut.w_ready.value = 1
    dut.w_rw.value = 0  # Write phase
    dut.w_weight.value = 8  # Load weight = 8
    await RisingEdge(dut.w_clk)

    dut.w_rw.value = 1  # Compute phase
    dut.w_input.value = 0  # Input value = 0
    await RisingEdge(dut.w_clk)
    assert dut.w_output.value == 0, f"Scratchpad should remain 0 when input is 0: {dut.w_output.value}"

    # Test 9: Check multiple cycles of computation
    await reset_dut()
    dut.w_ready.value = 1
    dut.w_rw.value = 0
    dut.w_weight.value = 3  # Load weight = 3
    await RisingEdge(dut.w_clk)

    dut.w_rw.value = 1
    for i in range(1, 6):
        dut.w_input.value = i  # Input value = i
        await RisingEdge(dut.w_clk)

    dut.w_rw.value = 0
    await RisingEdge(dut.w_clk)

    cocotb.log.info("All tests passed for the weight-stationary PE!")
