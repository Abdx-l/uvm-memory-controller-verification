module ddr_controller #(
 parameter integer BANKS=4, ROWS=16, COLS=16, DATA_W=32,
 parameter integer TRCD=3, TRP=3, TRAS=7, TRFC=10, TREFI=200, TCL=3
)(
 input logic clk, rst,
 input logic valid, write,
 input logic [$clog2(BANKS)-1:0] bank,
 input logic [$clog2(ROWS)-1:0] row,
 input logic [$clog2(COLS)-1:0] col,
 input logic [DATA_W-1:0] wdata,
 output logic ready, rvalid,
 output logic [DATA_W-1:0] rdata,
 output logic [2:0] cmd,
 output logic [$clog2(BANKS)-1:0] cmd_bank,
 output logic [$clog2(ROWS)-1:0] cmd_row,
 output logic [$clog2(COLS)-1:0] cmd_col,
 output logic [DATA_W-1:0] cmd_wdata,
 input logic [DATA_W-1:0] mem_rdata
);
 localparam NOP=0, ACT=1, RD=2, WR=3, PRE=4, REF=5;
 localparam IDLE=0, ACCESS=1, RETURN=2, REFRESH=3;
 integer state, wait_cycles, refresh_age;
 integer cooldown[0:BANKS-1], active_age[0:BANKS-1];
 logic opened[0:BANKS-1];
 logic [$clog2(ROWS)-1:0] open_row[0:BANKS-1];
 logic [$clog2(BANKS)-1:0] b;
 logic [$clog2(ROWS)-1:0] r;
 logic [$clog2(COLS)-1:0] c;
 logic wr;
 logic [DATA_W-1:0] data;
 integer i, close_bank;
 logic all_closed, all_ready;
 always_comb begin
  all_closed=1; all_ready=1; close_bank=-1;
  for(integer j=0;j<BANKS;j=j+1) begin
   if(opened[j]) all_closed=0;
   if(opened[j] && cooldown[j]==0 && active_age[j]>=TRAS) close_bank=j;
   if(cooldown[j]>0) all_ready=0;
  end
  ready=(state==IDLE && refresh_age<TREFI);
 end
 always_ff @(posedge clk) begin
  if(rst) begin
   state<=IDLE; wait_cycles<=0; refresh_age<=0;
   cmd<=NOP; cmd_bank<=0; cmd_row<=0; cmd_col<=0; cmd_wdata<=0;
   rvalid<=0; rdata<=0; b<=0; r<=0; c<=0; wr<=0; data<=0;
   for(i=0;i<BANKS;i=i+1) begin
    opened[i]<=0; open_row[i]<=0; cooldown[i]<=0; active_age[i]<=0;
   end
  end else begin
   cmd<=NOP; rvalid<=0;
   refresh_age<=refresh_age+1;
   for(i=0;i<BANKS;i=i+1) begin
    if(cooldown[i]>0) cooldown[i]<=cooldown[i]-1;
    if(opened[i]) active_age[i]<=active_age[i]+1;
   end
   case(state)
    IDLE: begin
     if(refresh_age>=TREFI) state<=REFRESH;
     else if(valid && ready) begin
      b<=bank; r<=row; c<=col; wr<=write; data<=wdata; state<=ACCESS;
     end
    end
    ACCESS: begin
     cmd_bank<=b; cmd_row<=r; cmd_col<=c; cmd_wdata<=data;
     if(cooldown[b]==0) begin
      if(opened[b] && open_row[b]!=r) begin
       if(active_age[b]>=TRAS) begin
        cmd<=PRE; opened[b]<=0; cooldown[b]<=TRP;
       end
      end else if(!opened[b]) begin
       cmd<=ACT; opened[b]<=1; open_row[b]<=r;
       active_age[b]<=0; cooldown[b]<=TRCD;
      end else begin
       cmd<=wr?WR:RD; wait_cycles<=TCL+1; state<=RETURN;
       cooldown[b]<=TCL+1;
      end
     end
    end
    RETURN: begin
     if(wait_cycles>0) wait_cycles<=wait_cycles-1;
     else begin
      rvalid<=1;
      if(!wr) rdata<=mem_rdata;
      else rdata<=data;
      state<=IDLE;
     end
    end
    REFRESH: begin
     if(wait_cycles>0) begin
      wait_cycles<=wait_cycles-1;
      if(wait_cycles==1) begin state<=IDLE; refresh_age<=0; end
     end else if(all_closed && all_ready) begin
      cmd<=REF; wait_cycles<=TRFC+1;
     end else begin
      if(close_bank>=0) begin
       cmd<=PRE; cmd_bank<=close_bank; opened[close_bank]<=0; cooldown[close_bank]<=TRP;
      end
     end
    end
   endcase
  end
 end
endmodule
