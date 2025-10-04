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

  logic [1:0] sew_sel; // example
  logic [31:0] avl;

  logic [4:0] max_elems;

  logic lsu_start;
  logic lsu_done;

  always_ff @(posedge clk_i or negedge rst_ni) begin
    if (!rst_ni) begin
      state_q <= IDLE;
      req_insn_q    <= '0;
      req_rs1_q     <= '0;
      req_rd_q      <= '0;
      is_vsetvli_q  <= 1'b0;
      is_vle8_q     <= 1'b0;
    end
    else  begin       
      state_q <= state_d;
      req_insn_q    <= req_insn_d;
      req_rs1_q     <= req_rs1_d;
      req_rd_q      <= req_rd_d;
      is_vsetvli_q  <= is_vsetvli_d;
      is_vle8_q     <= is_vle8_d;
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
            2'b00: sew_q = 2'd0; // SEW=8
            2'b01: sew_q = 2'd1; // SEW=16
            default: sew_q = 2'd0;
          endcase

          // compute max elements per vreg
          max_elems = (sew_q==0) ? 16 : 8;

          vl_q = (avl < max_elems) ? avl[4:0] : max_elems;

          state_d = WRITEBK;
        end
        else if (is_vle8_q) begin
          // ---- kick LSU micro-FSM ----
          // set up starting indices, base, dest vreg, etc.
          // (do not emit v_resp here; LSU will assert done when finished)
          lsu_start    = 1'b1;      // a one-cycle pulse to start LSU
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

endmodule
