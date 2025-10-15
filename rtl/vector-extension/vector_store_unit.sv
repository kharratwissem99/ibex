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
  // logic  [4:0] idx_e_q, idx_e_d;      // 0..15 (element index) for SEW=8, wenn SEW=16 dann 0..7
  // logic [5:0] byte_idx;
  logic [1:0] EEW_BYTES;
  always_comb begin
    if (request_type_i == 3'b000) EEW_BYTES = 1 // bytes pro element
    else if (request_type_i == 3'b101) EEW_BYTES = 2
    else EEW_BYTES = 1
  end

  // helpers
  // logic [2:0] elements_left;       
  // logic [2:0] elems_beat;

  // localparam int BYTES_PER_BEAT = 4;
  // logic [2:0] ELEMS_PER_BEAT; // 4 oder 2

  // assign ELEMS_PER_BEAT = BYTES_PER_BEAT / EEW_BYTES;
  // assign elements_left       = (vl_i > idx_e_q) ? (vl_i - idx_e_q) : 3'd0;
  // assign elems_beat  = (elements_left > ELEMS_PER_BEAT) ? ELEMS_PER_BEAT : elements_left;
  // logic inc_rq_cnt;
  logic  [1:0] cnt_d, cnt_q;      // 0..15 (element index) for SEW=8, wenn SEW=16 dann 0..7 // todo: increase length if vlen>128
  logic last;
  always_comb begin
    cnt_d = cnt_q;
    if (data_gnt_i) begin
      cnt_d = cnt_q + 1;
      if (cnt_q + 1 == anzahl_req) last = 1;
    end
  end

  logic last_valid;
  logic  [1:0] valid_cnt_d, valid_cnt_q;      // 0..15 (element index) for SEW=8, wenn SEW=16 dann 0..7 // todo: increase length if vlen>128
  always_comb begin
    valid_cnt_d = valid_cnt_q;
    if (data_rvalid_i) begin
      valid_cnt_d = valid_cnt_q + 1;
      if (valid_cnt_q + 1 == anzahl_req) last_valid = 1;
    end
  end

  logic [6:0] n;
  assign n = data_offset + vl_i * EEW_BYTES;
  logic [2:0] anzahl_req;
  assign anzahl_req = n[4:2];

  // assign byte_idx = idx_e_q * EEW_BYTES;

  logic [31:0]  data_addr;
  logic [1:0]   data_offset;   // mux control for data to be written to memory

  assign data_addr   = adder_result_ex_i;
  assign data_offset = data_addr[1:0];

  // assign data_addr_w_aligned = {data_addr[31:2], 2'b00};

  // logic [31:0] addr, a0_aligned, a1_aligned;
  // logic [1:0]  sh;                    // byte offset within 32b word // replaced with data offset signal

  // // helpers
  // logic [2:0] elements_left;       
  // logic [2:0] elems_beat;

  // localparam int BYTES_PER_BEAT = 4;
  // logic [2:0] ELEMS_PER_BEAT; // 4 oder 2

  logic [2:0]  Nbytes;
  logic        need_two;            // second write needed?

  logic [31:0] bank_word_q, bank_word_d;  // 32-bit from VRF bank
  logic [3:0]  w0_strb_l, w1_strb_l;
  logic [31:0] w0_data_l, w1_data_l;
  logic [2:0]  first, second;

  // VRF connections for store
  // assign vrf_rd_vreg_o = vd_idx_i;
  // assign vrf_rd_bank_o = byte_idx[3:2];
  assign rd_bank_o = cnt_q;

  // assign addr       = base_i + byte_idx; // current byte address after incremention // 
  // assign a0_aligned = {addr[31:2], 2'b00}; // aligned down
  // assign data_addr_w_aligned = {data_addr[31:2], 2'b00};

  // assign ELEMS_PER_BEAT = BYTES_PER_BEAT / EEW_BYTES;
  // assign elements_left       = (vl_i > idx_e_q) ? (vl_i - idx_e_q) : 3'd0;
  // assign elems_beat  = (elements_left > ELEMS_PER_BEAT) ? ELEMS_PER_BEAT : elements_left;
  assign Nbytes      = elems_beat * EEW_BYTES;
  // assign sh         = addr[1:0];
  assign need_two   = (sh != 2'd0) && ((sh + Nbytes) > 3'd4); // wir brauchen zwei beats wenn die verschiebung and der anzahl der gebleiebenen Bytes größer als 4 ist.

  assign first = need_two ? (3'd4 - {1'b0,sh}) : Nbytes;
  assign second = need_two ? (Nbytes - first) : 3'd0;
  // one-beat packet (or first of two)
//   assign w0_data_l = bank_word_q << (8*sh);
//   assign w0_strb_l = (first==3'd4) ? 4'b1111 : ((4'b1111 >> (4 - first)) << sh);

  assign w0_data_l = rd_rdata_i << (8*sh);
  assign w0_mask_l = 4'b1111 << (8*sh);
//   assign w0_strb_l = (first==3'd4) ? 4'b1111 : ((4'b1111 >> (4 - first)) << sh);
  

  // second-beat packet (if needed)
  assign w1_data_l = bank_word_q >> (8*first);
  assign w1_strb_l = (second==3'd0) ? 4'b0000 : (4'b1111 >> (4 - second));
  
  // assign a1_aligned = a0_aligned + 32'd4; // aligned up

  // VRF connections for store
//   logic        vrf_rd_en;
  // logic  [4:0] vrf_rd_vreg;  
  // logic  [1:0] vrf_rd_bank;
  
  logic [31:0] mask, data;
  assign mask = rd_rdata_i
  
//   assign rd_en_o   = vrf_rd_en; // remove
  // assign rd_vreg_o = vrf_rd_vreg;
  // assign rd_bank_o = vrf_rd_bank;
  // assign vrf_rd_vreg = vd_idx_i; // todo: can be send directly
  // assign vrf_rd_bank = byte_idx[3:2];

  always_comb begin
    st_state_d    = st_state_q;
    addr_incr_req_o     = 1'b0;
    idx_e_d         = idx_e_q;
    bank_word_d   = bank_word_q;

    // defaults: memory
    data_req_o    = 1'b0;
    data_addr_o   = '0;
    data_we_o     = 1'b0;
    data_wdata_o  = '0;
    data_be_o     = 4'b0000;

    lsu_err_d           = lsu_err_q; // new signal

    unique case (st_state_q)
      ST_IDLE: begin
        if (st_req) begin
          // push new request
          data_req_o   = 1'b1;
          lsu_err_d    = 1'b0; // new signal
          data_addr_o   = data_addr_w_aligned;
          data_we_o     = 1'b1;
          bank_word_d = rd_rdata_i;
          data_wdata_o  = (bank_word_q >> 8*(4-sh)) || (rd_rdata_i << (8*sh));
          data_be_o     = w0_mask_l;
          
        //   vrf_rd_en = 1'b1; //do we need this signal
        //   if (vl_i == 0) st_state_d = ST_DONE;
        //   else st_state_d = ST_VRF_RD;
          if (data_gnt_i) begin
            st_state_d = ST_WAIT_GNT;
          end
          else
            st_state_d = ST_REQ;
          idx_e_d = '0; // wichtig or reset counter. we can make a combinatorische block folr signal and increment it directly
        end
      end
  
      ST_WAIT_GNT: begin
          // keep the same signals
          data_req_o   = 1'b1;
          lsu_err_d    = 1'b0; // new signal
          data_addr_o   = a0_aligned;
          data_we_o     = 1'b1;
          data_wdata_o  = w0_data_l;
          data_be_o     = w0_mask_l;
        // vrf_rd_en    = 1'b1;
        if (data_gnt_i) begin
            idx_e_d = idx_e_q + elems_beat; //could be external increment
            st_state_d = (idx_e_d >= vl_i) ?     : ST_REQ; // fertig?
        end
      end

      // first memory write
      ST_REQ1: begin
        // push new request
        addr_incr_req_o     = 1'b1;
        data_req_o   = 1'b1;
        data_addr_o  = a0_aligned; // the incremented address internally or externally
        data_we_o    = 1'b1;
        data_wdata_o = w0_data_l;
        data_be_o    = w0_strb_l;
        if (data_gnt_i) begin
            if (last_req) st_state_d = ST_WAIT_VALID;
            else st_state_d = ST_REQ1;
        end
        else st_state_d = ST_WAIT_GNT;
      end

      ST_WAIT_VALID: begin
        data_req_o   = 1'b0;
        if (data_rvalid_i) st_state_d = IDLE;
      end

      
    endcase
  end

  always_ff @(posedge clk_i or negedge rst_ni) begin
    if (!rst_ni) begin
      st_state_q         <= ST_IDLE;
      idx_e_q   <= '0;
      bank_word_q  <= '0;
    end else begin
      st_state_q <= st_state_d;
      idx_e_q <= idx_e_d;
      bank_word_q <= bank_word_d;
    end
  end
endmodule
