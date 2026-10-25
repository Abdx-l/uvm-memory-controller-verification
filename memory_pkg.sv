package memory_pkg;
 import uvm_pkg::*;
 `include "uvm_macros.svh"
 class mem_item extends uvm_sequence_item;
  rand bit write;
  rand bit [1:0] bank;
  rand bit [3:0] row,col;
  rand bit [31:0] data;
  bit [31:0] result;
  bit abort_with_reset;
  `uvm_object_utils_begin(mem_item)
   `uvm_field_int(write,UVM_ALL_ON)
   `uvm_field_int(bank,UVM_ALL_ON)
   `uvm_field_int(row,UVM_ALL_ON)
   `uvm_field_int(col,UVM_ALL_ON)
   `uvm_field_int(data,UVM_ALL_ON)
   `uvm_field_int(result,UVM_ALL_ON)
   `uvm_field_int(abort_with_reset,UVM_ALL_ON)
  `uvm_object_utils_end
  function new(string name="mem_item");super.new(name);endfunction
 endclass
 class traffic extends uvm_sequence #(mem_item);
  `uvm_object_utils(traffic)
  function new(string name="traffic");super.new(name);endfunction
  task initialize_memory();
   mem_item t;
   // Initialize every location before random read/write traffic.
   for(int b=0;b<4;b++) for(int r=0;r<4;r++) for(int c=0;c<16;c++) begin
    t=mem_item::type_id::create("init"); start_item(t);
    t.write=1;t.bank=b;t.row=r;t.col=c;t.data=(b<<8)|(r<<4)|c;finish_item(t);
   end
  endtask
  task random_accesses();
   mem_item t;
   repeat(1000) begin
    t=mem_item::type_id::create("random");start_item(t);
    if(!t.randomize() with {row<4;col<4;}) `uvm_fatal("RAND","randomization failed")
    finish_item(t);
   end
  endtask
  task body();
   initialize_memory();
   random_accesses();
  endtask
 endclass
 class reset_traffic extends traffic;
  `uvm_object_utils(reset_traffic)
  function new(string name="reset_traffic");super.new(name);endfunction
  task body();
   mem_item t;
   initialize_memory();
   t=mem_item::type_id::create("interrupted_write");start_item(t);
   t.write=1;t.bank=0;t.row=0;t.col=0;t.data=32'hdeadbeef;t.abort_with_reset=1;
   finish_item(t);
   // The interrupted write must not alter initialized address zero.
   t=mem_item::type_id::create("read_after_reset");start_item(t);
   t.write=0;t.bank=0;t.row=0;t.col=0;finish_item(t);
   t=mem_item::type_id::create("new_write");start_item(t);
   t.write=1;t.bank=3;t.row=2;t.col=1;t.data=32'h13579bdf;finish_item(t);
   t=mem_item::type_id::create("read_new_write");start_item(t);
   t.write=0;t.bank=3;t.row=2;t.col=1;finish_item(t);
   random_accesses();
  endtask
 endclass
 class mem_driver extends uvm_driver #(mem_item);
  `uvm_component_utils(mem_driver)
  virtual mem_if vif;
  function new(string n,uvm_component p);super.new(n,p);endfunction
  function void build_phase(uvm_phase phase);
   if(!uvm_config_db#(virtual mem_if)::get(this,"","vif",vif)) `uvm_fatal("VIF","interface missing")
  endfunction
  task run_phase(uvm_phase phase);
   mem_item t;
   vif.valid=0;
   wait(!vif.rst);
   forever begin
    seq_item_port.get_next_item(t);
    @(negedge vif.clk);
    vif.valid=1;vif.write=t.write;vif.bank=t.bank;vif.row=t.row;vif.col=t.col;vif.wdata=t.data;
    while(!vif.ready) @(negedge vif.clk);
    @(negedge vif.clk);vif.valid=0;
    if(t.abort_with_reset) begin
     vif.rst=1;repeat(4) @(negedge vif.clk);vif.rst=0;
     seq_item_port.item_done();continue;
    end
    while(!vif.rvalid) @(negedge vif.clk);
    seq_item_port.item_done();
   end
  endtask
 endclass
 class mem_monitor extends uvm_monitor;
  `uvm_component_utils(mem_monitor)
  virtual mem_if vif;
  uvm_analysis_port#(mem_item) ap;
  int bank_direction[4][2];
  int row_hits=0,conflicts=0,refreshes=0,resets=0,aborted=0;
  covergroup accesses;
   option.per_instance=1;
   rw:coverpoint vif.write;
   banks:coverpoint vif.bank;
   rows:coverpoint vif.row {bins low[]={[0:3]};}
   mix:cross rw,banks;
   reset_state:coverpoint vif.rst;
  endgroup
  function new(string n,uvm_component p);super.new(n,p);ap=new("ap",this);accesses=new;endfunction
  function void build_phase(uvm_phase phase);
   if(!uvm_config_db#(virtual mem_if)::get(this,"","vif",vif)) `uvm_fatal("VIF","interface missing")
  endfunction
  task run_phase(uvm_phase phase);
   mem_item pending;
   bit previous_reset=0;
   int open_rows[4]='{-1,-1,-1,-1};
   forever begin
    @(posedge vif.clk);
    if(vif.rst) begin
     if(!previous_reset) begin
      resets++;if(pending!=null)aborted++;
     end
     previous_reset=1;pending=null;open_rows='{-1,-1,-1,-1};accesses.sample();
    end
    else begin
     previous_reset=0;
     case(vif.command)
      1:open_rows[vif.command_bank]=int'(vif.command_row);
      4:open_rows[vif.command_bank]=-1;
      5:begin open_rows='{-1,-1,-1,-1};refreshes++;end
     endcase
     if(vif.valid && vif.ready) begin
      pending=mem_item::type_id::create("observed");
      pending.write=vif.write;pending.bank=vif.bank;pending.row=vif.row;pending.col=vif.col;pending.data=vif.wdata;
      bank_direction[vif.bank][vif.write]++;
      if(open_rows[vif.bank]==int'(vif.row))row_hits++;
      else if(open_rows[vif.bank]>=0)conflicts++;
      accesses.sample();
     end
     if(vif.rvalid && pending!=null) begin
      pending.result=vif.rdata;ap.write(pending);pending=null;
     end
    end
   end
  endtask
 endclass
 class mem_scoreboard extends uvm_scoreboard;
  `uvm_component_utils(mem_scoreboard)
  uvm_analysis_imp#(mem_item,mem_scoreboard) imp;
  bit [31:0] reference[int];
  int checked=0,reads=0,writes=0,expected=1256;
  function new(string n,uvm_component p);super.new(n,p);imp=new("imp",this);endfunction
  function void build_phase(uvm_phase phase);
   void'(uvm_config_db#(int)::get(this,"","expected",expected));
  endfunction
  function void write(mem_item t);
   int address=(int'(t.bank)<<8)|(int'(t.row)<<4)|int'(t.col);
   if(t.write) begin reference[address]=t.data;writes++;end
   else begin
    reads++;
    if(!reference.exists(address) || reference[address]!==t.result)
     `uvm_error("DATA",$sformatf("address %0h expected %0h got %0h",address,reference[address],t.result))
   end
   checked++;
  endfunction
  function void check_phase(uvm_phase phase);
   if(checked!=expected) `uvm_error("COUNT",$sformatf("checked %0d expected %0d",checked,expected))
  endfunction
 endclass
 class mem_agent extends uvm_agent;
  `uvm_component_utils(mem_agent)
  uvm_sequencer#(mem_item) sequencer;
  mem_driver driver;mem_monitor monitor;
  function new(string n,uvm_component p);super.new(n,p);endfunction
  function void build_phase(uvm_phase phase);
   sequencer=new("sequencer",this);
   driver=mem_driver::type_id::create("driver",this);
   monitor=mem_monitor::type_id::create("monitor",this);
  endfunction
  function void connect_phase(uvm_phase phase);driver.seq_item_port.connect(sequencer.seq_item_export);endfunction
 endclass
 class mem_env extends uvm_env;
  `uvm_component_utils(mem_env)
  mem_agent agent;mem_scoreboard scoreboard;
  function new(string n,uvm_component p);super.new(n,p);endfunction
  function void build_phase(uvm_phase phase);
   agent=mem_agent::type_id::create("agent",this);
   scoreboard=mem_scoreboard::type_id::create("scoreboard",this);
  endfunction
  function void connect_phase(uvm_phase phase);agent.monitor.ap.connect(scoreboard.imp);endfunction
  function void check_phase(uvm_phase phase);
   for(int b=0;b<4;b++) for(int d=0;d<2;d++)
    if(agent.monitor.bank_direction[b][d]==0)
     `uvm_error("COVERAGE",$sformatf("missing bank %0d direction %0d",b,d))
   if(agent.monitor.row_hits==0 || agent.monitor.conflicts==0 || agent.monitor.refreshes==0 || agent.monitor.resets==0)
    `uvm_error("COVERAGE","row hit, conflict, refresh or reset scenario absent")
  endfunction
  function void report_phase(uvm_phase phase);
   string file_name;
   int fd;
   uvm_report_server server=uvm_report_server::get_server();
   `uvm_info("RESULT",$sformatf("checked=%0d reads=%0d writes=%0d row_hits=%0d conflicts=%0d refreshes=%0d resets=%0d aborted=%0d",scoreboard.checked,scoreboard.reads,scoreboard.writes,agent.monitor.row_hits,agent.monitor.conflicts,agent.monitor.refreshes,agent.monitor.resets,agent.monitor.aborted),UVM_LOW)
   if($value$plusargs("RESULT_JSON=%s",file_name)) begin
    fd=$fopen(file_name,"w");
    if(fd==0) `uvm_fatal("RESULT","cannot open result file")
    $fdisplay(fd,"{\"checked\":%0d,\"expected\":%0d,\"reads\":%0d,\"writes\":%0d,\"row_hits\":%0d,\"conflicts\":%0d,\"refreshes\":%0d,\"resets\":%0d,\"aborted\":%0d,\"bank_direction\":[[%0d,%0d],[%0d,%0d],[%0d,%0d],[%0d,%0d]],\"errors\":%0d,\"fatals\":%0d}",scoreboard.checked,scoreboard.expected,scoreboard.reads,scoreboard.writes,agent.monitor.row_hits,agent.monitor.conflicts,agent.monitor.refreshes,agent.monitor.resets,agent.monitor.aborted,agent.monitor.bank_direction[0][0],agent.monitor.bank_direction[0][1],agent.monitor.bank_direction[1][0],agent.monitor.bank_direction[1][1],agent.monitor.bank_direction[2][0],agent.monitor.bank_direction[2][1],agent.monitor.bank_direction[3][0],agent.monitor.bank_direction[3][1],server.get_severity_count(UVM_ERROR),server.get_severity_count(UVM_FATAL));
    $fclose(fd);
   end
  endfunction
 endclass
 class memory_test extends uvm_test;
  `uvm_component_utils(memory_test)
  mem_env env;
  function new(string n,uvm_component p);super.new(n,p);endfunction
  function void build_phase(uvm_phase phase);env=mem_env::type_id::create("env",this);endfunction
  task run_phase(uvm_phase phase);
   traffic sequence_=traffic::type_id::create("traffic");
   phase.raise_objection(this);sequence_.start(env.agent.sequencer);
   repeat(3) @(negedge env.agent.driver.vif.clk);phase.drop_objection(this);
  endtask
 endclass
 class reset_recovery_test extends memory_test;
  `uvm_component_utils(reset_recovery_test)
  function new(string n,uvm_component p);super.new(n,p);endfunction
  function void build_phase(uvm_phase phase);
   super.build_phase(phase);
   uvm_config_db#(int)::set(this,"env.scoreboard","expected",1259);
  endfunction
  task run_phase(uvm_phase phase);
   reset_traffic sequence_=reset_traffic::type_id::create("traffic");
   phase.raise_objection(this);sequence_.start(env.agent.sequencer);
   repeat(3) @(negedge env.agent.driver.vif.clk);phase.drop_objection(this);
  endtask
  function void check_phase(uvm_phase phase);
   if(env.agent.monitor.resets<2 || env.agent.monitor.aborted!=1)
    `uvm_error("RESET","expected one interrupted transaction and a reset recovery")
  endfunction
 endclass
endpackage
