module memory_model #(
 parameter BANKS=4, ROWS=16, COLS=16, DATA_W=32, TRCD=3, TRP=3, TRAS=7, TRFC=10
)(
 input logic clk,rst,
 input logic [2:0] cmd,
 input logic [$clog2(BANKS)-1:0] bank,
 input logic [$clog2(ROWS)-1:0] row,
 input logic [$clog2(COLS)-1:0] col,
 input logic [DATA_W-1:0] wdata,
 output logic [DATA_W-1:0] rdata
);
 logic [DATA_W-1:0] mem[0:BANKS-1][0:ROWS-1][0:COLS-1];
 integer opened[0:BANKS-1], act_at[0:BANKS-1], pre_at[0:BANKS-1];
 integer tick, refresh_until, i;
 always @(posedge clk) begin
  if(rst) begin
   tick=0; refresh_until=0; rdata=0;
   for(i=0;i<BANKS;i=i+1) begin opened[i]=-1; act_at[i]=-1000; pre_at[i]=-1000; end
  end else begin
   tick=tick+1;
   if(cmd!=0 && tick<refresh_until) $fatal(1,"command during refresh");
   case(cmd)
    1: begin
     if(opened[bank]!=-1 || tick-pre_at[bank]<TRP) $fatal(1,"ACT timing");
     opened[bank]=row; act_at[bank]=tick;
    end
    2,3: begin
     if(opened[bank]<0 || tick-act_at[bank]<TRCD) $fatal(1,"column timing");
     if(cmd==3) mem[bank][opened[bank]][col]=wdata;
     else rdata=mem[bank][opened[bank]][col];
    end
    4: begin
     if(opened[bank]<0 || tick-act_at[bank]<TRAS) $fatal(1,"PRE timing");
     opened[bank]=-1; pre_at[bank]=tick;
    end
    5: begin
     for(i=0;i<BANKS;i=i+1)
      if(opened[i]!=-1 || tick-pre_at[i]<TRP) $fatal(1,"REF timing");
     refresh_until=tick+TRFC;
    end
   endcase
  end
 end
endmodule
