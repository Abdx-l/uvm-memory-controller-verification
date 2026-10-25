onerror {quit -code 1}
vlib work
vlog -sv +incdir+$env(UVM_HOME)/src $env(UVM_HOME)/src/uvm_pkg.sv mem_if.sv memory_pkg.sv rtl/ddr_controller.sv tb/memory_model.sv top.sv
vsim -c -coverage top +UVM_TESTNAME=memory_test -do "run -all; coverage save coverage.ucdb; quit -f"
