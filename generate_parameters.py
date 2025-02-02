"""
Do not run this yourself. This script is called by the Makefile to send 
parameters to the Verilog files and testbenches.
"""

import json

JSON_FILE = "parameters.json"
HEADER_FILE = "src/parameters.vh"


def generate_verilog_header():
    """Reads parameters from JSON and writes to a Verilog header file."""
    try:
        with open(JSON_FILE, "r") as f:
            params = json.load(f)
    except FileNotFoundError:
        print(f"Error: {JSON_FILE} not found.")
        raise SystemExit(1)

    with open(HEADER_FILE, "w") as f:
        f.write("// Auto-generated Verilog header file\n")
        f.write("// Do not modify manually. Update parameters.json instead.\n\n")
        f.write("`ifndef PARAMETERS_VH\n")
        f.write("`define PARAMETERS_VH\n\n")

        for key, value in params.items():
            f.write(f"`define {key} {value}\n")

        f.write("\n`endif\n")

    print(f"Generated {HEADER_FILE} from {JSON_FILE}")


if __name__ == "__main__":
    generate_verilog_header()
