module vector_store_unit (
  input  logic         clk_i,
  input  logic         rst_ni,

//   input logic  [4:0]  vd_idx_i,    // destination vector register indexhttps://ibex-core.readthedocs.io/en/latest/03_reference/verification.html
  input  logic [31:0]  adder_result_ex_i,
  input logic  [4:0]   vl_i,      // vector length (from rs1) // useful for counting how many cycles do we need crs register
  input logic  [2:0]   request_type_i,      // 8 oder 16 oder sogar 32

  output logic         addr_incr_req_o,

  input  logic         st_req,
  output logic         st_done,
  // output logic         st_fault,
  output logic         store_err_o, // st_fault
  
  // interface to ibex_vrf
//   output  logic            rd_en_o,
//   output  logic [4:0]      rd_vreg_o, handle it externally
  output  logic [1:0]      rd_bank_o,
  input   logic [31:0]     rd_rdata_i,

  // interface to memory
  output logic                     data_req_o,
  output logic [31:0]              data_addr_o,
  output logic                     data_we_o,
  output logic [3:0]               data_be_o,
  output logic [31:0]              data_wdata_o,

  input  logic                     data_gnt_i,
  input  logic                     data_rvalid_i,
  input  logic                     data_err_i,
  // input  logic [31:0]              data_rdata_i we don't need it for store

  output logic         busy_o,
);

  assign lsu_req_done_o = (lsu_req_i | (ls_fsm_cs != IDLE)) & (ls_fsm_ns == IDLE);
  assign busy_o = (ls_fsm_cs != IDLE);
  logic store_err;
  assign store_err = (data_rvalid_i) & (data_err_i);
  assign store_err_o = store_err;

  // Store LSU
  typedef enum logic [1:0] {
    ST_IDLE,
    ST_WAIT_GNT,
    ST_REQ,
    ST_WAIT_VALID,
  } st_state_e;

  logic [31:0]  data_addr_w_aligned;
  assign data_addr_w_aligned = {data_addr[31:2], 2'b00};

  assign rd_bank_o = gnt_cnt_q;

  logic  [1:0] gnt_cnt_d, gnt_cnt_q;      // 0..15 (element index) for SEW=8, wenn SEW=16 dann 0..7 // todo: increase length if vlen>128
  logic last_req;
  always_comb begin
    gnt_cnt_d = gnt_cnt_q;
    if (data_gnt_i) begin
      gnt_cnt_d = gnt_cnt_q + 1;
      if (gnt_cnt_q + 1 == anzahl_req) last_req = 1;
    end
  end

  logic last_valid;
  logic  [1:0] valid_cnt_d, valid_cnt_q;      // 0..15 (element index) for SEW=8, wenn SEW=16 dann 0..7 // todo: increase length if vlen > 128
  always_comb begin
    valid_cnt_d = valid_cnt_q;
    if (data_rvalid_i) begin
      valid_cnt_d = valid_cnt_q + 1;
      if (valid_cnt_q + 1 == anzahl_req) last_valid = 1;
    end
  end

  logic [1:0] EEW_BYTES;
  always_comb begin
    if (request_type_i == 3'b000) EEW_BYTES = 1 // bytes pro element
    else if (request_type_i == 3'b101) EEW_BYTES = 2
    else if (request_type_i == ) EEW_BYTES = 3 // todo: sew 32 
    else EEW_BYTES = 1
  end

  logic [31:0]  data_addr;
  logic [1:0]   data_offset;   // mux control for data to be written to memory

  assign data_addr   = adder_result_ex_i;
  assign data_offset = data_addr[1:0];

  logic [6:0] n;
  always_comb begin
    if (EEW_BYTES == 1) SHIFT_FAKTOR = 0 //sew = 8
    else if EEW_BYTES == 2 SHIFT_FAKTOR = 1 //sew = 16
    else if EEW_BYTES == 4 SHIFT_FAKTOR = 2 //sew = 32
  end

  assign n = data_offset + vl_i << SHIFT_FAKTOR;
  logic [2:0] anzahl_req;
  assign anzahl_req = n[4:2];

  logic [31:0] first_mask, last_mask, data_wdata;

  // prepare data to be written to the memory
  // we handle misaligned accesses, half word and byte accesses here
  always_comb begin
    unique case (data_offset)
      2'b00:   first_mask =  4'b1111;
      2'b01:   first_mask =  4'b1110;
      2'b10:   first_mask =  4'b1100;
      2'b11:   first_mask =  4'b1000;
      default: first_mask =  4'b1111;
    endcase // case (data_offset)
  end

  always_comb begin
    unique case (n[1:0])
      2'b00:   last_mask =  4'b1111;
      2'b01:   last_mask =  4'b0001;
      2'b10:   last_mask =  4'b0011;
      2'b11:   last_mask =  4'b0111;
      default: last_mask =  4'b1111;
    endcase // case (n[1:0])
  end

  // prepare data to be written to the memory
  // we handle misaligned accesses, half word and byte accesses here
  always_comb begin
    unique case (data_offset)
      2'b00:   data_wdata =  rd_rdata_i[31:0];
      2'b01:   data_wdata = {rd_rdata_i[23:0], rd_rdata_i[31:24]};
      2'b10:   data_wdata = {rd_rdata_i[15:0], rd_rdata_i[31:16]};
      2'b11:   data_wdata = {rd_rdata_i[ 7:0], rd_rdata_i[31: 8]};
      default: data_wdata =  rd_rdata_i[31:0];
    endcase // case (data_offset)
  end
  
  always_comb begin
    st_state_d    = st_state_q;

    // defaults: memory
    data_req_o    = 1'b0;
    data_addr_o   = '0;
    data_we_o     = 1'b0;
    data_wdata_o  = '0;
    data_be_o     = 4'b0000;

    addr_incr_req_o     = 1'b0;

    last_req_data_d = last_req_data_q;
    last_mask_d = last_mask_q;

    unique case (st_state_q)
      ST_IDLE: begin
        if (st_req) begin
          // push first request
          data_req_o   = 1'b1;
          data_addr_o   = data_addr_w_aligned;
          data_we_o     = 1'b1;
          if (last_req) begin 
            data_wdata_o  = data_wdata;
            data_be_o     = first_mask & last_mask;
            last_req_data_d = data_wdata;
            last_mask_d = first_mask & last_mask;
          end
          else begin
            data_wdata_o  = data_wdata;
            data_be_o     = first_mask;
            last_req_data_d = data_wdata;
            last_mask_d = first_mask;
          end

          bank_word_d = data_wdata;
          addr_incr_req_o     = 1'b0;
          
          if (data_gnt_i) begin
            if (last_req) st_state_d = IDLE;
            else st_state_d = ST_REQ
          end
          else
            st_state_d = ST_WAIT_GNT;
        end
      end
  
      ST_WAIT_GNT: begin
          // keep the last request
          data_req_o   = 1'b1;
          data_addr_o   = data_addr_w_aligned; // keep last request
          data_we_o     = 1'b1; // want to write
          data_wdata_o  = last_req_data_q;
          data_be_o     = last_mask_q;
          bank_word_d = data_wdata;
          addr_incr_req_o     = 1'b0; // the address data_addr_w_aligned will not be incremented
        if (data_gnt_i) begin
            if (last_req) st_state_d = ST_IDLE;
            else st_state_d = ST_REQ; // the next cycle we will push a new request
        end
      end

      ST_REQ: begin
        // push new request
        data_req_o   = 1'b1;
        data_addr_o  = data_addr_w_aligned;
        data_we_o    = 1'b1;

        if (last_req) begin
        data_wdata_o = last_req_data_q;
        data_be_o    = last_mask;
        end
        else begin
          data_wdata_o = ; // todo
          data_be_o    = 4'b1111;
          last_req_data_d = ; // todo
          last_mask_d = ; //todo
        end

        addr_incr_req_o = 1'b1;
        if (data_gnt_i) begin
            if (last_req) st_state_d = ST_IDLE;
            else st_state_d = ST_REQ; // next time a new request will be pushed
        end
        else st_state_d = ST_WAIT_GNT;
      end
    endcase
  end

  always_ff @(posedge clk_i or negedge rst_ni) begin
    if (!rst_ni) begin
      st_state_q         <= ST_IDLE;
      last_mask_q   <= '0;
      last_req_data_q  <= '0;
    end else begin
      st_state_q <= st_state_d;
      last_mask_q <= last_mask_d;
      last_req_data_q <= last_req_data_d;
    end
  end
endmodule
