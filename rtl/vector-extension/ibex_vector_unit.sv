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
  output logic                     data_req_o, // data_req_o
  output logic [31:0]              data_addr_o, // data_addr_o
  output logic                     data_we_o, // data_we_o
  output logic [3:0]               data_be_o, // data_be_o
  output logic [31:0]              data_wdata_o, // data_wdata_o

  input  logic                     data_gnt_i, // data_gnt_i
  input  logic                     data_rvalid_i, // data_rvalid_i
  input  logic                     data_err_i, // data_err_i
  input  logic [31:0]              data_rdata_i // data_rdata_i
);

  logic [31:0]  req_insn_q, req_insn_d;
  logic [31:0]  req_rs1_q, req_rs1_d;
  logic  [4:0]  req_rd_q, req_rd_d;

  logic         is_vsetvli_q, is_vsetvli_d;
  logic         is_vle8_q, is_vle8_d;
  // (later: is_vse8_q, is_vle16_q, ...)

  // inside ibex_vector_unit.sv
  typedef enum logic [2:0] {IDLE, DECODE, EXECUTE, WRITEBK, TRAP} vstate_e;
  vstate_e state_q, state_d;

  // simple CSR regs
  logic [4:0] vl_q;      // up to 16 (for SEW=8) or 8 (for SEW=16)
  logic [1:0] sew_q;     // 0=8b, 1=16b
  // next-state for CSR regs
  logic [4:0] vl_d;
  logic [1:0] sew_d;

  logic [1:0] sew_sel; // example
  logic [31:0] avl;

  logic [4:0] max_elems;

  logic lsu_start;
  logic lsu_done;
  logic lsu_fault;

  always_ff @(posedge clk_i or negedge rst_ni) begin
    if (!rst_ni) begin
      state_q <= IDLE;
      req_insn_q    <= '0;
      req_rs1_q     <= '0;
      req_rd_q      <= '0;
      is_vsetvli_q  <= 1'b0;
      is_vle8_q     <= 1'b0;
      // reset CSR regs
      vl_q         <= '0;
      sew_q        <= '0;
    end
    else  begin       
      state_q <= state_d;
      req_insn_q    <= req_insn_d;
      req_rs1_q     <= req_rs1_d;
      req_rd_q      <= req_rd_d;
      is_vsetvli_q  <= is_vsetvli_d;
      is_vle8_q     <= is_vle8_d;
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

    req_insn_d   = req_insn_q;
    req_rs1_d    = req_rs1_q;
    req_rd_d     = req_rd_q;

  // Proxy decode (for now). Example:
  // opcode=0x0B; funct7=0x01; funct3=000 -> vsetvli proxy
  // funct3=001 -> vle8 proxy
    is_vsetvli_d = is_vsetvli_q;
  is_vle8_d = is_vle8_q;

  // Defaults for next-state regs and LSU start pulse
  vl_d        = vl_q;
  sew_d       = sew_q;
  lsu_start   = 1'b0;

    case (state_q)
      IDLE: begin
        v_req_ready_o = 1'b1; // ready to take new request
        if (v_req_valid_i) begin
          state_d = DECODE;
          req_insn_d   = v_req_i.insn;
          req_rs1_d    = v_req_i.rs1_val;
          req_rd_d     = v_req_i.rd_idx;

          // Proxy decode (for now). Example:
          // opcode=0x0B; funct7=0x01; funct3=000 -> vsetvli proxy
          // funct3=001 -> vle8 proxy
          is_vsetvli_d = (v_req_i.insn[6:0]  == 7'h0B) &&
                          (v_req_i.insn[31:25]== 7'h01) &&
                          (v_req_i.insn[14:12]== 3'b000);

          is_vle8_d    = (v_req_i.insn[6:0]  == 7'h0B) &&
                          (v_req_i.insn[31:25]== 7'h01) &&
                          (v_req_i.insn[14:12]== 3'b001);
        end else begin
          // no new request: clear decode flags
          is_vsetvli_d = 1'b0;
          is_vle8_d    = 1'b0;
        end
      end

      DECODE: begin
        v_req_ready_o = 1'b0;
        // here you’d check v_req_i.insn opcode/funct
        // assume proxy => always vsetvli
        // state_d = EXECUTE; # old
        if (is_vsetvli_q) state_d = EXECUTE;        // one-cycle op
        else if (is_vle8_q) state_d = EXECUTE;      // will kick LSU micro-FSM
        else begin
          // unsupported -> trap
          // v_resp_o.done = 1'b1;
          // v_resp_o.trap = 1'b1;
          state_d = TRAP;
        end
      end

      EXECUTE: begin
        if (is_vsetvli_q) begin
          // parse SEW from imm or funct3 (proxy encoding)
          v_req_ready_o = 1'b0;
          sew_sel = req_insn_q[21:20]; // example
          avl    = req_rs1_q;

          case (sew_sel)
            2'b00: sew_d = 2'd0; // SEW=8
            2'b01: sew_d = 2'd1; // SEW=16
            default: sew_d = 2'd0;
          endcase

          // compute max elements per vreg
          max_elems = (sew_d==0) ? 16 : 8;

          vl_d = (avl < max_elems) ? avl[4:0] : max_elems;

          state_d = WRITEBK;
        end
        else if (is_vle8_q && (sew_q == 2'd0)) begin
          // ---- kick LSU micro-FSM ----
          // set up starting indices, base, dest vreg, etc.
          // (do not emit v_resp here; LSU will assert done when finished)
          // lsu_start    = 1'b1;      // a one-cycle pulse to start LSU
          lsu_start = (lsu_q == LSU_IDLE);  // single-cycle pulse when LSU idle
          if (lsu_done) state_d = WRITEBK;  // for loads, WB often just signals done
          // state_d      = EXECUTE;   // stay here until LSU_finished
          if (lsu_done) state_d = WRITEBK;
        end
      end

      WRITEBK: begin
        v_req_ready_o = 1'b0;
        v_resp_o.done     = 1'b1;
        v_resp_o.trap     = 1'b0;
        // in the future maybe we will directly write to register file
        // here we just return the value
        if (is_vsetvli_q) begin
          v_resp_o.rd_we    = (req_rd_q != 0);
          v_resp_o.rd_wdata = {27'd0, vl_q}; // return VL in rd
        end else begin
          // VLE8 does not write back to scalar rd in this cut
          v_resp_o.rd_we    = 1'b0;
          v_resp_o.rd_wdata = 32'd0;
        end
        state_d = IDLE;
      end

      TRAP: begin
        // stay in trap until reset
        v_req_ready_o = 1'b0;
        v_resp_o.done     = 1'b1;
        v_resp_o.trap     = 1'b1;
        v_resp_o.rd_we    = 1'b0;
        v_resp_o.rd_wdata = 32'd0;
        state_d = IDLE; // or stay in TRAP? for now the core will handle it
      end

      // DONE: begin
      //   // wait until Ibex sees done, then back to IDLE
      //   v_req_ready_o = 1'b0;
      //   if (!v_req_valid_i) state_d = IDLE;
      // end
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

  logic [31:0] base_q;
  logic [4:0] vd_idx_q;
  // ---- LSU micro-FSM ----
  // will be later moved to a load store unit module
  logic  [4:0] idx_q, idx_d;      // 0..15 (element index)
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

  // ---- LSU / VRF state ----
  typedef enum logic [3:0] {
    LSU_IDLE, LSU_SETUP,
    LSU_REQ1, LSU_WAIT1,
    LSU_REQ2, LSU_WAIT2,
    LSU_ALIGN,
    LSU_WRITE, LSU_WRITE2,
    LSU_DONE, LSU_FAULT
  } lsu_state_e;
  lsu_state_e lsu_q, lsu_d;

  logic [31:0] addr, a0_aligned, a1_aligned;
  logic [1:0]  sh;                    // byte offset within 32b word
  logic        misaligned;

  assign addr       = base_q + idx_q; // current byte address after incremention
  assign sh         = addr[1:0];
  assign misaligned = (sh != 2'b00);
  assign a0_aligned = {addr[31:2], 2'b00}; // aligned down
  assign a1_aligned = a0_aligned + 32'd4; // aligned up

  always_comb begin
    // defaults
    lsu_d = lsu_q;
    idx_d = idx_q;
    beat1_d = beat1_q;
    beat2_d = beat2_q;
    word_d  = word_q;

    lsu_done     = 1'b0;
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
    vrf_wr_bank  = idx_q[3:2];

    // Precompute some helpers (SEW=8 path)
    logic [1:0] idx_mod;                 // position within VRF bank word
    logic [2:0] bytes_left;              // how many elements remain
    logic [2:0] bytes_from_read;         // this beat moves up to 4 bytes
    logic [2:0] first_bytes;             // bytes written into current bank
    logic [2:0] second_bytes;            // spill bytes into next bank
    logic [31:0] wdata1, wdata2;
    logic [3:0]  mask1, mask2;

    idx_mod        = idx_q[1:0];
    bytes_left     = (vl_q > idx_q) ? (vl_q - idx_q) : 3'd0;
    bytes_from_read= (bytes_left > 3'd4) ? 3'd4 : bytes_left;
    // total bytes we want this beat limited by bank boundary inside the VRF word
    logic [2:0] space_in_bank = 3'd4 - {1'b0, idx_mod};
    first_bytes    = (space_in_bank < bytes_from_read) ? space_in_bank : bytes_from_read;
    second_bytes   = bytes_from_read - first_bytes;

    // shift/pack for VRF write(s) from the assembled 32b 'word_q'
    wdata1 = word_q << (8*idx_mod);
    mask1  = (first_bytes == 0) ? 4'b0000
                                : ((4'b1111 >> (4 - first_bytes)) << idx_mod);
    wdata2 = word_q >> (8*first_bytes);
    mask2  = (second_bytes == 0) ? 4'b0000
                                : (4'b1111 >> (4 - second_bytes));

    unique case (lsu_q)
      LSU_IDLE:  if (lsu_start) begin
        lsu_d = LSU_SETUP;
        idx_d = '0;
      end

      LSU_SETUP: begin
        // Preconditions for this first cut (assert in TB):
        // base_q[1:0] == 2'b00  &&  (vl_q % 4 == 0)
        lsu_d = (vl_q == 0) ? LSU_DONE : LSU_REQ;
      end

      // ----- First aligned read (always) -----
      LSU_REQ1: begin
        data_req_o  = 1'b1;
        data_addr_o = a0_aligned;   // aligned down
        data_we_o   = 1'b0;
        if (data_req_o && data_gnt_i) lsu_d = LSU_WAIT1;
      end

      // LSU_REQ: begin
      //   data_req_o = 1'b1;
      //   data_addr_o  = base_q + idx_q;   // EEW=1 byte, 4 bytes per beat
      //   data_we_o = 1'b0;             // load
      //   // wstrb=0000 on loads
      //   if (data_gnt_i) lsu_d = LSU_WAIT;
      // end

      LSU_WAIT1: begin
        if (data_rvalid_i) begin
          if (data_err_i) lsu_d = LSU_FAULT;
          else begin
            beat1_d = data_rdata_i;
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

      // ----- Assemble the exact 4-byte window we want -----
      LSU_ALIGN: begin
        if (misaligned) begin
          // 64-bit merge: [beat2][beat1], then pick 4 bytes starting at 'sh'
          logic [63:0] merged = {beat2_q, beat1_q};
          word_d = merged >> (sh * 8);
        end else begin
          word_d = beat1_q;
        end
        lsu_d = LSU_WRITE;
      end

      // LSU_WAIT: begin
      //   if (data_rvalid_i) begin
      //     if (data_err_i) begin
      //       // lsu_fault = 1'b1;
      //       lsu_d     = LSU_FAULT;
      //     end else begin
      //       // vrf_wr_en    = 1'b1;
      //       // vrf_wr_wstrb = 4'b1111;         // aligned full word
      //       lsu_d        = LSU_WRITE;
      //     end
      //   end
      // end

      // LSU_WRITE: begin
      //   // advance by 4 lanes (one 32b bank)
      //   vrf_wr_en    = 1'b1;
      //   vrf_wr_wstrb = 4'b1111;         // aligned full word
      //   if (idx_q + 5'd4 >= vl_q) begin // potensial overflow. todo check
      //     lsu_d = LSU_DONE;
      //   end else begin
      //     lsu_d = LSU_REQ;
      //     idx_d = idx_q + 5'd4;
      //   end
      // end

      // LSU_WRITE: begin
      //   // advance by 4 lanes (one 32b bank)
      //   vrf_wr_en    = 1'b1;
      //   vrf_wr_wdata = word_q;
      //   vrf_wr_wstrb = 4'b1111;         // aligned full word
      //   if (idx_q + 5'd4 >= vl_q) begin // potensial overflow. todo check
      //     lsu_d = LSU_DONE;
      //   end else begin
      //     lsu_d = LSU_REQ1;
      //     idx_d = idx_q + 5'd4;
      //   end
      // end

      // todo: implement LSU_WRITE and LSU_WRITE2 for misaligned case
      // ----- VRF write into current bank (and possibly split) -----
      LSU_WRITE: begin
        if (first_bytes != 0) begin
          vrf_wr_en    = 1'b1;
          vrf_wr_bank  = idx_q[3:2];
          vrf_wr_wdata = wdata1;
          vrf_wr_wstrb = mask1;
        end
        if (second_bytes != 0) begin
          lsu_d = LSU_WRITE2;                 // spill next cycle
        end else begin
          idx_d = idx_q + bytes_from_read[4:0];
          lsu_d = (idx_d >= vl_q) ? LSU_DONE : LSU_REQ1;
        end
      end

      // ----- Spill into next bank (only if needed) -----
      LSU_WRITE2: begin
        vrf_wr_en    = 1'b1;
        vrf_wr_bank  = (idx_q[3:2] + 2'd1);
        vrf_wr_wdata = wdata2;
        vrf_wr_wstrb = mask2;

        idx_d = idx_q + bytes_from_read[4:0];
        lsu_d = (idx_d >= vl_q) ? LSU_DONE : LSU_REQ1;
      end

      LSU_FAULT: begin
        lsu_fault = 1'b1;
        lsu_done = 1'b1;
        lsu_d     = LSU_IDLE;
      end

      LSU_DONE: begin
        lsu_done = 1'b1;
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

endmodule
