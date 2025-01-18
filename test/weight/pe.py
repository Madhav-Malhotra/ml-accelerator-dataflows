import cocotb
from cocotb.triggers import RisingEdge
from cocotb.binary import BinaryValue

@cocotb.test()
async def test_weight_stationary_pe(dut):
    """Test the weight-stationary processing element against the waveform."""

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

    # Phase 1: Load weight
    dut.w_ready.value = 1
    dut.w_rw.value = 0  # Write phase
    dut.w_weight.value = 2  # Load weight = 2
    await RisingEdge(dut.w_clk)
    
    # Phase 2: Compute inputs
    dut.w_rw.value = 1  # Compute phase
    inputs = [2, 1, 3, 4]  # Data inputs
    expected_scratch = [0, 3, 6, 15]  # Expected scratch values
    expected_output = [0, 3, 6, 9]  # Expected output values
    
    for i in range(len(inputs)):
        dut.w_input.value = inputs[i]
        await RisingEdge(dut.w_clk)
        
        # Verify expected accumulation in scratchpad (r_scratch inferred)
        assert dut.w_output.value == expected_output[i], \
            f"Mismatch at cycle {i}: Expected {expected_output[i]}, Got {dut.w_output.value}"
    
    # Phase 3: Output values
    dut.w_rw.value = 0  # Output phase
    await RisingEdge(dut.w_clk)
    assert dut.w_output.value == 9, "Final output mismatch! Expected 9"
    
    cocotb.log.info("All tests passed, matching waveform!")
