`timescale 1ns/1ps

// If your package is in another path, adjust the include.
// `include "ibex_pkg.sv"

// Forward-declare the DUT if your simulator wants it (else remove).
// module ibex_vector_unit #(parameter int VLEN_BITS=128) (...);

// -----------------------------
// Simple testbench
// -----------------------------
module ibex_vector_unit_tb;

  // Clock / reset
  logic clk, rst_n;
  initial begin
    clk = 0;
    forever #5 clk = ~clk;          // 100 MHz
  end

  initial begin
    rst_n = 0;
    #50;
    rst_n = 1;
  end

  // Core <-> VU handshake
  logic                          v_req_valid;
  logic                          v_req_ready;
  ibex_pkg::v_req_t          v_req;
  ibex_pkg::v_resp_t         v_resp;

  // Memory bridge (stubbed)
  logic                          mem_req_valid, mem_req_ready;
  logic [31:0]                   mem_req_addr;
  logic                          mem_req_write;
  logic [31:0]                   mem_req_wdata;
  logic [3:0]                    mem_req_wstrb;
  logic                          mem_resp_valid;
  logic [31:0]                   mem_resp_rdata;
  logic                          mem_resp_err;

  // Always-accept, no-latency memory stub (enough for vsetvli testing)
  assign mem_req_ready   = 1'b1;
  assign mem_resp_valid  = 1'b0;    // vsetvli doesn't touch memory
  assign mem_resp_rdata  = '0;
  assign mem_resp_err    = 1'b0;

  // -----------------------------
  // DUT
  // -----------------------------
  ibex_vector_unit #(
    .VLEN_BITS(128)
  ) dut (
    .clk_i             (clk),
    .rst_ni            (rst_n),
    .v_req_valid_i     (v_req_valid),
    .v_req_ready_o     (v_req_ready),                 // not used here; we hold valid for 1 cycle
    .v_req_i           (v_req),
    .v_resp_o          (v_resp),

    .mem_req_valid_o   (mem_req_valid),
    .mem_req_ready_i   (mem_req_ready),
    .mem_req_addr_o    (mem_req_addr),
    .mem_req_write_o   (mem_req_write),
    .mem_req_wdata_o   (mem_req_wdata),
    .mem_req_wstrb_o   (mem_req_wstrb),
    .mem_resp_valid_i  (mem_resp_valid),
    .mem_resp_rdata_i  (mem_resp_rdata),
    .mem_resp_err_i    (mem_resp_err)
  );

  // -----------------------------
  // Helpers
  // -----------------------------

  // Build an R-type word: funct7|rs2|rs1|funct3|rd|opcode
  function automatic logic [31:0] r_insn(
    input logic [6:0]  funct7,
    input logic [4:0]  rs2,
    input logic [4:0]  rs1,
    input logic [2:0]  funct3,
    input logic [4:0]  rd,
    input logic [6:0]  opcode
  );
    r_insn = {funct7, rs2, rs1, funct3, rd, opcode};
  endfunction

  // Our **proxy vsetvli** (R-type):
  // - opcode = 0x0B (custom-0)
  // - funct7 = 0x01 (just a tag)
  // - funct3 encodes SEW: 000 => SEW=8, 001 => SEW=16
  // - rs1 carries AVL (value passed via v_req.rs1_val)
  // - rd is scalar rd that should receive VL
  function automatic logic [31:0] make_proxy_vsetvli(
    input logic [2:0] sew_f3,  // 3'b000 -> SEW=8, 3'b001 -> SEW=16
    input logic [4:0] rd
  );
    logic [6:0] opcode, funct7;
    opcode = 7'h0B;    // custom-0
    funct7 = 7'h01;    // tag
    make_proxy_vsetvli = r_insn(funct7, 5'd0 /*rs2 unused*/, 5'd0 /*rs1 encoded via value*/, sew_f3, rd, opcode);
  endfunction

  // Drive one vector request and wait for DONE; return the response
  task automatic drive_vsetvli_and_wait(
    input  logic [31:0] insn_word,
    input  logic [31:0] avl,
    input  logic [4:0]  rd_idx,
    output logic        rd_we,
    output logic [31:0] rd_wdata
  );
    // Present request for one cycle (if your DUT requires ready/valid handshake, loop until ready)
    v_req.insn    = insn_word;
    v_req.rs1_val = avl;
    v_req.rd_idx  = rd_idx;

    // If your VU exposes v_req_ready_o, poll it; here we just pulse valid for 1 cycle.
    v_req_valid   = 1'b1;
    @(posedge clk);
    v_req_valid   = 1'b0;

    // Wait for DONE
    do @(posedge clk); while (v_resp.done == 1'b0);

    rd_we    = v_resp.rd_we;
    rd_wdata = v_resp.rd_wdata;
  endtask

  // -----------------------------
  // Test sequence
  // -----------------------------
  initial begin
    // init
    logic [31:0] insn1;
    logic        rd_we1;
    logic [31:0] rd_wdata1;

    logic [31:0] insn2;
    logic        rd_we2;
    logic [31:0] rd_wdata2;

    v_req_valid     = 1'b0;
    v_req           = '0;

    // Wait for reset
    // @(negedge rst_n);
    @(posedge rst_n);
    repeat (5) @(posedge clk);

    // === Test 1: SEW=8, AVL=20 -> VL should clamp to 16
    insn1 = make_proxy_vsetvli(3'b000 /*SEW=8*/, 5'd10 /*rd=x10*/);

    drive_vsetvli_and_wait(insn1, 32'd20, 5'd10, rd_we1, rd_wdata1);

    assert (rd_we1) else $fatal(1, "Test1: rd_we not asserted");
    assert (rd_wdata1[4:0] == 5'd16)
      else $fatal(1, $sformatf("Test1: expected VL=16, got %0d", rd_wdata1[4:0]));

    $display("[TB] Test1 OK: SEW=8, AVL=20 => VL=%0d", rd_wdata1[4:0]);

    // === Test 2: SEW=16, AVL=5 -> VL should be 5 (max 8)
    insn2 = make_proxy_vsetvli(3'b001 /*SEW=16*/, 5'd11 /*rd=x11*/);

    drive_vsetvli_and_wait(insn2, 32'd5, 5'd11, rd_we2, rd_wdata2);

    assert (rd_we2) else $fatal(1, "Test2: rd_we not asserted");
    assert (rd_wdata2[4:0] == 5'd5)
      else $fatal(1, $sformatf("Test2: expected VL=5, got %0d", rd_wdata2[4:0]));

    $display("[TB] Test2 OK: SEW=16, AVL=5 => VL=%0d", rd_wdata2[4:0]);

    $display("[TB] All vsetvli proxy tests passed ✅");
    #20;
    $finish;
  end

endmodule
