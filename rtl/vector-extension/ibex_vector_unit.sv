// ibex_vector_unit.sv
`include "../ibex_pkg.sv"

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
  // output logic                     mem_req_valid_o,
  // input  logic                     mem_req_ready_i,
  // output logic [31:0]              mem_req_addr_o,
  // output logic                     mem_req_write_o,
  // output logic [31:0]              mem_req_wdata_o,
  // output logic [3:0]               mem_req_wstrb_o,
  // input  logic                     mem_resp_valid_i,
  // input  logic [31:0]              mem_resp_rdata_i,
  // input  logic                     mem_resp_err_i
);

  // inside ibex_vector_unit.sv
  typedef enum logic [2:0] {IDLE, DECODE, EXECUTE, WRITEBK, DONE} vstate_e;
  vstate_e state_q, state_d;

  // simple CSR regs
  logic [4:0] vl_q;      // up to 16 (for SEW=8) or 8 (for SEW=16)
  logic [1:0] sew_q;     // 0=8b, 1=16b

  // next-state logic
  always_comb begin
    state_d     = state_q;
    v_resp_o    = '{default:0}; // clear response by default
    v_req_ready_o = 1'b0;

    case (state_q)
      IDLE: begin
        v_req_ready_o = 1'b1; // ready to take new request
        if (v_req_valid_i) state_d = DECODE;
      end

      DECODE: begin
        v_req_ready_o = 1'b0;
        // here you’d check v_req_i.insn opcode/funct
        // assume proxy => always vsetvli
        state_d = EXECUTE;
      end

      EXECUTE: begin
        // parse SEW from imm or funct3 (proxy encoding)
        v_req_ready_o = 1'b0;
        logic [1:0] sew_sel = v_req_i.insn[21:20]; // example
        logic [31:0] avl    = v_req_i.rs1_val;

        case (sew_sel)
          2'b00: sew_q = 2'd0; // SEW=8
          2'b01: sew_q = 2'd1; // SEW=16
          default: sew_q = 2'd0;
        endcase

        // compute max elements per vreg
        logic [4:0] max_elems = (sew_q==0) ? 16 : 8;

        vl_q = (avl < max_elems) ? avl[4:0] : max_elems;

        state_d = WRITEBK;
      end

      WRITEBK: begin
        v_req_ready_o = 1'b0;
        v_resp_o.done     = 1'b1;
        v_resp_o.trap     = 1'b0;
        v_resp_o.rd_we    = (v_req_i.rd_idx != 0);
        v_resp_o.rd_wdata = {27'd0, vl_q}; // return VL in rd
        state_d           = DONE;
      end

      DONE: begin
        // wait until Ibex sees done, then back to IDLE
        v_req_ready_o = 1'b0;
        if (!v_req_valid_i) state_d = IDLE;
      end
    endcase
  end

  always_ff @(posedge clk_i or negedge rst_ni) begin
    if (!rst_ni) state_q <= IDLE;
    else         state_q <= state_d;
  end


  // logic v_req_ready, v_req_ready_next;
  // // Phase-1 bring-up defaults
  // assign v_req_ready_o   = v_req_ready; // accept when IDLE (we’ll refine)
  // assign v_resp_o        = '{done:1'b0, trap:1'b0, rd_we:1'b0, rd_wdata:32'd0, cause:5'd0};
  // // assign mem_req_valid_o = 1'b0;
  // // assign mem_req_addr_o  = '0;
  // // assign mem_req_write_o = 1'b0;
  // // assign mem_req_wdata_o = '0;
  // // assign mem_req_wstrb_o = 4'b0000;
  // always_ff @(posedge clk_i or negedge rst_ni) begin
  //   if (!rst_ni) begin
  //     // reset state
  //     v_req_ready <= 1'b0;
  //   end else begin
  //     // state transitions
  //     v_req_ready <= v_req_ready_next; 
  //   end
  // end

  // always_comb begin
  //   // combinational logic
  //   v_req_ready_next = v_req_ready;
  //   if (v_req_valid_i) begin
  //     v_req_ready_next = 1'b1;
  //   end
  //   else begin
  //     v_req_ready_next = 1'b0;
  //   end
  // end
endmodule
