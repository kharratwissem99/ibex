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
  logic [6:0]   opcode_q, opcode_d;   // Added missing opcode signals

  // ---- Control FSM ----
  typedef enum logic [2:0] {IDLE, DECODE, EXECUTE, WRITEBK, DONE, TRAP} vstate_e;
  vstate_e state_q, state_d;

  // simple CSR regs, todo: do we need vtype?, vstart?, do we need state and next state for them?
  logic [4:0] vl_q, vl_d;      // up to 16 (for SEW=8) or 8 (for SEW=16). In specification vl is a 32 bit register. 
  logic [1:0] sew_q, sew_d;     // 0=8b, 1=16b // todo: should these be normally extracted from vtype CSR?

  // hilfvariablen verwendet in Execute stage
  logic [31:0] avl;
  logic [4:0] max_elems;

  // internal signals used for communication between the main control FSM and Load FSM
  logic ld_rq_q, ld_rq_d, ld_done, ld_fault;
  // internal signals used for communication between the main control FSM and Store FSM
  logic st_rq_q, st_rq_d, st_done, st_fault;

  logic lsu_done;
  assign lsu_done = ld_done || st_done;

  logic lsu_fault;
  assign lsu_fault = st_fault || ld_fault;

  // assign ld_rq = ld_idle && (state_q == EXECUTE) && (opcode_q == 7'h07);
  // assign st_rq = st_idle && (state_q == EXECUTE) && (opcode_q == 7'h27);

  // todo: should we combine all sequential processes into one always_ff block? until now 3 were used.
  always_ff @(posedge clk_i or negedge rst_ni) begin
    if (!rst_ni) begin
      state_q <= IDLE;
      req_insn_q    <= '0;
      req_rs1_q     <= '0;
      req_rd_q      <= '0;
      rs_data_q     <= '0;
      opcode_q      <= '0;
      // reset CSR regs
      vl_q          <= '0;
      sew_q         <= '0;

      ld_rq_d <= '0;
      st_rq_d <= '0;
    end
    else  begin       
      state_q <= state_d;
      req_insn_q    <= req_insn_d;
      req_rs1_q     <= req_rs1_d;
      req_rd_q      <= req_rd_d;
      rs_data_q     <= rs_data_d;
      opcode_q      <= opcode_d;
      // update CSR regs
      vl_q         <= vl_d;
      sew_q        <= sew_d;

      ld_rq_q        <= ld_rq_d;
      st_rq_q        <= st_rq_d;
    end
  end

  // Die letzte request speichern
  always_comb begin
    if (v_req_valid_i) begin
      req_insn_d   = v_req_i.insn;
      opcode_d     = v_req_i.insn[6:0];
      req_rs1_d    = v_req_i.rs1_val;
      req_rd_d     = v_req_i.rd_idx;
    end
    else begin
      req_insn_d   = req_insn_q;
      opcode_d     = opcode_q;
      req_rs1_d    = req_rs1_q;
      req_rd_d     = req_rd_q;
    end
  end

  // next-state logic
  always_comb begin
    state_d     = state_q;

    //response
    v_resp_o    = '{default:0}; // clear response by default
    v_req_ready_o = 1'b0;

    // output to the register file
    raddr_a_o = req_rs1_q; // read address a
    raddr_b_o = req_rs1_q; // read address v
    waddr_a_o = 32'b0; //write address
    wdata_a_o = 0; // write data
    we_a_o = 1'b0; // write enable

    rs_data_d = rs_data_q

    // crs registers
    vl_d        = vl_q;
    sew_d       = sew_q;

    ld_rq_d = ld_rq_q;
    ld_st_d = ld_st_q;

    case (state_q)
      IDLE: begin
        v_req_ready_o = 1'b1; // ready to take new request
        if (v_req_valid_i) begin
          if (v_req_i.insn[6:0] == 7'h57) state_d = DECODE;
          else if (v_req_i.insn[6:0] == 7'h07) begin 
            state_d = EXECUTE;
            ld_rq_d = 1'b1;
          end
          else if (v_req_i.insn[6:0] == 7'h27) begin 
            state_d = EXECUTE;
            st_rq_d = 1'b1;
          end
          else state_d = TRAP;
        end
      end

      DECODE: begin
        v_req_ready_o = 1'b0;
        // read from register file: laut ibex documentation 
        // "https://ibex-core.readthedocs.io/en/latest/03_reference/register_file.html":
        // register file data is available the same cycle a read is requested.
        raddr_a_o = req_rs1_q;
        rs_data_d = rdata_a_i;
        if (err_i) state_d = TRAP;
        else state_d = EXECUTE;
      end

      EXECUTE: begin
        ld_rq_d = 1'b0;
        st_rq_d = 1'b0;
        if (opcode_q == 7'h57) begin
          v_req_ready_o = 1'b0;
          avl    = rs_data_q; // Hilfvariable
          sew_d = req_insn_q[25:23]; // todo: In which position in vtypei we find sew_d? 23 to 25?
          // compute max elements per vreg
          max_elems = (sew_d==0) ? 16 : 8; // hilfvariable
          vl_d = (avl < max_elems) ? avl[4:0] : max_elems;
          state_d = WRITEBK;
        end
        else begin 
          if (lsu_done) begin
            if (lsu_fault) state_d = TRAP;
            else state_d = DONE;
          end
        end
      end

      WRITEBK: begin
        v_req_ready_o     = 1'b0;
        v_resp_o.done     = 1'b0;
        v_resp_o.trap     = 1'b0;
        if (opcode_q == 7'h57) begin
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
    .rd_en_i   (vrf_rd_en),
    .rd_vreg_i (vrf_rd_vreg),
    .rd_bank_i (vrf_rd_bank),
    .rd_rdata_o(vrf_rd_rdata)
  `ifdef VERIF_VRF_PEEK
  ,.vrf_peek_o (vrf_peek_bus),
    .vrf_peek_idx_i (vd_idx_q)
  `endif
  );

  // ---- LUV (Load Unit Vector) Instantiation ----
  
  // LUV memory interface signals
  logic        luv_data_req;
  logic [31:0] luv_data_addr;
  logic        luv_data_we;
  logic [3:0]  luv_data_be;
  logic [31:0] luv_data_wdata;
  
  // SUV memory interface signals  
  logic        suv_data_req;
  logic [31:0] suv_data_addr;
  logic        suv_data_we;
  logic [3:0]  suv_data_be;
  logic [31:0] suv_data_wdata;
  
  // Memory interface multiplexing
  // Priority: Load operations have priority over store operations
  logic mem_luv_active;
  assign mem_luv_active = luv_data_req; // todo: note until now load and store units will never work at the same time
  
  assign data_req_o   = mem_luv_active ? luv_data_req   : suv_data_req;
  assign data_addr_o  = mem_luv_active ? luv_data_addr  : suv_data_addr;
  assign data_we_o    = mem_luv_active ? luv_data_we    : suv_data_we;
  assign data_be_o    = mem_luv_active ? luv_data_be    : suv_data_be;
  assign data_wdata_o = mem_luv_active ? luv_data_wdata : suv_data_wdata;

  luv u_luv (
    .clk_i              (clk_i),
    .rst_ni             (rst_ni),
    
    // Control interface
    .vd_idx_i           (req_rd_q),
    .base_i             (req_rs1_q),  
    .vl_i               (vl_q),
    .request_type_i     (sew_q == 2'd0 ? 5'd0 : 5'd5), // 0=SEW8, 5=SEW16 // todo: bind them with the insn.width
    
    .lu_rq              (ld_rq),
    .ld_done            (ld_done),
    .ld_fault           (ld_fault),
    
    // VRF interface  
    .vrf_wr_en_o        (vrf_wr_en),
    .vrf_wr_vreg_o      (vrf_wr_vreg),
    .vrf_wr_bank_o      (vrf_wr_bank), 
    .vrf_wr_wdata_o     (vrf_wr_wdata),
    .vrf_wr_wstrb_o     (vrf_wr_wstrb),
    
    // Memory interface
    .data_req_o         (luv_data_req),
    .data_addr_o        (luv_data_addr),
    .data_we_o          (luv_data_we),
    .data_be_o          (luv_data_be),
    .data_wdata_o       (luv_data_wdata),
    
    .data_gnt_i         (data_gnt_i & mem_luv_active), // todo: es ist ok, both kann take gnt signal
    .data_rvalid_i      (data_rvalid_i),
    .data_err_i         (data_err_i),
    .data_rdata_i       (data_rdata_i)
  );

  // ---- SUV (Store Unit Vector) Instantiation ----
  suv u_suv (
    .clk_i              (clk_i),
    .rst_ni             (rst_ni),
    
    // Control interface
    .vd_idx_i           (req_rd_q),  // Note: for stores, this is source register
    .base_i             (req_rs1_q),
    .vl_i               (vl_q),
    .request_type_i     (sew_q == 2'd0 ? 5'd0 : 5'd5), // 0=SEW8, 5=SEW16 // todo: bind them with the insn.width
    
    .st_rq              (st_rq),
    .st_done            (st_done),
    .st_fault           (st_fault),
    
    // VRF interface
    .rd_en_o            (vrf_rd_en),
    .rd_vreg_o          (vrf_rd_vreg),
    .rd_bank_o          (vrf_rd_bank),
    .rd_rdata_i         (vrf_rd_rdata),
    
    // Memory interface
    .data_req_o         (suv_data_req),
    .data_addr_o        (suv_data_addr),  
    .data_we_o          (suv_data_we),
    .data_be_o          (suv_data_be),
    .data_wdata_o       (suv_data_wdata),
    
    .data_gnt_i         (data_gnt_i & ~mem_luv_active) // todo: es ist ok, both kann take gnt signal
    // Note: SUV doesn't need rvalid/err/rdata for simple stores
  );

endmodule
