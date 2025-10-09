// ibex_vector_unit.sv
// `include "ibex_pkg.sv"
`timescale 1ns/1ps

module ibex_vector_unit #(
  parameter int VLEN_BITS = 128
)(
  input  logic                     clk_i,
  input  logic                     rst_ni,

  input  logic                     v_req_valid_i,
  input  ibex_pkg::v_req_t         v_req_i,

  output logic                     v_req_ready_o,
  output ibex_pkg::v_resp_t        v_resp_o,

  // 32-bit memory interface
  output logic                     data_req_o,
  output logic [31:0]              data_addr_o,
  output logic                     data_we_o,
  output logic [3:0]               data_be_o,
  output logic [31:0]              data_wdata_o,

  input  logic                     data_gnt_i,
  input  logic                     data_rvalid_i,
  input  logic                     data_err_i,
  input  logic [31:0]              data_rdata_i,

  // Register File interface
  //Read port R1
  output  logic [4:0]           raddr_a_o,
  input logic [DataWidth-1:0]   rdata_a_i,

  //Read port R2
  output  logic [4:0]           raddr_b_o,
  input logic [DataWidth-1:0]   rdata_b_i,

  // Write port W1
  output  logic [4:0]           waddr_a_o,
  output  logic [DataWidth-1:0] wdata_a_o,
  output  logic                 we_a_o,
  input   logic                 err_i
);

  // internal signals and state registers
  // latched request info
  // todo: warum soll ich diese Signale latchen? Kann ich die nicht direkt verwenden? NEIN, weil die wieder gelesen werden können
  logic [31:0]  req_insn_q, req_insn_d;
  logic [31:0]  req_rs1_q, req_rs1_d;
  logic  [4:0]  req_rd_q, req_rd_d;

  logic         is_vsetvli_q, is_vsetvli_d;
  logic         is_vle_q, is_vle_d;
  logic         is_vse_q, is_vse_d;

  logic [31:0]  rs_data_q, rs_data_d;

  // ---- Control FSM ----
  typedef enum logic [2:0] {IDLE, DECODE, EXECUTE, WRITEBK, DONE, TRAP} vstate_e;
  vstate_e state_q, state_d;

  // ---- LSU / VRF state ----
  typedef enum logic [3:0] {
    LSU_IDLE, LSU_SETUP,
    LSU_REQ1, LSU_WAIT1,
    LSU_REQ2, LSU_WAIT2,
    LSU_ALIGN,
    LSU_WRITE,
    LSU_DONE, LSU_FAULT
  } lsu_state_e;
  lsu_state_e lsu_q, lsu_d;

  // simple CSR regs, todo: do we need vtype?, vstart?, do we need state and next state for them?
  logic [4:0] vl_q, vl_d;      // up to 16 (for SEW=8) or 8 (for SEW=16). In specification vl is a 32 bit register. 
  logic [1:0] sew_q, sew_d;     // 0=8b, 1=16b // todo: should these be normally extracted from vtype CSR?

  // hilfvariablen verwendet in Execute stage
  logic [31:0] avl;
  logic [4:0] max_elems;

  // internal signals used for communication between the main control FSM and Load FSM
  logic ld_rq, ld_done, ld_fault;
  // internal signals used for communication between the main control FSM and Store FSM
  logic st_rq, st_done, st_fault;

  // todo: should we combine all sequential processes into one always_ff block? until now 3 were used.
  always_ff @(posedge clk_i or negedge rst_ni) begin
    if (!rst_ni) begin
      state_q <= IDLE;
      req_insn_q    <= '0;
      req_rs1_q     <= '0;
      req_rd_q      <= '0;
      is_vsetvli_q  <= 1'b0;
      is_vle_q     <= 1'b0;
      is_vse_q     <= 1'b0;
      rs_data_q     <= '0;
      // reset CSR regs
      vl_q          <= '0;
      sew_q         <= '0;
    end
    else  begin       
      state_q <= state_d;
      req_insn_q    <= req_insn_d;
      req_rs1_q     <= req_rs1_d;
      req_rd_q      <= req_rd_d;
      is_vsetvli_q  <= is_vsetvli_d;
      is_vle_q     <= is_vle_d;
      is_vse_q     <= is_vse_d;
      rs_data_q     <= rs_data_d; 
      // update CSR regs
      vl_q         <= vl_d;
      sew_q        <= sew_d;
    end
  end

  // next-state logic
  always_comb begin
    state_d     = state_q;

    v_resp_o    = '{default:0}; // clear response by default
    v_req_ready_o = 1'b0;

    // output to the register file
    raddr_a_o = req_rs1_q;
    raddr_b_o = req_rs1_q;

    waddr_a_o = 32'b0;
    wdata_a_o = 0;
    we_a_o = 1'b0;

    req_insn_d   = req_insn_q;
    req_rs1_d    = req_rs1_q;
    req_rd_d     = req_rd_q;

    is_vsetvli_d = is_vsetvli_q;
    is_vle_d = is_vle_q;
    is_vse_d = is_vse_q;

    rs_data_d = rs_data_q

    // Defaults for next-state regs and LSU start pulse
    vl_d        = vl_q;
    sew_d       = sew_q;
    
    ld_rq   = 1'b0;
    st_rq   = 1'b0;

    case (state_q)
      IDLE: begin
        v_req_ready_o = 1'b1; // ready to take new request
        if (v_req_valid_i) begin
          state_d = EXECUTE;
          req_insn_d   = v_req_i.insn;
          req_rs1_d    = v_req_i.rs1_val;
          req_rd_d     = v_req_i.rd_idx;

          // Do we need to save this signals? we can read them directly from req_*_q signals
          is_vsetvli_d = (v_req_i.insn[6:0]  == 7'h57);
          is_vle_d    = (v_req_i.insn[6:0]  == 7'h07);
          is_vse_d    = (v_req_i.insn[6:0]  == 7'h27);
          if (!(is_vsetvli_d || is_vle_d || is_vse_d)) begin
            // unsupported instruction -> trap
            state_d = TRAP;
          // end
        end else begin
          // no new request: clear decode flags
          is_vsetvli_d = 1'b0;
          is_vle_d    = 1'b0;
          is_vse_d    = 1'b0;
        end
      end

      DECODE: begin
        v_req_ready_o = 1'b0;
        // read from register file: laut ibex documentation 
        // "https://ibex-core.readthedocs.io/en/latest/03_reference/register_file.html":
        // register file data is available the same cycle a read is requested.
        raddr_a_o = req_rs1_q;
        rs_data_d = rdata_a_i;
        state_d = EXECUTE;
      end

      EXECUTE: begin
        if (is_vsetvli_q) begin
          v_req_ready_o = 1'b0;
          avl    = rs_data_q; // Hilfvariable
          sew_d = req_insn_q[25:23]; // todo: In which position in vtypei we find sew_d? 23 to 25?
          // compute max elements per vreg
          max_elems = (sew_d==0) ? 16 : 8; // hilfvariable

          vl_d = (avl < max_elems) ? avl[4:0] : max_elems;

          state_d = WRITEBK;
        end
        else if (is_vle_q) begin
          // ---- kick LSU micro-FSM ----
          ld_rq = (lsu_q == LSU_IDLE);  // single-cycle pulse when LSU idle
          if (ld_done) begin
            if (ld_fault) state_d = TRAP;
            else state_d = DONE;
          end
        end
        else if (is_vse_q) begin
          st_rq = (st_q == ST_IDLE);       // one-cycle pulse to start
          if (st_done) begin
            if (st_fault) state_d = TRAP;
            else state_d = DONE;
          end
        end
      end

      WRITEBK: begin
        v_req_ready_o     = 1'b0;
        v_resp_o.done     = 1'b0;
        v_resp_o.trap     = 1'b0;
        if (is_vsetvli_q) begin
          waddr_a_o = req_rd_d;
          wdata_a_o = vl_q;
          we_a_o = 1;
        end
        state_d = DONE;
      end

      TRAP: begin
        // stay in trap until reset
        v_req_ready_o     = 1'b0;
        v_resp_o.done     = 1'b1;
        v_resp_o.trap     = 1'b1;
        //v_resp_o.rd_we    = 1'b0; // for now we decided to write directly to the register file
        //v_resp_o.rd_wdata = 32'd0; // for now we decided to write directly to the register file
        state_d = IDLE; // or stay in TRAP? for now the core will handle it
      end

      DONE: begin
        v_req_ready_o = 1'b0;
        v_resp_o.done     = 1'b1;
        v_resp_o.trap     = 1'b0;
        state_d = IDLE;
      end
    endcase
  end

  // ---- VRF write/read wires ----
  logic        vrf_wr_en;
  logic  [4:0] vrf_wr_vreg;
  logic  [1:0] vrf_wr_bank;
  logic [31:0] vrf_wr_wdata;
  logic  [3:0] vrf_wr_wstrb;

  // (read side will be used later for stores)
  logic        vrf_rd_en;
  logic  [4:0] vrf_rd_vreg;
  logic  [1:0] vrf_rd_bank;
  logic [31:0] vrf_rd_rdata;

  ibex_vrf u_vrf (
    .clk_i(clk_i), .rst_ni(rst_ni),
    .wr_en_i   (vrf_wr_en),
    .wr_vreg_i (vrf_wr_vreg),
    .wr_bank_i (vrf_wr_bank),
    .wr_wdata_i(vrf_wr_wdata),
    .wr_wstrb_i(vrf_wr_wstrb),
    .rd_en_i   (1'b0),
    .rd_vreg_i ('0),
    .rd_bank_i ('0),
    .rd_rdata_o()
  `ifdef VERIF_VRF_PEEK
  ,.vrf_peek_o (vrf_peek_bus),
    .vrf_peek_idx_i (vd_idx_q)
  `endif
  );

  // NOTE: for simplicity, we always set idx_mode to 0 (start at byte 0 of bank word), because vstart is always 0 in this cut.

  logic [31:0] base_q;
  logic [4:0] vd_idx_q;
  // ---- LSU micro-FSM ----
  // will be later moved to a load store unit module
  logic  [4:0] idx_q, idx_d;      // 0..15 (element index) for SEW=8, wenn SEW=16 dann 0..7
  logic [31:0] beat1_q, beat1_d;      // first aligned word
  logic [31:0] beat2_q, beat2_d;      // second aligned word (for misaligned)
  logic [31:0] word_q,  word_d;       // final 32b window for this beat

  // these are for lsuv module
  // assign base_q = base_i; this are for lsuv module
  // assign vd_idx_q = vd_idx_i;

  // Use latched request values to derive base/index
  assign base_q = req_rs1_q;
  assign vd_idx_q = req_rd_q;

  // assign vrf_wr_vreg  = vd_idx_q; // destination vreg, we don't need to change it in the combinatorial logic
  // assign vrf_wr_bank  = idx_q[3:2];  // 4 lanes per bank when SEW=8

  logic [31:0] addr, a0_aligned, a1_aligned;
  logic [1:0]  sh;                    // byte offset within 32b word
  logic        misaligned;

  localparam int BYTES_PER_BEAT = 4;
  logic [1:0] EEW_BYTES = (sew_q==2'd0) ? 1 : 2;
  logic [2:0] ELEMS_PER_BEAT = BYTES_PER_BEAT / EEW_BYTES; // 4 oder 2

  // todo: why should we write again, if we take the bytes that we need from the first beat. Use the following to integrate this feature
  // until now we always read two beats when misaligned
  //logic [2:0]  Nbytes      = elems_beat * EEW_BYTES;         // 1..4 (8b: 4/3/2/1; 16b: 4/2)
  //logic        need_second = (sh != 2'd0) && ((sh + Nbytes) > 3'd4);

  logic [5:0] byte_idx;                               // bis 30 (16*2-2)
  assign byte_idx = idx_e_q * EEW_BYTES;

  assign addr       = base_q + byte_idx; // current byte address after incremention // 
  assign sh         = addr[1:0];
  assign misaligned = (sh != 2'b00);
  assign a0_aligned = {addr[31:2], 2'b00}; // aligned down
  assign a1_aligned = a0_aligned + 32'd4; // aligned up

  // helpers
  logic [2:0] elements_left       = (vl_q > idx_q) ? (vl_q - idx_q) : 3'd0;
  logic [2:0] elements_from_read  = (elements_left > ELEMS_PER_BEAT) ? ELEMS_PER_BEAT : elements_left; // 1..4 (last can be 1..3)

  logic [3:0] mask;
  // mask for tail (idx_mod is always 0 here) // todo: check if this is still correct for SEW=16
  if (EEW_BYTES == 1) begin // sew=8
    mask =
      (elements_from_read == 3'd4) ? 4'b1111 :
      (elements_from_read == 3'd3) ? 4'b0111 :
      (elements_from_read == 3'd2) ? 4'b0011 :
      (elements_from_read == 3'd1) ? 4'b0001 : 4'b0000;
  end
  else if (EEW_BYTES == 2) begin // sew=16
    mask =
      (elements_from_read == 3'd2) ? 4'b1111 :
      (elements_from_read == 3'd1) ? 4'b1100 : 4'b0000;
  end

  logic [63:0] merged; // todo: Latches/Konflikt risiko warum ??

  always_comb begin
    // defaults
    lsu_d = lsu_q;
    idx_d = idx_q;
    beat1_d = beat1_q;
    beat2_d = beat2_q;
    word_d  = word_q;

    ld_done     = 1'b0;
    lsu_fault    = 1'b0;

    data_req_o = 1'b0;
    data_addr_o  = '0;
    data_we_o = 1'b0;
    data_wdata_o = '0;
    data_be_o = 4'b0000;

    // TODO: check VRF defaults
    vrf_wr_en    = 1'b0;
    vrf_wr_wdata = data_rdata_i;
    vrf_wr_wstrb = 4'b0000;

    // directly assigned see the assign statements above
    vrf_wr_vreg  = vd_idx_q;
    vrf_wr_bank  = byte_idx[3:2];

    unique case (lsu_q)
      LSU_IDLE:  if (ld_rq) begin
        lsu_d = LSU_SETUP;
        idx_d = '0; // wichtig
      end

      LSU_SETUP: begin
        // Preconditions for this first cut (assert in TB):
        // base_q[1:0] == 2'b00  &&  (vl_q % 4 == 0)
        lsu_d = (vl_q == 0) ? LSU_DONE : LSU_REQ1;
      end

      // ----- First aligned read (always) -----
      LSU_REQ1: begin
        data_req_o  = 1'b1;
        data_addr_o = a0_aligned;   // aligned down
        data_we_o   = 1'b0;
        if (data_req_o && data_gnt_i) lsu_d = LSU_WAIT1;
      end

      LSU_WAIT1: begin
        if (data_rvalid_i) begin
          if (data_err_i) lsu_d = LSU_FAULT;
          else begin
            beat1_d = data_rdata_i;
            // todo: when optimizing see above: lsu_d = need_second ? LSU_REQ2 : LSU_ALIGN; // <— use the condition
            lsu_d   = misaligned ? LSU_REQ2 : LSU_ALIGN;
          end
        end
      end

      // ----- Second aligned read (only if misaligned) -----
      LSU_REQ2: begin
        data_req_o  = 1'b1;
        data_addr_o = a1_aligned;
        data_we_o   = 1'b0;
        if (data_req_o && data_gnt_i) lsu_d = LSU_WAIT2;
      end

      LSU_WAIT2: begin
        if (data_rvalid_i) begin
          if (data_err_i) lsu_d = LSU_FAULT;
          else begin
            beat2_d = data_rdata_i;
            lsu_d   = LSU_ALIGN;
          end
        end
      end

      // when we use optimization obove: todo:
      //LSU_ALIGN: begin
      //  if (need_second) begin
      //    logic [63:0] merged = {beat2_q, beat1_q};
      //    word_d = merged >> (8*sh);
      //  end else begin
      //    word_d = beat1_q >> (8*sh);   // auch bei nur einem Read sh berücksichtigen
      //  end
      //  lsu_d = LSU_WRITE;
      //end


      // ----- Assemble the exact 4-byte window we want -----
      LSU_ALIGN: begin // todo: maybe will be later replaced by the commented out optimization above
        if (misaligned) begin
          // 64-bit merge: [beat2][beat1], then pick 4 bytes starting at 'sh'
          // logic [63:0] merged = {beat2_q, beat1_q};
          merged = {beat2_q, beat1_q};
          word_d = merged >> (sh * 8);
        end else begin
          word_d = beat1_q;
        end
        lsu_d = LSU_WRITE;
      end

      LSU_WRITE: begin
        // current VRF bank = idx_q[3:2]; idx_mod==0 -> no shift needed
        vrf_wr_en    = (elements_from_read != 0);
        vrf_wr_vreg  = vd_idx_q;
        vrf_wr_bank  = byte_idx[3:2];
        vrf_wr_wdata = word_q;     // already the right 4-byte window, aligned to byte 0
        vrf_wr_wstrb = mask;       // only low N bytes if tail

        // advance or finish
        idx_d = idx_q + elements_from_read;  // (3-bit -> zero-extends fine)
        lsu_d = (idx_d >= vl_q) ? LSU_DONE : LSU_REQ1;
      end

      LSU_FAULT: begin
        lsu_fault = 1'b1;
        ld_done = 1'b1;
        lsu_d     = LSU_IDLE;
      end

      LSU_DONE: begin
        ld_done = 1'b1;
        lsu_d    = LSU_IDLE;
      end
    endcase
  end

  // State/data registers
  always_ff @(posedge clk_i or negedge rst_ni) begin
    if (!rst_ni) begin
      lsu_q   <= LSU_IDLE;
      idx_q   <= '0;
      beat1_q <= '0;
      beat2_q <= '0;
      word_q  <= '0;
    end else begin
      lsu_q   <= lsu_d;
      idx_q   <= idx_d;
      beat1_q <= beat1_d;
      beat2_q <= beat2_d;
      word_q  <= word_d;
    end
  end

  // Store LSU
  typedef enum logic [3:0] {
    ST_IDLE, ST_SETUP,
    ST_VRF_RD, ST_VRF_LATCH,
    ST_REQ1, ST_WAIT1,
    ST_REQ2, ST_WAIT2,
    ST_DONE, ST_FAULT
  } st_state_e;

  st_state_e st_q, st_d;

  //logic [31:0] base_q;              // req_rs1_q (latched earlier)
  //logic  [4:0] vs_idx_q;            // source vreg index (use rd field in your proxy scheme)
  //logic  [4:0] idx_q, idx_d;        // byte element index 0..15
  //todo: many signals were redefined here, should be shared with load LSU
  logic [31:0] bank_word_q, bank_word_d;  // 32-bit from VRF bank
  logic [31:0] w0_data, w1_data;    // store beats' data
  logic  [3:0] w0_strb, w1_strb;    // store beats' byte-enables
  //logic [31:0] a0_aligned, a1_aligned;
  //logic [31:0] addr;                // base_q + idx_q
  //logic [1:0]  sh;                  // addr[1:0]
  //logic [2:0]  bytes_left;          // vl-idx (clamped)
  //logic [2:0]  N;                   // bytes to store this beat = min(4, bytes_left)
  logic        need_two;            // second write needed?

  // VRF connections for store
  assign vrf_rd_vreg = vs_idx_q;
  assign vrf_rd_bank = byte_idx[3:2];

  //assign bytes_left = (vl_q > idx_q) ? (vl_q - idx_q) : 3'd0;
  //assign N          = (bytes_left > 3'd4) ? 3'd4 : bytes_left; // same as bytes from read

  // 1 or 2 stores this beat?
  logic [2:0]  Nbytes      = elems_beat * EEW_BYTES;         // 1..4 (8b: 4/3/2/1; 16b: 4/2)
  assign need_two   = (sh != 2'd0) && ((sh + Nbytes) > 3'd4); // wir brauchen zwei beats wenn die verschiebung and der anzahl der gebleiebenen Bytes größer als 4 ist.

  always_comb begin
    st_d          = st_q;
    idx_d         = idx_q;
    bank_word_d   = bank_word_q;

    // defaults: memory
    data_req_o    = 1'b0;
    data_addr_o   = '0;
    data_we_o     = 1'b0;
    data_wdata_o  = '0;
    data_be_o     = 4'b0000;

    // defaults: VRF read
    vrf_rd_en     = 1'b0;

    // status
    st_done       = 1'b0;
    st_fault      = 1'b0;

    // precompute masks/data for current beat (from bank_word_q)
    logic [1:0]  sh_l = sh;
    logic [2:0]  N_l  = elems_beat;
    logic [2:0]  first = need_two ? (3'd4 - {1'b0,sh_l}) : Nbytes;
    logic [2:0]  second= need_two ? (Nbytes - first)         : 3'd0;

    // one-beat packet (or first of two)
    logic [31:0] w0_data_l = bank_word_q << (8*sh_l);
    logic [3:0]  w0_strb_l;

  
    // full 4-byte mask << sh
    //logic [3:0]  full_at_sh = (4'b1111 << sh_l); // wir verschieben und erstellen die erste Mask
    // low N bytes at starting pos sh
    //logic [3:0]  lowN_at_sh = (N_l==3'd4) ? full_at_sh
    //                        : ((4'b1111 >> (4 - N_l)) << sh_l);
    // mask first bytes only (if two-beat)
    //logic [3:0]  first_mask = (first==3'd4) ? full_at_sh
    //                        : ((4'b1111 >> (4 - first)) << sh_l);
    //assign w0_strb_l = need_two ? first_mask : lowN_at_sh;

    // kann dadurch vereinfacht werden zu (todo: verify):
    assign w0_strb_l = (first==3'd4) ? 4'b1111
                            : ((4'b1111 >> (4 - first)) << sh_l);

    // second-beat packet (if needed)
    logic [31:0] w1_data_l = bank_word_q >> (8*first);
    logic [3:0]  w1_strb_l = (second==3'd0) ? 4'b0000
                          : (4'b1111 >> (4 - second));

    unique case (st_q)
      ST_IDLE: begin
        if (st_rq) begin
          idx_d = '0; // wichtig
          st_d  = ST_SETUP;
        end
      end

      ST_SETUP: begin
        // assert: SEW=8, vl_q ≤ 16
        st_d = (vl_q == 0) ? ST_DONE : ST_VRF_RD;
      end

      // read VRF bank word
      ST_VRF_RD: begin
        vrf_rd_en   = 1'b1;
        // your VRF returns data REGISTERED next cycle → go latch
        st_d        = ST_VRF_LATCH;
      end

      ST_VRF_LATCH: begin
        bank_word_d = vrf_rd_rdata;        // capture VRF word
        st_d        = ST_REQ1;
      end

      // first memory write
      ST_REQ1: begin
        data_req_o   = 1'b1;
        data_addr_o  = a0_aligned;
        data_we_o    = 1'b1;
        data_wdata_o = w0_data_l;
        data_be_o    = w0_strb_l;
        if (data_req_o && data_gnt_i) st_d = ST_WAIT1;
      end

      ST_WAIT1: begin
        // if your memory returns store responses, wait for rvalid_i
        if (data_rvalid_i) begin
          if (data_err_i) st_d = ST_FAULT;
          else            st_d = need_two ? ST_REQ2 : ST_DONE;
        end
        // if not, you can shortcut: st_d = need_two ? ST_REQ2 : ST_DONE;
      end

      // optional second write
      ST_REQ2: begin
        data_req_o   = 1'b1;
        data_addr_o  = a1_aligned;
        data_we_o    = 1'b1;
        data_wdata_o = w1_data_l;
        data_be_o    = w1_strb_l;
        if (data_req_o && data_gnt_i) st_d = ST_WAIT2;
      end

      ST_WAIT2: begin
        if (data_rvalid_i) begin
          if (data_err_i) st_d = ST_FAULT;
          else begin           
            //st_d = ST_DONE;
            idx_d = idx_q + elems_beat;                  // zero-extends fine
            st_d  = (idx_d >= vl_q) ? ST_DONE : ST_VRF_RD;
          end
        end
        // (same note as WAIT1 if your memory has no store response)
      end

      ST_DONE: begin
        // advance to next chunk or finish instruction
        //idx_d = idx_q + N;                  // zero-extends fine
        //st_d  = (idx_d >= vl_q) ? ST_IDLE : ST_VRF_RD;
        //if (idx_d >= vl_q) st_done = 1'b1;  // signal control FSM
        st_done = 1'b1;  // signal control FSM
        st_d    = ST_IDLE;
      end

      ST_FAULT: begin
        st_fault = 1'b1;
        st_done  = 1'b1;
        st_d     = ST_IDLE;
      end
    endcase
  end

  always_ff @(posedge clk_i or negedge rst_ni) begin
    if (!rst_ni) begin
      st_q         <= ST_IDLE;
      //idx_q        <= '0; // already zeroed see the reset above
      bank_word_q  <= '0;
    end else begin
      st_q         <= st_d;
      //idx_q        <= idx_d;
      bank_word_q  <= bank_word_d;
    end
  end

endmodule
