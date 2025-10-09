module luv (
  input  logic         clk_i,
  input  logic         rst_ni,

  input logic  [4:0]  vd_idx_i,    // destination vector register index
  input logic  [31:0]  base_i,      // base address (from rs1)
  input logic  [4:0]   vl_i,      // vector length (from rs1)
  input logic  [2:0]   request_type_i,      // 8 oder 16

  input  logic         lu_rq,  // pulse to start LSU operation
  output logic         ld_done,   // pulse when operation done
  output logic         ld_fault,  // pulse if any fault during operation
  
  // interface to ibex_vrf
  output logic         vrf_wr_en_o,
  output logic  [4:0]  vrf_wr_vreg_o,
  output logic  [1:0]  vrf_wr_bank_o,
  output logic [31:0]  vrf_wr_wdata_o,
  output logic  [3:0]  vrf_wr_wstrb_o,

  // interface to memory
  output logic                     data_req_o,
  output logic [31:0]              data_addr_o,
  output logic                     data_we_o,
  output logic [3:0]               data_be_o,
  output logic [31:0]              data_wdata_o,

  input  logic                     data_gnt_i,
  input  logic                     data_rvalid_i,
  input  logic                     data_err_i,
  input  logic [31:0]              data_rdata_i
);

// NOTE: for simplicity, we always set idx_mode to 0 (start at byte 0 of bank word), because vstart is always 0 in this cut.

  // ---- LSU / VRF state ----
  typedef enum logic [3:0] {
    LSU_IDLE,
    LSU_REQ1, LSU_WAIT1,
    LSU_REQ2, LSU_WAIT2,
    LSU_WRITE,
    LSU_DONE, LSU_FAULT
  } lsu_state_e;
  lsu_state_e ld_state_q, ld_state_d;

  logic  [4:0] idx_e_q, idx_e_d;      // 0..15 (element index) for SEW=8, wenn SEW=16 dann 0..7
  logic [5:0] byte_idx;
  logic [31:0] word_q,  word_d;       // final 32b window for this beat

  logic [31:0] addr, a0_aligned, a1_aligned;
  logic [1:0]  sh;                    // byte offset within 32b word

  // helpers
  logic [4:0] elements_left; // todo: why ist 5 bits      
  logic [2:0] elems_beat; // todo: why ist 3 bits 
  logic [3:0] mask;

  localparam int BYTES_PER_BEAT = 4;
  logic [1:0] EEW_BYTES;

  logic [2:0]  Nbytes;
  logic        need_two;            // second write needed?

  always_comb begin
    if (request_type_i == 3'd0) EEW_BYTES = 2'd1; // bytes pro element
    else if (request_type_i == 3'd5) EEW_BYTES = 2'd2;
    else EEW_BYTES = 2'd1; // default
  end
  assign byte_idx = idx_e_q * EEW_BYTES;
  assign addr       = base_i + byte_idx; // current byte address after incremention // 
  assign a0_aligned = {addr[31:2], 2'b00}; // aligned down

  assign ELEMS_PER_BEAT = BYTES_PER_BEAT / EEW_BYTES;
  assign elements_left = (vl_i > idx_e_q) ? (vl_i - idx_e_q) : 5'd0;
  assign elems_beat  = (elements_left > ELEMS_PER_BEAT) ? ELEMS_PER_BEAT : elements_left[2:0];
  assign Nbytes      = elems_beat * EEW_BYTES;
  assign sh         = addr[1:0];
  assign need_two   = (sh != 2'd0) && ((sh + Nbytes) > 3'd4); // wir brauchen zwei beats wenn die verschiebung and der anzahl der gebleiebenen Bytes größer als 4 ist.

  assign a1_aligned = a0_aligned + 32'd4; // aligned up

  // mask for tail (idx_mod is always 0 here) // todo: check if this is still correct for SEW=16
  
  always_comb begin 
    if (EEW_BYTES == 1) begin // sew=8
      mask =
        (elems_beat == 3'd4) ? 4'b1111 :
        (elems_beat == 3'd3) ? 4'b0111 :
        (elems_beat == 3'd2) ? 4'b0011 :
        (elems_beat == 3'd1) ? 4'b0001 : 4'b0000;
    end
    else if (EEW_BYTES == 2) begin // sew=16
      mask =
        (elems_beat == 3'd2) ? 4'b1111 :
        (elems_beat == 3'd1) ? 4'b1100 : 4'b0000;
    end
    // todo: we can implement vle32??
  end

  always_comb begin
    // defaults
    ld_state_d = ld_state_q; // state
    idx_e_d = idx_e_q;
    word_d  = word_q;

    ld_done     = 1'b0;
    ld_fault    = 1'b0;

    vrf_wr_en    = 1'b0;
    vrf_wr_wdata = data_rdata_i;
    vrf_wr_wstrb = 4'b0000;
    vrf_wr_vreg  = vd_idx_i;
    vrf_wr_bank  = byte_idx[3:2];

    data_req_o = 1'b0;
    data_addr_o  = '0;
    data_we_o = 1'b0;
    data_wdata_o = '0;
    data_be_o = 4'b0000;

    unique case (ld_state_q)
      LSU_IDLE:  if (lu_rq) begin
        if (vl_i == 0) ld_state_d = LSU_DONE;
        else ld_state_d = LSU_REQ1;
        idx_e_d = '0; // wichtig
        word_d  = '0;
      end

      // ----- First aligned read (always) -----
      LSU_REQ1: begin
        data_req_o  = 1'b1;
        data_addr_o = a0_aligned;   // aligned down
        data_we_o   = 1'b0;
        if (data_gnt_i) ld_state_d = LSU_WAIT1;
      end

      LSU_WAIT1: begin
        if (data_rvalid_i) begin
          if (data_err_i) ld_state_d = LSU_FAULT;
          else begin
            word_d = data_rdata_i >> (8*sh);
            ld_state_d = need_two ? LSU_REQ2 : LSU_WRITE;
          end
        end
      end

      LSU_REQ2: begin
        data_req_o  = 1'b1;
        data_addr_o = a1_aligned;
        data_we_o   = 1'b0;
        if (data_gnt_i) ld_state_d = LSU_WAIT2;
      end

      LSU_WAIT2: begin
        if (data_rvalid_i) begin
          if (data_err_i) ld_state_d = LSU_FAULT;
          else begin
            word_d = (data_rdata_i << (8*(4-sh))) | word_q;
            ld_state_d = LSU_WRITE;
          end
        end
      end

      LSU_WRITE: begin
        // current VRF bank = idx_e_q[3:2]; idx_mod==0 -> no shift needed
        vrf_wr_en    = (elems_beat != 0);
        vrf_wr_vreg  = vd_idx_i;
        vrf_wr_bank  = byte_idx[3:2];
        vrf_wr_wdata = word_q;     // already the right 4-byte window, aligned to byte 0
        vrf_wr_wstrb = mask;       // only low N bytes if tail

        // advance or finish
        idx_e_d = idx_e_q + elems_beat;  // (3-bit -> zero-extends fine)
        ld_state_d = (idx_e_d >= vl_i) ? LSU_DONE : LSU_REQ1;
      end

      LSU_FAULT: begin
        ld_fault = 1'b1;
        ld_done = 1'b1;
        ld_state_d     = LSU_IDLE;
      end

      LSU_DONE: begin
        ld_done = 1'b1;
        ld_state_d    = LSU_IDLE;
      end
    endcase
  end

  // State/data registers
  always_ff @(posedge clk_i or negedge rst_ni) begin
    if (!rst_ni) begin
      ld_state_q   <= LSU_IDLE;
      idx_e_q   <= '0;
      word_q  <= '0;
    end else begin
      ld_state_q   <= ld_state_d;
      idx_e_q   <= idx_e_d;
      word_q  <= word_d;
    end
  end
endmodule
