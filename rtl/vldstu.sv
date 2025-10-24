// Vector Load/Store Unit Wrapper
// Provides unified interface for vector memory operations
// Currently implements: Store operations
// TODO: Add Load operations in Phase 2

module vldstu #(
  parameter int unsigned VLEN = 128
) (
  input  logic         clk_i,
  input  logic         rst_ni,

  // Vector operation request interface  
  input  logic         v_req_i,           // Vector memory operation request (wird im Zukunft unterteilt and will drive st_req or ld_req) will be multiplexed by using v_we_i.
  input  logic         v_we_i,            // 1=store, 0=load (for future), for now it is set to 1, because we only have a store Unit.
  input  logic [31:0]  v_addr_i,          // Base address. This is the adder_result_ex_i signal just renamed. 
  input  logic [4:0]   v_vl_i,            // Vector length vl_i
  input  logic [2:0]   v_sew_i,           // Element width (000=8bit, 101=16bit, 010=32bit) // This is request_type_i
  // output logic         v_ready_o,      // Ready to accept new request, todo: check we don't need this signal
  output logic         v_done_o,          // Operation completed // This is st_done or ld_done
  output logic         v_err_o,           // Error occurred // This is store_err_o or load_err_o

  // Vector register file interface (for stores)
  input  logic [VLEN-1:0] vrf_rdata_i,   // Vector register data to store // This is rd_rdata_i
  
  // Vector register file interface (for loads - future)
  output logic            vrf_we_o,       // Write enable to VRF // TODO: for now not use, but this is wr_en_o.
  output logic [VLEN-1:0] vrf_wdata_o,    // Write data to VRF // TODO: for now not use, but this is wr_wdata_o.

  // Memory interface
  output logic         data_req_o,
  output logic [31:0]  data_addr_o,
  output logic         data_we_o,
  output logic [3:0]   data_be_o,
  output logic [31:0]  data_wdata_o,
  input  logic         data_gnt_i,
  input  logic         data_rvalid_i,
  input  logic         data_err_i,
  input  logic [31:0]  data_rdata_i, // TODO: this is also not used yet, for loads

  // Address increment request (to ID/EX stage)
  output logic         addr_incr_req_o,
  output logic [31:0]  addr_last_o,

  output logic resp_valid_o, // This is a very important Signal, without it we can't stall the core. It can be st_resp_valid or ld_resp_valid

  // Status signals
  output logic         busy_o
);

  // Internal control signals
  logic st_req, ld_req;
  logic st_done, ld_done;
  logic st_err, ld_err;
  logic st_busy, ld_busy;

  // Store Unit signals
  logic        st_resp_valid;
  logic [31:0] st_addr_last;
  logic        st_data_req;
  logic [31:0] st_data_addr;
  logic        st_data_we;
  logic [3:0]  st_data_be;
  logic [31:0] st_data_wdata;
  logic        st_addr_incr_req;

  // Load Unit signals
  logic        ld_resp_valid;
  logic [31:0] ld_addr_last;
  logic        ld_data_req;
  logic [31:0] ld_data_addr;
  logic        ld_addr_incr_req;

  // Request routing based on operation type
  assign st_req = v_req_i & v_we_i;   // Store request
  assign ld_req = v_req_i & ~v_we_i;  // Load request (now enabled in Phase 2)

  // Response aggregation - use OR gates since only one unit is active at a time
  assign v_done_o  = st_done | ld_done;         // Done when either completes
  assign v_err_o   = st_err | ld_err;           // Error from either unit
  assign busy_o    = st_busy | ld_busy;         // Busy when either is active

  // Address last multiplexing - priority to the active unit
  assign addr_last_o = st_busy ? st_addr_last : ld_addr_last; // TODO: please check this, since can lead to a undefined behaviour

  // Memory interface multiplexing - controlled by which unit is active
  logic        mem_data_req;
  logic [31:0] mem_data_addr;
  logic        mem_data_we;
  logic [3:0]  mem_data_be;
  logic [31:0] mem_data_wdata;

  // Only one unit can be active at a time, so simple OR gates work
  assign mem_data_req   = st_data_req | ld_data_req;
  assign mem_data_addr  = st_busy ? st_data_addr : ld_data_addr; // TODO: please check this, since can lead to a undefined behaviour
  assign mem_data_we    = st_data_we;  // Load unit never writes
  assign mem_data_be    = st_data_be;  // Load unit doesn't use byte enables
  assign mem_data_wdata = st_data_wdata;

  // Connect multiplexed signals to output
  assign data_req_o   = mem_data_req;
  assign data_addr_o  = mem_data_addr;
  assign data_we_o    = mem_data_we;
  assign data_be_o    = mem_data_be;
  assign data_wdata_o = mem_data_wdata;

  // Address increment request - OR both units
  assign addr_incr_req_o = st_addr_incr_req | ld_addr_incr_req;

  assign resp_valid_o = st_resp_valid | ld_resp_valid;

  //=============================================================================
  // Vector Store Unit Instance
  //=============================================================================
  
  vector_store_unit u_vector_store (
    .clk_i              (clk_i),
    .rst_ni             (rst_ni),
    
    // Control interface
    .adder_result_ex_i  (v_addr_i),
    .vl_i               (v_vl_i),
    .request_type_i     (v_sew_i),
    .st_req             (st_req),
    .st_done            (st_done),
    .store_err_o        (st_err),
    .busy_o             (st_busy),
    
    // Address management
    .addr_incr_req_o    (st_addr_incr_req),
    .addr_last_o        (st_addr_last),
    .st_resp_valid_o    (st_resp_valid),
    
    // Vector register interface  
    .rd_rdata_i         (vrf_rdata_i),
    
    // Memory interface
    .data_req_o         (st_data_req),
    .data_addr_o        (st_data_addr),
    .data_we_o          (st_data_we),
    .data_be_o          (st_data_be),
    .data_wdata_o       (st_data_wdata),
    .data_gnt_i         (data_gnt_i),
    .data_rvalid_i      (data_rvalid_i),
    .data_err_i         (data_err_i)
  );

  //=============================================================================
  // Vector Load Unit Instance (Phase 2 - Now Enabled)
  //=============================================================================
  
  vector_load_unit u_vector_load (
    .clk_i              (clk_i),
    .rst_ni             (rst_ni),
    
    // Control interface  
    .adder_result_ex_i  (v_addr_i),
    .vl_i               (v_vl_i),
    .request_type_i     (v_sew_i),
    .ld_req             (ld_req),
    .ld_done            (ld_done),
    .load_err_o         (ld_err),
    .busy_o             (ld_busy),
    
    // Address management
    .addr_incr_req_o    (ld_addr_incr_req),
    .addr_last_o        (ld_addr_last),
    .ld_resp_valid_o    (ld_resp_valid),
    
    // Vector register interface
    .wr_en_o            (vrf_we_o),
    .wr_wdata_o         (vrf_wdata_o),
    
    // Memory interface
    .data_req_o         (ld_data_req),
    .data_addr_o        (ld_data_addr),
    .data_we_o          (),  // Not used for loads (always 0)
    .data_be_o          (),  // Not used for loads
    .data_wdata_o       (),  // Not used for loads
    .data_gnt_i         (data_gnt_i),
    .data_rvalid_i      (data_rvalid_i),
    .data_err_i         (data_err_i),
    .data_rdata_i       (data_rdata_i)
  );

  // Assertions for debugging
  `ifdef SIMULATION
    // Ensure only one unit is active at a time
    assert property (@(posedge clk_i) disable iff (!rst_ni) 
                     !(st_busy && ld_busy)) 
      else $error("Both store and load units busy simultaneously");
    
    // Check request/response protocol
    assert property (@(posedge clk_i) disable iff (!rst_ni)
                     v_req_i |=> ##[1:$] v_done_o)
      else $warning("Vector request never completed");
      
    // Verify exclusive operation (only one unit should be requested at a time)
    assert property (@(posedge clk_i) disable iff (!rst_ni)
                     v_req_i |-> (v_we_i ^ ~v_we_i))
      else $error("Invalid vector operation: both store and load requested");
  `endif

endmodule
