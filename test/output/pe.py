import json
import random
import cocotb
from cocotb.clock import Clock
from cocotb.binary import BinaryValue
from cocotb.triggers import RisingEdge, Timer

# Init parameters
with open("parameters.json") as f:
    params = json.load(f)
OUT_MEM_NUM_ROWS = params["OUT_MEM_NUM_ROWS"]
OUT_PE_WEIGHT_WIDTH = params["OUT_PE_WEIGHT_WIDTH"]
OUT_PE_INPUT_WIDTH = params["OUT_PE_INPUT_WIDTH"]
OUT_PE_FWD_WIDTH = params["OUT_PE_FWD_WIDTH"]
COCOTB_SEED = params["COCOTB_SEED"]
COCOTB_CLOCK = params["COCOTB_CLOCK_NS"]


# Helper functions
def not_resolvable(value: str) -> bool:
    """Check if a value is not resolvable"""
    return "x" in value.lower() or "z" in value.lower()


class PETest:
    def __init__(self, dut):
        self.dut = dut
        self.log = dut._log
        self.rng = random.Random(COCOTB_SEED)

    async def reset(self):
        """Reset the PE by clearing ready signal"""
        self.dut.w_ready.value = 0
        await RisingEdge(self.dut.w_clock)
        await Timer(1, units="ns")

    async def initialize(self):
        """Initialize the DUT and start clock"""
        clock = Clock(self.dut.w_clock, COCOTB_CLOCK, units="ns")
        cocotb.start_soon(clock.start())

        # Initialize inputs
        self.dut.w_ready.value = 0
        self.dut.w_rw.value = 0
        self.dut.w_stream.value = 0
        self.dut.w_weight.value = 0
        self.dut.w_input.value = 0
        self.dut.w_fwd_in.value = 0

        await self.reset()


@cocotb.test()
async def test_data_gating(dut):
    """Test data gating functionality in multiplication pipeline"""
    tb = PETest(dut)
    await tb.initialize()

    assert not_resolvable(
        dut.w_out.value.binstr
    ), "Output should be high-Z when not ready"

    # Test 1: Zero weight should not trigger pipeline
    dut.w_ready.value = 1
    dut.w_rw.value = 1
    dut.w_weight.value = 0
    dut.w_input.value = 5

    await RisingEdge(dut.w_clock)
    await Timer(1, units="ns")  # Wait for nonblocking updates
    assert dut.r_pipeline.value == 0, "Pipeline should be gated for zero weight"
    assert dut.r_scratch.value == 0, "Scratch should be gated for zero weight"

    await RisingEdge(dut.w_clock)
    await Timer(1, units="ns")
    assert dut.r_pipeline.value == 0, "Pipeline should be gated for zero weight"
    assert dut.r_scratch.value == 0, "Scratch should be gated for zero weight"

    # Test 2: Zero input should not trigger pipeline
    dut.w_weight.value = 5
    dut.w_input.value = 0

    await RisingEdge(dut.w_clock)
    await Timer(1, units="ns")
    assert dut.r_pipeline.value == 0, "Pipeline should be gated for zero weight"
    assert dut.r_scratch.value == 0, "Scratch should be gated for zero weight"

    await RisingEdge(dut.w_clock)
    await Timer(1, units="ns")
    assert dut.r_pipeline.value == 0, "Pipeline should be gated for zero weight"
    assert dut.r_scratch.value == 0, "Scratch should be gated for zero weight"

    # Test 3: Non-zero multiplication should proceed
    dut.w_weight.value = 2
    dut.w_input.value = 3
    await RisingEdge(dut.w_clock)
    await Timer(1, units="ns")
    assert (
        dut.r_pipeline.value == 6
    ), f"Pipeline should be {2*3}. Got: {dut.r_pipeline.value}"
    prev = dut.r_scratch.value
    assert prev == 0, "Scratch should be zero"

    dut.w_weight.value = 0
    dut.w_input.value = 0

    await RisingEdge(dut.w_clock)
    await Timer(1, units="ns")
    assert dut.r_scratch.value == (
        prev + 6
    ), f"Scratchpad should be {prev+6}. Got: {dut.r_scratch.value}"


@cocotb.test()
async def test_pipeline_timing(dut):
    """Test pipeline stages timing and scratchpad accumulation"""
    tb = PETest(dut)
    await tb.initialize()

    # Setup read mode with continuous values
    dut.w_ready.value = 1
    dut.w_rw.value = 1

    # Generate test vectors
    weights_vector = []
    inputs_vector = []
    for _ in range(OUT_MEM_NUM_ROWS):
        wgt = random.randint(0, (2**OUT_PE_WEIGHT_WIDTH) - 1)
        inp = random.randint(0, (2**OUT_PE_INPUT_WIDTH) - 1)

        # Potentially gate values
        if random.random() < 0.5:
            wgt = 0
        if random.random() < 0.5:
            inp = 0

        weights_vector.append(wgt)
        inputs_vector.append(inp)

    # Run the test
    prev = 0
    for wgt, inp in zip(weights_vector, inputs_vector):
        dut.w_weight.value = wgt
        dut.w_input.value = inp

        # Just to test all possible interactions
        dut.w_stream.value = random.choice([0, 1])
        dut.w_fwd_in.value = random.randint(0, (2**OUT_PE_FWD_WIDTH) - 1)

        await RisingEdge(dut.w_clock)
        await Timer(1, units="ns")

        assert (
            dut.r_pipeline.value == wgt * inp
        ), f"Pipeline should be {wgt*inp}. Got: {dut.r_pipeline.value}"

        # How to account for addition overflow?
        assert (
            dut.r_scratch.value == prev
        ), f"Scratch should be {prev}. Got: {dut.r_scratch.value}"

        prev += wgt * inp

    # Check final scratchpad value
    await RisingEdge(dut.w_clock)
    await Timer(1, units="ns")
    assert (
        dut.r_scratch.value == prev
    ), f"Final scratch should be {prev}. Got: {dut.r_scratch.value}"


