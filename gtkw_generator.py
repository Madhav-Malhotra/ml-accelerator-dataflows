#!/usr/bin/env python3
"""
GTKWave Save File Generator

This script generates GTKWave save files (.gtkw) for Verilog modules to automatically
display all signals and parameters in the waveform viewer.
"""

import os
import re
import sys
import json
import argparse
from datetime import datetime
from vcd.gtkw import GTKWSave, GTKWColor


def parse_verilog_file(verilog_path: str, params_path: str) -> dict:
    """Parse a Verilog file to extract module parameters and signals."""
    with open(verilog_path, "r") as f:
        content = f.read()

    # Load parameters from JSON file
    with open(params_path, "r") as f:
        params_dict = json.load(f)

    # Extract module name
    module_match = re.search(r"module\s+(\w+)\s*#?\s*\(", content)
    if not module_match:
        raise ValueError(f"Could not find module declaration in {verilog_path}")

    module_name = module_match.group(1)

    # Extract parameters
    params = []
    param_pattern = r"parameter\s+(\w+)\s*=\s*(.+?)(?:,|\)|\n)"
    for match in re.finditer(param_pattern, content):
        param_name = match.group(1)
        params.append(param_name)

    # Also search for parameters defined with `define
    define_params = {}
    define_pattern = r"`(\w+)"
    for match in re.finditer(define_pattern, content):
        define_name = match.group(1)
        if (
            define_name not in ["include", "ifdef", "endif"]
            and define_name not in define_params.keys()
        ):
            # Intentionallly let this fail if parameter isn't defined
            # Something's very wrong if this happens
            define_params[define_name] = params_dict[define_name]

    # Extract input and output signals
    signals = []
    signal_pattern = (
        r"(input|output)\s+(?:wire|reg)?\s*(?:\[\s*([^:]+)\s*:\s*([^]]+)\s*\])?\s*(\w+)"
    )
    for match in re.finditer(signal_pattern, content):
        direction = match.group(1)
        msb = match.group(2)
        lsb = match.group(3)
        signal_name = match.group(4)

        if msb and lsb:
            signals.append((direction, signal_name, msb, lsb))
        else:
            signals.append((direction, signal_name, None, None))

    # Extract internal registers and wires
    internal_signals = []
    internal_pattern = r"(?:reg|wire)\s+(?:\[\s*([^:]+)\s*:\s*([^]]+)\s*\])?\s*(\w+)"
    for match in re.finditer(internal_pattern, content):
        msb = match.group(1)
        lsb = match.group(2)
        signal_name = match.group(3)

        # Make sure this isn't already in the signals list (as inputs/outputs)
        signal_exists = False
        for _, existing_name, _, _ in signals:
            if signal_name == existing_name:
                signal_exists = True
                break

        if not signal_exists:
            if msb and lsb:
                internal_signals.append(("internal", signal_name, msb, lsb))
            else:
                internal_signals.append(("internal", signal_name, None, None))

    return {
        "module_name": module_name,
        "parameters": params,
        "define_parameters": define_params,
        "signals": signals,
        "internal_signals": internal_signals,
    }


def evaluate_bit_expression(expr, define_params):
    """Evaluate a bit expression using the define parameters"""
    # Replace parameter references with their values
    for param, value in define_params.items():
        expr = expr.replace(param, str(value))

    # Replace remaining Verilog parameter references with their values
    expr = re.sub(r"`(\w+)", lambda m: str(define_params.get(m.group(1), 0)), expr)

    # Handle simple arithmetic expressions like "PARAM-1"
    expr = expr.replace("-", " - ").replace("+", " + ")
    tokens = expr.split()

    # Simple evaluation for expressions like "X-1" or "X+1"
    if len(tokens) == 3 and tokens[1] in ["-", "+"]:
        try:
            left = int(tokens[0])
            right = int(tokens[2])
            if tokens[1] == "-":
                return left - right
            else:
                return left + right
        except ValueError:
            pass

    # Try direct conversion for simple values
    try:
        return int(expr)
    except ValueError:
        # If we can't evaluate, return the original expression
        return expr


def create_vector_signal_name(signal_name, msb, lsb, define_params):
    """Create a signal name with bit range for vector signals"""
    if msb is None or lsb is None:
        return signal_name  # Not a vector

    # Evaluate MSB and LSB expressions
    msb_val = msb
    lsb_val = lsb

    # Try to evaluate expressions containing parameters
    if isinstance(msb, str):
        msb_val = evaluate_bit_expression(msb, define_params)
    if isinstance(lsb, str):
        lsb_val = evaluate_bit_expression(lsb, define_params)

    # If we have numeric values, use them
    if isinstance(msb_val, int) and isinstance(lsb_val, int):
        return f"{signal_name}[{msb_val}:{lsb_val}]"

    # If we still have expressions, try to simplify them
    for param, value in define_params.items():
        if isinstance(msb_val, str):
            msb_val = msb_val.replace(param, str(value))
        if isinstance(lsb_val, str):
            lsb_val = lsb_val.replace(param, str(value))

    # Create the signal name with bit range
    return f"{signal_name}[{msb_val}:{lsb_val}]"


