# Default simulation tool
SIM ?= icarus

# Directory structure
VERILOG_SOURCES_DIR := src
TEST_DIR := test
BUILD_DIR := sim_build

# Module type can be 'output' or 'weight'
MOD_TYPE ?= output
# Module name without .v extension (e.g., arbiter, pe, control, etc.)
MOD ?= arbiter

# Determine paths based on MODULE_TYPE and MODULE
VERILOG_SOURCES := $(VERILOG_SOURCES_DIR)/$(MOD_TYPE)/$(MOD).v
TOPLEVEL := $(MODULE)
MODULE := $(TEST_DIR).$(MOD_TYPE).$(MOD)

# Python test file
PYTHONPATH := .
TOPLEVEL_LANG := verilog

# Include cocotb's Makefile
include $(shell cocotb-config --makefiles)/Makefile.sim

# Clean build files
clean_local:
	@rm -rf $(BUILD_DIR)
	@rm -rf __pycache__
	@rm -rf *.xml
	@rm -rf results.xml
	@find . -name "*.pyc" -delete
	@find . -name "__pycache__" -delete

.PHONY: clean_local help_local

help_local:
	@echo "Usage:"
	@echo "  make MOD_TYPE=<type> MOD=<name>"
	@echo "  where <type> is 'output' or 'weight'"
	@echo "  and <name> is the module name without .v extension"
	@echo ""
	@echo "Example:"
	@echo "  make MOD_TYPE=output MOD=arbiter"
	@echo "  make MOD_TYPE=weight MOD=pe"
	@echo ""
	@echo "To clean all files:"
	@echo "  make clean_local"