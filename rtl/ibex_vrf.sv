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
  always_ff @(posedge clk_i) begin
    if (rd_en_i) begin
      rd_rdata_o <= mem[rd_vreg_i][rd_bank_i];
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

endmodule

// Initialization for simulation/testing
`ifdef SIMULATION
initial begin
  // Initialize vector register v1 with test data
  #100; // Wait for reset
  mem[1][0] = 32'h12345678;  // Bank 0
  mem[1][1] = 32'hABCDEF00;  // Bank 1  
  mem[1][2] = 32'hDEADBEEF;  // Bank 2
  mem[1][3] = 32'hCAFEBABE;  // Bank 3
  
  $display("VRF initialized: v1 = {0x%08X, 0x%08X, 0x%08X, 0x%08X}", 
           mem[1][3], mem[1][2], mem[1][1], mem[1][0]);
end
`endif
