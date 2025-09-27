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

  logic v_req_ready, v_req_ready_next;
  // Phase-1 bring-up defaults
  assign v_req_ready_o   = v_req_ready; // accept when IDLE (we’ll refine)
  assign v_resp_o        = '{done:1'b0, trap:1'b0, rd_we:1'b0, rd_wdata:32'd0, cause:5'd0};
  // assign mem_req_valid_o = 1'b0;
  // assign mem_req_addr_o  = '0;
  // assign mem_req_write_o = 1'b0;
  // assign mem_req_wdata_o = '0;
  // assign mem_req_wstrb_o = 4'b0000;
  always_ff @(posedge clk_i or negedge rst_ni) begin
    if (!rst_ni) begin
      // reset state
      v_req_ready <= 1'b0;
    end else begin
      // state transitions
      v_req_ready <= v_req_ready_next; 
    end
  end

  always_comb begin
    // combinational logic
    v_req_ready_next = v_req_ready;
    if (v_req_valid_i) begin
      v_req_ready_next = 1'b1;
    end
    else begin
      v_req_ready_next = 1'b0;
    end
  end
endmodule
