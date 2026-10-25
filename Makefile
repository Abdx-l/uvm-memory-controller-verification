TOOL_ROOT ?= $(CURDIR)/.deps/verilator
VERILATOR ?= $(TOOL_ROOT)/bin/verilator
UVM_HOME ?= $(TOOL_ROOT)/share/uvm/src
JOBS ?= 2
SOURCES = mem_if.sv memory_pkg.sv rtl/ddr_controller.sv tb/memory_model.sv top.sv

.PHONY: setup build test
setup:
	bash scripts/setup.sh "$(TOOL_ROOT)"

build: setup
	$(VERILATOR) --binary --timing --assert --coverage -j $(JOBS) \
		-Wno-fatal -Wno-WIDTH --timescale 1ns/1ps --top-module top \
		-CFLAGS -O0 +define+UVM_NO_DPI -I"$(UVM_HOME)" \
		"$(UVM_HOME)/uvm_pkg.sv" $(SOURCES)

test: build
	PATH="$(TOOL_ROOT)/bin:$$PATH" python3 scripts/regress.py