@cocotb.test()
async def test_streaming(dut):
    """Test streaming mode and output behavior"""
    tb = PETest(dut)
    await tb.initialize()

    # Test: Read with stream
    dut.w_ready.value = 1
    dut.w_rw.value = 1
    dut.w_stream.value = 1
    dut.w_weight.value = 7
    dut.w_input.value = 3
    dut.w_fwd_in.value = (2**OUT_PE_FWD_WIDTH) - 1

    await RisingEdge(dut.w_clock)
    await Timer(1, units="ns")

    prod = dut.w_weight.value * dut.w_input.value
    assert dut.r_pipeline.value == (
        prod
    ), f"Pipeline should be {prod}. Got {dut.r_pipeline.value}"
    assert (
        dut.r_scratch.value == 0
    ), f"Scratch should be zero. Got {dut.r_scratch.value}"
    assert (
        dut.r_fwd.value == dut.w_fwd_in.value
    ), f"Forward reg should be {dut.w_fwd_in.value}. Got: {dut.r_fwd.value}"
    assert (
        dut.w_out.value == dut.r_fwd.value
    ), f"Output should be {dut.r_fwd.value}. Got: {dut.w_out.value}"
    assert (
        dut.w_wgt_out.value == dut.w_weight.value
    ), f"Weight out should be {dut.w_weight.value}. Got: {dut.w_wgt_out.value}"
    assert (
        dut.w_inp_out.value == dut.w_input.value
    ), f"Input out should be {dut.w_input.value}. Got: {dut.w_inp_out.value}"

    # Test: Read without stream
    dut.w_rw.value = 1
    dut.w_stream.value = 0
    dut.w_weight.value = 5
    dut.w_input.value = 0
    dut.w_fwd_in.value = 10
    prev_fwd = dut.r_fwd.value

    await RisingEdge(dut.w_clock)
    await Timer(1, units="ns")

    assert not_resolvable(
        dut.w_out.value.binstr
    ), "Output should be high-Z in read mode without stream"
    assert (
        dut.r_fwd.value == prev_fwd
    ), f"Forward reg should be {prev_fwd}. Got: {dut.r_fwd.value}"
    assert (
        dut.r_scratch.value == prod
    ), f"Scratch should be {prod}. Got: {dut.r_scratch.value}"
    assert (
        dut.r_pipeline.value == 0
    ), f"Pipeline should be zero. Got: {dut.r_pipeline.value}"
    assert (
        dut.w_wgt_out.value == dut.w_weight.value
    ), f"Weight out should be {dut.w_weight.value}. Got: {dut.w_wgt_out.value}"
    assert (
        dut.w_inp_out.value == dut.w_input.value
    ), f"Input out should be {dut.w_input.value}. Got: {dut.w_inp_out.value}"

    # Test: Write with stream
    dut.w_rw.value = 0
    dut.w_stream.value = 1
    dut.w_weight.value = random.randint(0, (2**OUT_PE_WEIGHT_WIDTH) - 1)
    dut.w_input.value = random.randint(0, (2**OUT_PE_INPUT_WIDTH) - 1)
    prev_fwd = dut.r_fwd.value

    await RisingEdge(dut.w_clock)
    await Timer(1, units="ns")

    assert (
        dut.w_out.value == dut.r_fwd.value
    ), f"Output should be {dut.r_fwd.value}. Got: {dut.w_out.value}"
    assert (
        dut.r_fwd.value == prev_fwd
    ), f"Forward reg should be {prev_fwd}. Got: {dut.r_fwd.value}"
    assert (
        dut.r_scratch.value == prod
    ), f"Scratch should be {prod}. Got: {dut.r_scratch.value}"
    assert (
        dut.r_pipeline.value == 0
    ), f"Pipeline should be zero. Got: {dut.r_pipeline.value}"
    assert (
        dut.w_wgt_out.value == dut.w_weight.value
    ), f"Weight out should be {dut.w_weight.value}. Got: {dut.w_wgt_out.value}"
    assert (
        dut.w_inp_out.value == dut.w_input.value
    ), f"Input out should be {dut.w_input.value}. Got: {dut.w_inp_out.value}"

    # Test: Write without stream
    dut.w_rw.value = 0
    dut.w_stream.value = 0
    dut.w_weight.value = random.randint(0, (2**OUT_PE_WEIGHT_WIDTH) - 1)
    dut.w_input.value = random.randint(0, (2**OUT_PE_INPUT_WIDTH) - 1)
    prev_fwd = dut.r_fwd.value

    await RisingEdge(dut.w_clock)
    await Timer(1, units="ns")

    assert (
        dut.w_out.value == dut.r_scratch.value
    ), f"Output should be {dut.r_scratch.value}. Got: {dut.w_out.value}"
    assert (
        dut.r_fwd.value == prev_fwd
    ), f"Forward reg should be {prev_fwd}. Got: {dut.r_fwd.value}"
    assert (
        dut.r_scratch.value == prod
    ), f"Scratch should be {prod}. Got: {dut.r_scratch.value}"
    assert (
        dut.r_pipeline.value == 0
    ), f"Pipeline should be zero. Got: {dut.r_pipeline.value}"
    assert (
        dut.w_wgt_out.value == dut.w_weight.value
    ), f"Weight out should be {dut.w_weight.value}. Got: {dut.w_wgt_out.value}"
    assert (
        dut.w_inp_out.value == dut.w_input.value
    ), f"Input out should be {dut.w_input.value}. Got: {dut.w_inp_out.value}"
