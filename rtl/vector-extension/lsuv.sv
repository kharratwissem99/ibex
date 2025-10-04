module lsuv (
  input  logic         clk_i,
  input  logic         rst_ni,

  input logic  [4:0]  vd_idx_i,    // destination vector register index
  input logic [31:0]  base_i,      // base address (from rs1)

  input logic [4:0]   vl_q_i,      // vector length (from rs1)

  input  logic         lsu_start,  // pulse to start LSU operation
  output logic         lsu_done,   // pulse when operation done
  output logic         lsu_fault,  // pulse if any fault during operation
  
  // interface to ibex_vrf
  output logic         vrf_wr_en_o,
  output logic  [4:0]  vrf_wr_vreg_o,
  output logic  [1:0]  vrf_wr_bank_o,
  output logic [31:0]  vrf_wr_wdata_o,
  output logic  [3:0]  vrf_wr_wstrb_o,

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

  logic  [4:0] idx_q, idx_d;      // 0..15 (element index)
//   logic  [31:0] base_q;           // rs1 latched
//   logic  [4:0] vd_idx_q;          // destination vector register index
    assign base_q = base_i;
    assign vd_idx_q = vd_idx_i;

  assign vrf_wr_vreg  = vd_idx_q; // destination vreg, we don't need to change it in the combinatorial logic
  assign vrf_wr_bank  = idx_q[3:2];  // 4 lanes per bank when SEW=8

  typedef enum logic [2:0] {LSU_IDLE, LSU_SETUP, LSU_REQ, LSU_WAIT, LSU_WRITE, LSU_DONE} lsu_state_e;
  lsu_state_e lsu_q, lsu_d;

  always_comb begin
    // defaults
    lsu_d = lsu_q;
    idx_d = idx_q;

    lsu_done     = 1'b0;
    lsu_fault    = 1'b0;

    data_req_o = 1'b0;
    data_addr_o  = '0;
    data_we_o = 1'b0;
    data_wdata_o = '0;
    data_be_o = 4'b0000;

    vrf_wr_en    = 1'b0;
    vrf_wr_wdata = data_rdata_i;
    vrf_wr_wstrb = 4'b0000;

    // directly assigned see the assign statements above
    // vrf_wr_vreg
    // vrf_wr_bank 

    unique case (lsu_q)
      LSU_IDLE:  if (lsu_start) lsu_d = LSU_SETUP;

      LSU_SETUP: begin
        // Preconditions for this first cut (assert in TB):
        // base_q[1:0] == 2'b00  &&  (vl_q % 4 == 0)
        lsu_d = (vl_q_i == 0) ? LSU_DONE : LSU_REQ;
      end

      LSU_REQ: begin
        data_req_o = 1'b1;
        data_addr_o  = base_q + idx_q;   // EEW=1 byte, 4 bytes per beat
        data_we_o = 1'b0;             // load
        // wstrb=0000 on loads
        if (data_gnt_i) lsu_d = LSU_WAIT;
      end

      LSU_WAIT: begin
        if (data_rvalid_i) begin
          if (data_err_i) begin
            // lsu_fault = 1'b1;
            lsu_d     = LSU_FAULT;
          end else begin
            // vrf_wr_en    = 1'b1;
            // vrf_wr_wstrb = 4'b1111;         // aligned full word
            lsu_d        = LSU_WRITE;
          end
        end
      end

      LSU_WRITE: begin
        // advance by 4 lanes (one 32b bank)
        vrf_wr_en    = 1'b1;
        vrf_wr_wstrb = 4'b1111;         // aligned full word
        if (idx_q + 5'd4 >= vl_q) begin // potensial overflow. todo check
          lsu_d = LSU_DONE;
        end else begin
          lsu_d = LSU_REQ;
          idx_d = idx_q + 5'd4;
        end
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

  always_ff @(posedge clk_i or negedge rst_ni) begin
    if (!rst_ni) begin
      lsu_q <= LSU_IDLE;
      idx_q <= '0;
    end else begin
      lsu_q <= lsu_d;
      idx_q <= idx_d;
    //   if (lsu_q == LSU_SETUP)       idx_q <= 5'd0;
    //   else if (lsu_q == LSU_WRITE)  idx_q <= idx_q + 5'd4;
    end
  end
endmodule