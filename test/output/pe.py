import cocotb
from cocotb.triggers import RisingEdge
from cocotb.binary import BinaryValue

@cocotb.test()
async def pe(dut):
    """Test the Output-Stationary PE Array against the function table."""

    # Helper function to reset the DUT
    async def reset_dut():
        dut.w_rst_n.value = 0
        await RisingEdge(dut.w_clk)
        dut.w_rst_n.value = 1
        await RisingEdge(dut.w_clk)

    # Reset DUT
    await reset_dut()

    # Step 1: Ensure reset state aligns with function table
    assert dut.w_out.value == BinaryValue('Z'), "Expected output to be high impedance (Z) after reset"

    # Step 2: Load weights and inputs (w_ready = 0, w_rw = X)
    dut.w_rw.value = 0
    dut.w_ready.value = 0
    dut.w_stream.value = 0  # Stream is off

    test_weight = 5
    test_input = 3

    dut.w_weight.value = test_weight
    dut.w_input.value = test_input

    await RisingEdge(dut.w_clk)

    # Verify that registers are updated properly
    assert dut.w_wreg_out.value == test_weight, f"Expected w_wreg_out={test_weight}, got {dut.w_wreg_out.value}"
    assert dut.w_ireg_out.value == test_input, f"Expected w_ireg_out={test_input}, got {dut.w_ireg_out.value}"
    assert dut.r_scratch.value == 0, f"Expected r_scratch=0, got {dut.r_scratch.value}"
    assert dut.w_freg_out.value == 0, f"Expected w_freg_out=0 after reset, got {dut.w_freg_out.value}"

    # Step 3: Compute phase with stream off (w_ready = 1, w_rw = 0, w_stream = 0)
    dut.w_rw.value = 0
    dut.w_ready.value = 1
    dut.w_stream.value = 0

    await RisingEdge(dut.w_clk)

    # Expected output: w_out = r_scratch since w_stream = 0
    assert dut.w_out.value == dut.r_scratch.value, f"Expected w_out={dut.r_scratch.value}, got {dut.w_out.value}"

    # Step 4: Compute phase with stream on (w_ready = 1, w_rw = 0, w_stream = 1)
    dut.w_stream.value = 1

    await RisingEdge(dut.w_clk)

    # Expected output: w_out = w_freg_out when streaming is enabled
    assert dut.w_out.value == dut.w_freg_out.value, f"Expected w_out={dut.w_freg_out.value}, got {dut.w_out.value}"

    # Step 5: Compute phase with MAC operation, no streaming (w_ready = 1, w_rw = 1, w_stream = 0)
    dut.w_rw.value = 1
    dut.w_stream.value = 0

    expected_scratch = test_weight * test_input

    await RisingEdge(dut.w_clk)

    # Expected scratch update: r_scratch = r_scratch + (w_wreg_out * w_ireg_out)
    assert dut.r_scratch.value == expected_scratch, f"Expected r_scratch={expected_scratch}, got {dut.r_scratch.value}"

    # Expected output: w_out = high impedance (Z)
    assert dut.w_out.value == BinaryValue('Z'), "Expected w_out to be Z when w_stream=0 during MAC"

    # Step 6: Compute phase with MAC + Streaming (w_ready = 1, w_rw = 1, w_stream = 1)
    dut.w_stream.value = 1
    test_fwd_in = 42  # Simulated forwarded value

    dut.w_fwd_in.value = test_fwd_in
    await RisingEdge(dut.w_clk)

    # Expected output: w_out = previous w_freg_out
    assert dut.w_out.value == dut.w_freg_out.value, f"Expected w_out={dut.w_freg_out.value}, got {dut.w_out.value}"

    # Expected register update: w_freg_out should be updated to w_fwd_in
    assert dut.w_freg_out.value == test_fwd_in, f"Expected w_freg_out={test_fwd_in}, got {dut.w_freg_out.value}"