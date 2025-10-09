module suv (
  input  logic         clk_i,
  input  logic         rst_ni,

  input logic  [4:0]  vd_idx_i,    // destination vector register index
  input logic  [31:0]  base_i,      // base address (from rs1)
  input logic  [4:0]   vl_i,      // vector length (from rs1)
  input logic  [2:0]   request_type_i,      // 8 oder 16

  input  logic         st_rq,
  output logic         st_done,
  output logic         st_fault,
  
  // interface to ibex_vrf
  output  logic            rd_en_o,
  output  logic [4:0]      rd_vreg_o,
  output  logic [1:0]      rd_bank_o,
  input   logic [31:0]     rd_rdata_i,

  // interface to memory
  output logic                     data_req_o,
  output logic [31:0]              data_addr_o,
  output logic                     data_we_o,
  output logic [3:0]               data_be_o,
  output logic [31:0]              data_wdata_o,

  input  logic                     data_gnt_i,
  // input  logic                     data_rvalid_i, // todo: do we need this signals?
  // input  logic                     data_err_i,
  // input  logic [31:0]              data_rdata_i
);

  // Store LSU
  typedef enum logic [3:0] {
    ST_IDLE,
    ST_VRF_RD,
    ST_REQ1, ST_WAIT1,
    ST_REQ2, ST_WAIT2,
    ST_DONE, ST_FAULT
  } st_state_e;

  logic  [4:0] idx_e_q, idx_e_d;      // 0..15 (element index) for SEW=8, wenn SEW=16 dann 0..7
  logic [5:0] byte_idx;

  logic [31:0] addr, a0_aligned, a1_aligned;
  logic [1:0]  sh;                    // byte offset within 32b word

  // helpers
  logic [2:0] elements_left;       
  logic [2:0] elems_beat;

  localparam int BYTES_PER_BEAT = 4;
  logic [1:0] EEW_BYTES;
  logic [2:0] ELEMS_PER_BEAT; // 4 oder 2

  logic [2:0]  Nbytes;
  logic        need_two;            // second write needed?

  logic [31:0] bank_word_q, bank_word_d;  // 32-bit from VRF bank
  logic [3:0]  w0_strb_l, w1_strb_l;
  logic [31:0] w0_data_l, w1_data_l;
  logic [2:0]  first, second;

  always_comb begin
    if (request_type_i == 3'b000) EEW_BYTES = 1 // bytes pro element
    else if (request_type_i == 3'b101) EEW_BYTES = 2
    else EEW_BYTES = 1
  end
  assign byte_idx = idx_e_q * EEW_BYTES;
  // VRF connections for store
  assign vrf_rd_vreg_o = vd_idx_i;
  assign vrf_rd_bank_o = byte_idx[3:2];

  assign addr       = base_i + byte_idx; // current byte address after incremention // 
  assign a0_aligned = {addr[31:2], 2'b00}; // aligned down

  assign ELEMS_PER_BEAT = BYTES_PER_BEAT / EEW_BYTES;
  assign elements_left       = (vl_i > idx_e_q) ? (vl_i - idx_e_q) : 3'd0;
  assign elems_beat  = (elements_left > ELEMS_PER_BEAT) ? ELEMS_PER_BEAT : elements_left;
  assign Nbytes      = elems_beat * EEW_BYTES;
  assign sh         = addr[1:0];
  assign need_two   = (sh != 2'd0) && ((sh + Nbytes) > 3'd4); // wir brauchen zwei beats wenn die verschiebung and der anzahl der gebleiebenen Bytes größer als 4 ist.

  assign first = need_two ? (3'd4 - {1'b0,sh}) : Nbytes;
  assign second = need_two ? (Nbytes - first) : 3'd0;
  // one-beat packet (or first of two)
  assign w0_data_l = bank_word_q << (8*sh);
  assign w0_strb_l = (first==3'd4) ? 4'b1111 : ((4'b1111 >> (4 - first)) << sh);

  // second-beat packet (if needed)
  assign w1_data_l = bank_word_q >> (8*first);
  assign w1_strb_l = (second==3'd0) ? 4'b0000 : (4'b1111 >> (4 - second));
  
  assign a1_aligned = a0_aligned + 32'd4; // aligned up

  // VRF connections for store
  logic        vrf_rd_en;
  logic  [4:0] vrf_rd_vreg;  
  logic  [1:0] vrf_rd_bank;
  
  assign rd_en_o   = vrf_rd_en;
  assign rd_vreg_o = vrf_rd_vreg;
  assign rd_bank_o = vrf_rd_bank;
  assign vrf_rd_vreg = vd_idx_i;
  assign vrf_rd_bank = byte_idx[3:2];

  always_comb begin
    st_state_d    = st_state_q;

    // status
    st_done       = 1'b0;
    st_fault      = 1'b0;

    vrf_rd_en = 1'b0;

    idx_e_d         = idx_e_q;
    bank_word_d   = bank_word_q;

    // defaults: memory
    data_req_o    = 1'b0;
    data_addr_o   = '0;
    data_we_o     = 1'b0;
    data_wdata_o  = '0;
    data_be_o     = 4'b0000;

    unique case (st_state_q)
      ST_IDLE: begin
        if (st_rq) begin
          if (vl_i == 0) st_state_d = ST_DONE;
          else st_state_d = ST_VRF_RD;
          idx_e_d = '0; // wichtig
        end
      end
  
      ST_VRF_RD: begin
        vrf_rd_en = 1'b1;
        bank_word_d = rd_rdata_i;
        st_state_d = ST_REQ1;
      end

      // first memory write
      ST_REQ1: begin
        data_req_o   = 1'b1;
        data_addr_o  = a0_aligned;
        data_we_o    = 1'b1;
        data_wdata_o = w0_data_l;
        data_be_o    = w0_strb_l;
        if (data_gnt_i) st_state_d = ST_WAIT1;
      end

      ST_WAIT1: begin
        // Simplified: assume stores don't need response
        st_state_d = need_two ? ST_REQ2 : ST_DONE;
      end

      // optional second write
      ST_REQ2: begin
        data_req_o   = 1'b1;
        data_addr_o  = a1_aligned;
        data_we_o    = 1'b1;
        data_wdata_o = w1_data_l;
        data_be_o    = w1_strb_l;
        if (data_gnt_i) st_state_d = ST_WAIT2;
      end

      ST_WAIT2: begin
        // Simplified: assume stores don't need response todo: do stores need data_rvalid_i response??
        idx_e_d = idx_e_q + elems_beat;
        st_state_d = (idx_e_d >= vl_i) ? ST_DONE : ST_VRF_RD;
      end

      ST_DONE: begin
        st_done = 1'b1;  // signal control FSM
        st_state_d    = ST_IDLE;
      end

      ST_FAULT: begin
        st_fault = 1'b1;
        st_done  = 1'b1;
        st_state_d     = ST_IDLE;
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
