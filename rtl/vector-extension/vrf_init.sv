// Vector Register File Initialization
// Add this block to your existing simple system testbench

initial begin
  // Wait for reset to be released
  wait(rst_ni);
  #100; // Wait a bit for system to stabilize
  
  $display("=== Initializing Vector Register File ===");
  
  // Initialize vector register v1 with test data
  // Assuming your VRF instance path - adjust as needed
  // Replace "dut.u_ibex_top.u_vector_unit.u_vrf" with your actual path
  
  // Bank 0: 0x12345678
  dut.u_ibex_top.u_vector_unit.u_vrf.mem[1][0] = 32'h12345678;
  
  // Bank 1: 0xABCDEF00  
  dut.u_ibex_top.u_vector_unit.u_vrf.mem[1][1] = 32'hABCDEF00;
  
  // Bank 2: 0xDEADBEEF
  dut.u_ibex_top.u_vector_unit.u_vrf.mem[1][2] = 32'hDEADBEEF;
  
  // Bank 3: 0xCAFEBABE
  dut.u_ibex_top.u_vector_unit.u_vrf.mem[1][3] = 32'hCAFEBABE;
  
  $display("Vector register v1 initialized:");
  $display("  v1[bank0] = 0x%08X", dut.u_ibex_top.u_vector_unit.u_vrf.mem[1][0]);
  $display("  v1[bank1] = 0x%08X", dut.u_ibex_top.u_vector_unit.u_vrf.mem[1][1]); 
  $display("  v1[bank2] = 0x%08X", dut.u_ibex_top.u_vector_unit.u_vrf.mem[1][2]);
  $display("  v1[bank3] = 0x%08X", dut.u_ibex_top.u_vector_unit.u_vrf.mem[1][3]);
  
  // Optional: Initialize other vector registers if needed
  // v2 with different pattern
  dut.u_ibex_top.u_vector_unit.u_vrf.mem[2][0] = 32'hAAAAAAAA;
  dut.u_ibex_top.u_vector_unit.u_vrf.mem[2][1] = 32'hBBBBBBBB;
  dut.u_ibex_top.u_vector_unit.u_vrf.mem[2][2] = 32'hCCCCCCCC;
  dut.u_ibex_top.u_vector_unit.u_vrf.mem[2][3] = 32'hDDDDDDDD;
  
  $display("Vector register v2 initialized with pattern 0xAAAA/BBBB/CCCC/DDDD");
  
  $display("=== VRF Initialization Complete ===");
end