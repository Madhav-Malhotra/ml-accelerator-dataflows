#############################################
# Flags
#############################################

# Default simulation tool
SIM ?= icarus

# Directory structure
VERILOG_SOURCES_DIR := src
TEST_DIR := test
BUILD_DIR := sim_build
VERILOG_INCLUDE_DIRS := $(VERILOG_SOURCES_DIR)

# Module type can be 'output' or 'weight'
MOD_TYPE ?= output
# Module name without .v extension (e.g., arbiter, pe, control, etc.)
MOD ?= arbiter

# Verilog parameters file
PARAMS_JSON := parameters.json
PARAMS_VH := parameters.vh
PARAMS_SCRIPT := generate_parameters.py

# Determine paths based on MODULE_TYPE and MODULE
VERILOG_SOURCES := $(VERILOG_SOURCES_DIR)/$(MOD_TYPE)/$(MOD).v $(VERILOG_SOURCES_DIR)/$(PARAMS_VH)
TOPLEVEL := $(MOD)
MODULE := $(TEST_DIR).$(MOD_TYPE).$(MOD)

# Python test file
PYTHONPATH := .
TOPLEVEL_LANG := verilog

# Include cocotb's Makefile
include $(shell cocotb-config --makefiles)/Makefile.sim




#############################################
# Targets
#############################################

.PHONY: clean_local help_local test $(PARAMS_VH)

# Ensure parameters.vh is always up-to-date
$(PARAMS_VH):
	@echo "Updating Verilog parameters..."
	@python3 $(PARAMS_SCRIPT)

# Need to call this target so that parameters.vh is generated before running test
test: $(PARAMS_VH)
	$(MAKE) SIM=$(SIM) MOD_TYPE=$(MOD_TYPE) MOD=$(MOD) 

# Clean build files
clean_local:
	@rm -rf $(BUILD_DIR)
	@rm -rf __pycache__
	@rm -rf *.xml
	@rm -rf results.xml
	@find . -name "*.pyc" -delete
	@find . -name "__pycache__" -delete
	@rm -f $(VERILOG_SOURCES_DIR)/$(PARAMS_VH)

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