def trace_signals(
    define_params: dict,
    module_name: str,
    save: GTKWSave,
    save_group: str,
    signals: list,
    colour: str = "",
):
    """Trace a signal with a specific colour"""
    # Load colour
    colour_map = {
        "red": GTKWColor.red,
        "orange": GTKWColor.orange,
        "yellow": GTKWColor.yellow,
        "green": GTKWColor.green,
        "blue": GTKWColor.blue,
        "indigo": GTKWColor.indigo,
        "violet": GTKWColor.violet,
        "normal": GTKWColor.normal,
        "cycle": GTKWColor.cycle,
    }

    if colour_map.get(colour) is None:
        colour = "normal"

    with save.group(save_group, closed=False, highlight=False):
        for _, sig_name, msb, lsb in signals:
            out_sig_name = sig_name
            datafmt = "bin"

            # Vector signal
            if msb or lsb:
                out_sig_name = create_vector_signal_name(
                    sig_name, msb, lsb, define_params
                )
                datafmt = "hex"

            save.trace(
                f"{module_name}.{out_sig_name}",
                datafmt=datafmt,
                color=colour_map[colour],
            )


def create_gtkw_file(module_info: dict, waves_dir: str, fst_path: str):
    """Create a GTKWave save file for the parsed Verilog module."""
    module_name = module_info["module_name"]
    gtkw_path = os.path.join(waves_dir, f"{module_name}.gtkw")

    with open(gtkw_path, "w") as f:
        save = GTKWSave(f)

        # Add header information
        save.comment("*")
        save.comment("* GTKWave Analyzer save file - Auto-generated")
        save.comment(
            f"* Generated on {datetime.now().strftime('%a %b %d %H:%M:%S %Y')}"
        )
        save.comment("*")

        # Set up basic configuration
        save.dumpfile(fst_path)
        save.dumpfile_mtime(datetime.now().timestamp())
        save.savefile(gtkw_path)
        save.timestart(0)

        # Set window size and position
        save.size(1900, 1000)
        save.pos(-1, -1)

        # Configure GTKWave display
        save.zoom_markers(zoom=0.0)
        save.signals_width(250)
        save.sst_expanded(True)

        # Display parameters first
        if module_info["parameters"]:
            with save.group("Parameters", closed=False, highlight=False):
                for param in module_info["parameters"]:
                    save.trace(f"{module_name}.{param}", datafmt="dec")

        # Display input signals
        trace_signals(
            module_info["define_parameters"],
            module_name,
            save,
            "Inputs",
            module_info["signals"],
            "yellow",
        )

        # Display output signals
        trace_signals(
            module_info["define_parameters"],
            module_name,
            save,
            "Outputs",
            module_info["signals"],
            "red",
        )

        # Display internal signals
        trace_signals(
            module_info["define_parameters"],
            module_name,
            save,
            "Internals",
            module_info["internal_signals"],
            "blue",
        )

        # Enable pattern tracing
        save.pattern_trace(True)

    print(f"Created GTKWave save file: {gtkw_path}")
    return gtkw_path


def main():
    parser = argparse.ArgumentParser(
        description="Generate GTKWave save files for Verilog modules"
    )
    parser.add_argument(
        "--src-dir", default="src", help="Directory containing Verilog source files"
    )
    parser.add_argument(
        "--waves-dir", default="test/waves", help="Directory for GTKWave save files"
    )
    parser.add_argument(
        "--mod-type", default="output", help="Module type (subdirectory)"
    )
    parser.add_argument(
        "--parameters",
        default="parameters.json",
        help="JSON file containing parameters",
    )
    parser.add_argument("--mod", required=True, help="Module name")

    args = parser.parse_args()

    # Ensure waves directory exists
    os.makedirs(args.waves_dir, exist_ok=True)

    # Find Verilog source file
    verilog_path = os.path.join(args.src_dir, args.mod_type, f"{args.mod}.v")
    if not os.path.exists(verilog_path):
        print(f"Error: Verilog file not found: {verilog_path}")
        sys.exit(1)

    # Determine path to FST file
    fst_path = os.path.join(args.waves_dir, f"{args.mod}.fst")

    try:
        # Parse Verilog file
        module_info = parse_verilog_file(verilog_path, args.parameters)
        print(module_info)

        # Create GTKWave save file
        gtkw_path = create_gtkw_file(module_info, args.waves_dir, fst_path)

        print(f"Successfully created GTKWave save file: {gtkw_path}")
        print(f"Use 'gtkwave {gtkw_path}' to view waveforms")

    except Exception as e:
        print(f"Error: {e}")
        sys.exit(1)


if __name__ == "__main__":
    main()
