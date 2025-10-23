module ibex_vrf #(
  parameter int NREGS = 32,
  parameter int VLEN = 128  // Vector length in bits
)(
  input  logic            clk_i,
  input  logic            rst_ni,

  // Write port: whole 128-bit register with byte enables
  input  logic            wr_en_i,
  input  logic [4:0]      wr_vreg_i,
  input  logic [VLEN-1:0] wr_wdata_i,
  input  logic [VLEN/8-1:0] wr_wstrb_i,  // 16 byte enables for 128-bit register

  // Read port A: whole 128-bit register
  input  logic            rd_en_a_i,
  input  logic [4:0]      rd_vreg_a_i,
  output logic [VLEN-1:0] rd_rdata_a_o,

  // Read port B: whole 128-bit register  
  input  logic            rd_en_b_i,
  input  logic [4:0]      rd_vreg_b_i,
  output logic [VLEN-1:0] rd_rdata_b_o

`ifdef VERIF_VRF_PEEK
 ,output logic [127:0]     vrf_peek_o     // optional: expose whole reg for TB
 ,input  logic [4:0]       vrf_peek_idx_i
`endif
);

  // Storage: NREGS × 128-bit registers
  logic [VLEN-1:0] vrf_mem [NREGS-1:0];

  // Write port with byte enables
  always_ff @(posedge clk_i) begin
    if (!rst_ni) begin
      // Reset not needed here as we use initial block for test data
    end else if (wr_en_i) begin
      // Byte-wise write with strobes
      for (int i = 0; i < VLEN/8; i++) begin
        if (wr_wstrb_i[i]) begin
          vrf_mem[wr_vreg_i][8*i +: 8] <= wr_wdata_i[8*i +: 8];
        end
      end
    end
  end

  // Read port A (combinational for better performance)
  always_comb begin
    if (rd_en_a_i) begin
      rd_rdata_a_o = vrf_mem[rd_vreg_a_i];
    end else begin
      rd_rdata_a_o = '0;
    end
  end

  // Read port B (combinational for better performance)
  always_comb begin
    if (rd_en_b_i) begin
      rd_rdata_b_o = vrf_mem[rd_vreg_b_i];
    end else begin
      rd_rdata_b_o = '0;
    end
  end

`ifdef VERIF_VRF_PEEK
  // expose whole 128b reg for TB
  always_comb begin
    vrf_peek_o = vrf_mem[vrf_peek_idx_i];
  end
`endif

initial begin
  // Initialize vector registers with distinctive test data
  #100; // Wait for reset
  
  // v1: Original test pattern (little-endian: LSB at [0])
  vrf_mem[1] = {32'hCAFEBABE, 32'hDEADBEEF, 32'hABCDEF00, 32'h12345678};
  
  // v2: Incremented pattern
  vrf_mem[2] = {32'hAFEBABEC, 32'hEADBEEF0, 32'hBCDEF011, 32'h23456789};
  
  // v3: Rotated pattern  
  vrf_mem[3] = {32'hFEBABECA, 32'hADBEEF01, 32'hCDEF0122, 32'h3456789A};
  
  // v4: Inverted pattern
  vrf_mem[4] = {32'h35014543, 32'h21524110, 32'h543210FF, 32'hEDCBA987};
  
  // v5: Alternating pattern
  vrf_mem[5] = {32'h5555AAAA, 32'hAAAA5555, 32'h5555AAAA, 32'hAAAA5555};
  
  // v31: Maximum register with special pattern
  vrf_mem[31] = {32'h0F0F0F0F, 32'hF0F0F0F0, 32'h00000000, 32'hFFFFFFFF};
  
  $display("VRF initialized:");
  $display("  v1  = 0x%032X", vrf_mem[1]);
  $display("  v2  = 0x%032X", vrf_mem[2]);
  $display("  v3  = 0x%032X", vrf_mem[3]);
  $display("  v4  = 0x%032X", vrf_mem[4]);
  $display("  v5  = 0x%032X", vrf_mem[5]);
  $display("  v31 = 0x%032X", vrf_mem[31]);
end

endmodule
