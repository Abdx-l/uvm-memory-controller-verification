module top;
 import uvm_pkg::*;import memory_pkg::*;
 bit clk=0;always #5 clk=~clk;
 mem_if bus(clk);
 wire [2:0] cmd;wire [1:0] cmd_bank;wire [3:0] cmd_row,cmd_col;
 wire [31:0] cmd_wdata,mem_rdata;
 ddr_controller #(.TREFI(80)) dut(
 .clk(clk),.rst(bus.rst),.valid(bus.valid),.write(bus.write),.bank(bus.bank),.row(bus.row),.col(bus.col),
 .wdata(bus.wdata),.ready(bus.ready),.rvalid(bus.rvalid),.rdata(bus.rdata),.*);
 memory_model memory(.clk(clk),.rst(bus.rst),.cmd(cmd),.bank(cmd_bank),.row(cmd_row),.col(cmd_col),.wdata(cmd_wdata),.rdata(mem_rdata));
 initial begin bus.rst=1;repeat(4) @(negedge clk);bus.rst=0;end
 initial begin uvm_config_db#(virtual mem_if)::set(null,"*","vif",bus);run_test("memory_test");end
 initial begin #1000000;$fatal(1,"timeout");end
endmodule
