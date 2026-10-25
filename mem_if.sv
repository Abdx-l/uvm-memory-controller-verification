interface mem_if(input logic clk);
 logic rst,valid,write,ready,rvalid;
 logic [1:0] bank;
 logic [3:0] row,col;
 logic [31:0] wdata,rdata;
 // Values are sampled on the falling edge, away from RTL updates.
 property stable_request;
  @(posedge clk) disable iff(rst) valid && !ready |=> $stable({write,bank,row,col,wdata});
 endproperty
 assert property(stable_request);
 property completion_bounded;
  @(posedge clk) disable iff(rst) valid && ready |-> ##[1:100] rvalid;
 endproperty
 assert property(completion_bounded);
endinterface
