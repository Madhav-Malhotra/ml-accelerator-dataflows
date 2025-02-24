#############################################
# Flags
#############################################

# Parameters for simulation
SIM ?= icarus
WAVES=1

# Directory structure
VERILOG_SOURCES_DIR := src
TEST_DIR := test
BUILD_DIR := sim_build
VERILOG_INCLUDE_DIRS := $(VERILOG_SOURCES_DIR)
WAVES_DIR := test/waves

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

.PHONY: clean_local help_local test show gtkw $(PARAMS_VH)

# Ensure parameters.vh is always up-to-date
$(PARAMS_VH):
	$(MAKE) clean_local
	@echo "Updating Verilog parameters..."
	@python3 $(PARAMS_SCRIPT)

# Need to call this target so that parameters.vh is generated before running test
test: $(PARAMS_VH)
	$(MAKE) SIM=$(SIM) MOD_TYPE=$(MOD_TYPE) MOD=$(MOD) 
	@if [ -f $(BUILD_DIR)/$(MOD).fst ]; then \
		mv $(BUILD_DIR)/$(MOD).fst $(WAVES_DIR)/$(MOD).fst; \
		echo "Moved $(BUILD_DIR)/$(MOD).fst to $(WAVES_DIR)/$(MOD).fst"; \
	else \
		echo "Error: Failed to find dumpfile $(BUILD_DIR)/$(MOD).fst"; \
	fi

# Generate GTKW file for module
gtkw:
	@if [ -z "$(MOD)" ]; then \
		echo "Error: Please specify a module with MOD=<module_name>"; \
		exit 1; \
	fi
	@if [ ! -f "$(VERILOG_SOURCES_DIR)/$(MOD_TYPE)/$(MOD).v" ]; then \
		echo "Error: Verilog file $(VERILOG_SOURCES_DIR)/$(MOD_TYPE)/$(MOD).v not found"; \
		exit 1; \
	fi
	@echo "Generating GTKWave save file for $(MOD)..."
	@python3 gtkw_generator.py --src-dir=$(VERILOG_SOURCES_DIR) --waves-dir=$(WAVES_DIR) --mod-type=$(MOD_TYPE) --mod=$(MOD) --parameters=$(PARAMS_JSON)

# Show waveform for a specific module
show: gtkw
	@if [ -z "$(MOD)" ]; then \
		echo "Error: Please specify a module with MOD=<module_name>"; \
		exit 1; \
	fi
	@if [ ! -f "$(WAVES_DIR)/$(MOD).fst" ]; then \
		echo "Error: Waveform file $(WAVES_DIR)/$(MOD).fst not found"; \
		echo "You may need to run 'make test MOD=$(MOD) MOD_TYPE=$(MOD_TYPE)' first"; \
		exit 1; \
	fi
	@echo "Opening waveform for $(MOD)..."
	@if [ ! -f "$(WAVES_DIR)/$(MOD).gtkw" ]; then \
		echo "Warning: GTKWave save file $(WAVES_DIR)/$(MOD).gtkw not found"; \
		gtkwave $(WAVES_DIR)/$(MOD).fst & \
	else \
		gtkwave $(WAVES_DIR)/$(MOD).gtkw & \
	fi

# Clean build files
clean_local:
	@rm -rf $(BUILD_DIR)
	@rm -rf __pycache__
	@rm -rf *.xml
	@rm -rf results.xml
	@find . -name "*.pyc" -delete
	@find . -name "__pycache__" -delete
	@rm -f $(VERILOG_SOURCES_DIR)/$(PARAMS_VH)
	@rm -f $(WAVES_DIR)/*.fst
	@rm -f $(WAVES_DIR)/*.gtkw

help_local:
	@echo "Usage:"
	@echo "  make test MOD_TYPE=<type> MOD=<name>"
	@echo "  where <type> is 'output' or 'weight'"
	@echo "  and <name> is the module name without .v extension"
	@echo ""
	@echo "Example:"
	@echo "  make test MOD_TYPE=output MOD=arbiter"
	@echo "  make test MOD_TYPE=weight MOD=pe"
	@echo ""
	@echo "To see the test waveform after running the test:"
	@echo "  make show MOD=<name>"
	@echo ""
	@echo "To clean all files:"
	@echo "  make clean_local"