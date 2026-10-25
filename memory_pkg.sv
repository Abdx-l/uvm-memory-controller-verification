package memory_pkg;
 import uvm_pkg::*;
 `include "uvm_macros.svh"
 class mem_item extends uvm_sequence_item;
  rand bit write;
  rand bit [1:0] bank;
  rand bit [3:0] row,col;
  rand bit [31:0] data;
  bit [31:0] result;
  `uvm_object_utils_begin(mem_item)
   `uvm_field_int(write,UVM_ALL_ON)
   `uvm_field_int(bank,UVM_ALL_ON)
   `uvm_field_int(row,UVM_ALL_ON)
   `uvm_field_int(col,UVM_ALL_ON)
   `uvm_field_int(data,UVM_ALL_ON)
   `uvm_field_int(result,UVM_ALL_ON)
  `uvm_object_utils_end
  function new(string name="mem_item");super.new(name);endfunction
 endclass
 class traffic extends uvm_sequence #(mem_item);
  `uvm_object_utils(traffic)
  function new(string name="traffic");super.new(name);endfunction
  task body();
   mem_item t;
   // Initialize every location before random read/write traffic.
   for(int b=0;b<4;b++) for(int r=0;r<4;r++) for(int c=0;c<4;c++) begin
    t=mem_item::type_id::create("init"); start_item(t);
    t.write=1;t.bank=b;t.row=r;t.col=c;t.data=(b<<8)|(r<<4)|c;finish_item(t);
   end
   repeat(1000) begin
    t=mem_item::type_id::create("random");start_item(t);
    if(!t.randomize() with {row<4;col<4;}) `uvm_fatal("RAND","randomization failed")
    finish_item(t);
   end
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
    @(negedge vif.clk);while(!vif.ready) @(negedge vif.clk);
    vif.valid=1;vif.write=t.write;vif.bank=t.bank;vif.row=t.row;vif.col=t.col;vif.wdata=t.data;
    @(negedge vif.clk);vif.valid=0;
    while(!vif.rvalid) @(negedge vif.clk);
    seq_item_port.item_done();
   end
  endtask
 endclass
 class mem_monitor extends uvm_monitor;
  `uvm_component_utils(mem_monitor)
  virtual mem_if vif;
  uvm_analysis_port#(mem_item) ap;
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
   forever begin
    @(posedge vif.clk);
    if(vif.rst) begin pending=null;accesses.sample();end
    else begin
     if(vif.valid && vif.ready) begin
      pending=mem_item::type_id::create("observed");
      pending.write=vif.write;pending.bank=vif.bank;pending.row=vif.row;pending.col=vif.col;pending.data=vif.wdata;
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
  int checked=0;
  function new(string n,uvm_component p);super.new(n,p);imp=new("imp",this);endfunction
  function void write(mem_item t);
   int address=(int'(t.bank)<<8)|(int'(t.row)<<4)|int'(t.col);
   if(t.write) reference[address]=t.data;
   else if(!reference.exists(address) || reference[address]!==t.result)
    `uvm_error("DATA",$sformatf("address %0h expected %0h got %0h",address,reference[address],t.result))
   checked++;
  endfunction
  function void check_phase(uvm_phase phase);
   if(checked!=1256) `uvm_error("COUNT",$sformatf("checked %0d expected 1256",checked))
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
endpackage
