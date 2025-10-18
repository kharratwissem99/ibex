module ibex_vrf #(
  parameter int NREGS = 32
)(
  input  logic            clk_i,
  input  logic            rst_ni,

  // Write: one 32-bit word (bank) with per-byte strobes
  input  logic            wr_en_i,
  input  logic [4:0]      wr_vreg_i,
  input  logic [1:0]      wr_bank_i,      // 0..3 (which 32-bit word of the 128b reg)
  input  logic [31:0]     wr_wdata_i,
  input  logic [3:0]      wr_wstrb_i,

  // Read: one 32-bit word (bank) (for stores/ALU later)
  input  logic            rd_en_i,
  input  logic [4:0]      rd_vreg_i,
  input  logic [1:0]      rd_bank_i,
  output logic [31:0]     rd_rdata_o

`ifdef VERIF_VRF_PEEK
 ,output logic [127:0]     vrf_peek_o     // optional: expose whole reg for TB
 ,input  logic [4:0]       vrf_peek_idx_i
`endif
);

  // storage: NREGS × 4 banks × 32 bits
  logic [31:0] mem [NREGS-1:0][3:0];

  // byte-write
  always_ff @(posedge clk_i) begin
    if (wr_en_i) begin
      if (wr_wstrb_i[0]) mem[wr_vreg_i][wr_bank_i][ 7: 0] <= wr_wdata_i[ 7: 0];
      if (wr_wstrb_i[1]) mem[wr_vreg_i][wr_bank_i][15: 8] <= wr_wdata_i[15: 8];
      if (wr_wstrb_i[2]) mem[wr_vreg_i][wr_bank_i][23:16] <= wr_wdata_i[23:16];
      if (wr_wstrb_i[3]) mem[wr_vreg_i][wr_bank_i][31:24] <= wr_wdata_i[31:24];
    end
  end

  // read (registered or combo; here registered for timing cleanliness)
  // always_ff @(posedge clk_i) begin
  //   if (rd_en_i) begin
  //     rd_rdata_o <= mem[rd_vreg_i][rd_bank_i];
  //   end
  // end
  // changed to combo
  always_comb begin
    if (rd_en_i) begin
      rd_rdata_o <= mem[rd_vreg_i][rd_bank_i];
    end
    else begin
      rd_rdata_o <= 32'b0;
    end 
  end

`ifdef VERIF_VRF_PEEK
  // expose whole 128b reg for TB (word3 is highest bytes)
  always_comb begin
    vrf_peek_o = {
      mem[vrf_peek_idx_i][3],
      mem[vrf_peek_idx_i][2],
      mem[vrf_peek_idx_i][1],
      mem[vrf_peek_idx_i][0]
    };
  end
`endif

initial begin
  // Initialize vector registers with distinctive test data
  #100; // Wait for reset
  
  // v1: Original test pattern
  mem[1][0] = 32'h12345678;  // Bank 0
  mem[1][1] = 32'hABCDEF00;  // Bank 1  
  mem[1][2] = 32'hDEADBEEF;  // Bank 2
  mem[1][3] = 32'hCAFEBABE;  // Bank 3
  
  // v2: Incremented pattern
  mem[2][0] = 32'h23456789;  // Bank 0
  mem[2][1] = 32'hBCDEF011;  // Bank 1
  mem[2][2] = 32'hEADBEEF0;  // Bank 2
  mem[2][3] = 32'hAFEBABEC;  // Bank 3
  
  // v3: Rotated pattern  
  mem[3][0] = 32'h3456789A;  // Bank 0
  mem[3][1] = 32'hCDEF0122;  // Bank 1
  mem[3][2] = 32'hADBEEF01;  // Bank 2
  mem[3][3] = 32'hFEBABECA;  // Bank 3
  
  // v4: Inverted pattern
  mem[4][0] = 32'hEDCBA987;  // Bank 0
  mem[4][1] = 32'h543210FF;  // Bank 1
  mem[4][2] = 32'h21524110;  // Bank 2
  mem[4][3] = 32'h35014543;  // Bank 3
  
  // v5: Alternating pattern
  mem[5][0] = 32'hAAAA5555;  // Bank 0
  mem[5][1] = 32'h5555AAAA;  // Bank 1
  mem[5][2] = 32'hAAAA5555;  // Bank 2
  mem[5][3] = 32'h5555AAAA;  // Bank 3
  
  // v31: Maximum register with special pattern
  mem[31][0] = 32'hFFFFFFFF; // Bank 0 - all ones
  mem[31][1] = 32'h00000000; // Bank 1 - all zeros
  mem[31][2] = 32'hF0F0F0F0; // Bank 2 - alternating nibbles
  mem[31][3] = 32'h0F0F0F0F; // Bank 3 - alternating nibbles
  
  $display("VRF initialized:");
  $display("  v1  = {0x%08X, 0x%08X, 0x%08X, 0x%08X}", mem[1][3], mem[1][2], mem[1][1], mem[1][0]);
  $display("  v2  = {0x%08X, 0x%08X, 0x%08X, 0x%08X}", mem[2][3], mem[2][2], mem[2][1], mem[2][0]);
  $display("  v3  = {0x%08X, 0x%08X, 0x%08X, 0x%08X}", mem[3][3], mem[3][2], mem[3][1], mem[3][0]);
  $display("  v4  = {0x%08X, 0x%08X, 0x%08X, 0x%08X}", mem[4][3], mem[4][2], mem[4][1], mem[4][0]);
  $display("  v5  = {0x%08X, 0x%08X, 0x%08X, 0x%08X}", mem[5][3], mem[5][2], mem[5][1], mem[5][0]);
  $display("  v31 = {0x%08X, 0x%08X, 0x%08X, 0x%08X}", mem[31][3], mem[31][2], mem[31][1], mem[31][0]);
end

endmodule
