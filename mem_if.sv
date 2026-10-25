interface mem_if(input logic clk);
 logic rst,valid,write,ready,rvalid;
 logic [1:0] bank;
 logic [3:0] row,col;
 logic [31:0] wdata,rdata;
 logic [2:0] command;
 logic [1:0] command_bank;
 logic [3:0] command_row;
 // Driver changes requests on falling edges; monitor samples before NBA updates.
 property stable_request;
  @(posedge clk) disable iff(rst) valid && !ready |=> $stable({write,bank,row,col,wdata});
 endproperty
 assert property(stable_request);
 property completion_bounded;
  @(posedge clk) disable iff(rst) valid && ready |-> ##[1:100] rvalid;
 endproperty
 assert property(completion_bounded);
endinterface
