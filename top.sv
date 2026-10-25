module top;
 import uvm_pkg::*;import memory_pkg::*;
 bit clk=0;always #5 clk=~clk;
 mem_if bus(clk);
 wire [2:0] cmd;wire [1:0] cmd_bank;wire [3:0] cmd_row,cmd_col;
 wire [31:0] cmd_wdata,mem_rdata;
 wire [31:0] dut_rdata;
 bit inject_read_error;
 assign bus.command=cmd;
 assign bus.command_bank=cmd_bank;
 assign bus.command_row=cmd_row;
 assign bus.rdata=dut_rdata ^ (inject_read_error ? 32'h1 : 32'h0);
 initial inject_read_error=$test$plusargs("INJECT_READ_ERROR");
 ddr_controller #(.TREFI(80)) dut(
 .clk(clk),.rst(bus.rst),.valid(bus.valid),.write(bus.write),.bank(bus.bank),.row(bus.row),.col(bus.col),
 .wdata(bus.wdata),.ready(bus.ready),.rvalid(bus.rvalid),.rdata(dut_rdata),.*);
 memory_model memory(.clk(clk),.rst(bus.rst),.cmd(cmd),.bank(cmd_bank),.row(cmd_row),.col(cmd_col),.wdata(cmd_wdata),.rdata(mem_rdata));
 initial begin bus.rst=1;repeat(4) @(negedge clk);bus.rst=0;end
 initial begin
 uvm_report_server report_server;
 uvm_root root_;
 root_=uvm_root::get();
 root_.set_finish_on_completion(0);
 uvm_config_db#(virtual mem_if)::set(null,"*","vif",bus);run_test();
 report_server=uvm_report_server::get_server();
 if(report_server.get_severity_count(UVM_ERROR)>0 || report_server.get_severity_count(UVM_FATAL)>0) $fatal(1,"UVM checks failed");
 $finish;
 end
 initial begin #1000000;$fatal(1,"timeout");end
endmodule
