// Vector Execution Unit
// Instantiates the Vector ALU and manages vector arithmetic operations

module vector_ex_unit import ibex_pkg::*; #(
  parameter int unsigned VLEN = 128
) (
  input  logic         clk_i,
  input  logic         rst_ni,

  // Vector operation request interface
  input  logic         ex_req_i,           // Vector ALU operation request
  input  v_alu_op_e    op_i,              // ALU operation
  input  vew_e         vew_i,             // Element width

  input  logic [31:0]  v_vl_i,

  output logic         v_done_o,
  output logic         v_err_o,

  // Vector register file interface
  input  logic [VLEN-1:0] vrf_rdata1_i,
  input  logic [VLEN-1:0] vrf_rdata2_i,
  
  // Vector register file interface
  output logic            vrf_we_o,
  output logic [VLEN-1:0] vrf_wdata_o,

  output logic resp_valid_o, // This is a very important Signal, without it we can't stall the core. It can be st_resp_valid or ld_resp_valid

  // Status signals
  output logic         busy_o
);

  typedef enum logic {
    EX_IDLE,
    EX_REQ
  } ex_state_e;

  ex_state_e ex_state_q, ex_state_d;

  logic [VLEN-1:0] vrf_rdata1_q, vrf_rdata1_d;
  logic [VLEN-1:0] vrf_rdata2_q, vrf_rdata2_d;
  logic [VLEN-1:0] result_q, result_d;

  // Internal signals
  logic [31:0] alu_result;
  logic [31:0] operand_a;
  logic [31:0] operand_b;
  logic        valid;

  logic [6:0] total_bytes;
  logic [2:0] anzahl_req;

  logic last_req;

  // Element size calculation
  logic [1:0] SHIFT_FAKTOR;

  logic [2:0] requests_counter_q,requests_counter_d; // todo: how many bits we need?
  
  always_comb begin
    case (vew_i)
      EW8: begin // SEW=8
        SHIFT_FAKTOR = 2'd0;
      end
      EW16: begin // SEW=16
        SHIFT_FAKTOR = 2'd1;
      end
      EW32: begin // SEW=32
        SHIFT_FAKTOR = 2'd2;
      end
      default: begin
        SHIFT_FAKTOR = 2'd0;
      end
    endcase
  end
  
  assign total_bytes = (v_vl_i << SHIFT_FAKTOR);
  assign anzahl_req = total_bytes[6:2] + |total_bytes[1:0]; // Ceiling division by 4

  //=============================================================================
  // Vector ALU Instance
  //=============================================================================
  
  vector_alu u_vector_alu (
    .operand_a_i  (operand_a),
    .operand_b_i  (operand_b),
    .valid_i      (valid),
    .op_i         (op_i),
    .vew_i        (vew_i),
    .result_o     (alu_result)
  );

  // Register the output for timing
  always_ff @(posedge clk_i or negedge rst_ni) begin
    if (!rst_ni) begin
        vrf_rdata1_q <= '0;
        vrf_rdata2_q <= '0;
        requests_counter_q <= '0;
        result_q <= '0;
        ex_state_q <= EX_IDLE;
    end else begin
        vrf_rdata1_q <= vrf_rdata1_d;
        vrf_rdata2_q <= vrf_rdata2_d;
        requests_counter_q <= requests_counter_d;
        result_q <= result_d;
        ex_state_q <= ex_state_d;
    end
  end

  // Grant and valid counters
  always_comb begin
    requests_counter_d = requests_counter_q;
    last_req = 1'b0;
    resp_valid_o = 1'b0;
    
    if ((ex_state_q != EX_IDLE) || ex_req_i) begin
      if (requests_counter_q + 1 == anzahl_req) begin
        last_req = 1'b1;
        resp_valid_o = 1'b1;
        requests_counter_d = 2'd0; // Reset for next operation
      end else begin
        requests_counter_d = requests_counter_q + 1;
      end
    end
    
    // todo: Es ist vielleicht nutzlos. Nur wenn wir einen Abbruch(external Signal) machen, können wir das brauchen.
    //if (st_req && (ex_state_q == EX_IDLE)) begin
    //  requests_counter_d = 2'd0; // Reset at start
    //end
  end

  // todo: complete
  assign v_done_o = 1'b0; // todo: should we use this signal, maybe it is only relevant for pipelining? In the ex Unit is the same as resp_valid 
  assign v_err_o = 1'b0; // todo: should we implement an error?

  assign busy_o = (ex_state_q != EX_IDLE);

  // Main state machine
  always_comb begin
    ex_state_d = ex_state_q;

    operand_a    = '0;
    operand_b    = '0;
    valid        = 1'b0;
    vrf_rdata1_d = vrf_rdata1_q;
    vrf_rdata2_d = vrf_rdata2_q;

    result_d = result_q;
    vrf_we_o = 1'b0;
    vrf_wdata_o = '0;

    case (ex_state_q)
      EX_IDLE: begin
        if (ex_req_i) begin
            operand_a    = vrf_rdata1_i[31:0];
            operand_b    = vrf_rdata2_i[31:0];
            valid        = 1'b1;
            vrf_rdata1_d = vrf_rdata1_i >> 32;
            vrf_rdata2_d = vrf_rdata2_i >> 32;
            if (last_req) begin
              ex_state_d = EX_IDLE;
              // write the result in the vector register file
              vrf_we_o = 1'b1;
              vrf_wdata_o = {96'b0,alu_result};
            end else begin
              ex_state_d = EX_REQ;
              result_d = {alu_result, result_q[127:32]};
            end
        end
      end
      EX_REQ: begin
        operand_a    = vrf_rdata1_q[31:0];
        operand_b    = vrf_rdata2_q[31:0];
        valid        = 1'b1;
        vrf_rdata1_d = vrf_rdata1_q >> 32;
        vrf_rdata2_d = vrf_rdata2_q >> 32;
        valid        = 1'b1;
        result_d = {alu_result, result_q[127:32]};
        if (last_req) begin
            ex_state_d = EX_IDLE;
            // todo: write the result in the vector register file
            vrf_we_o = 1'b1;
            vrf_wdata_o = {alu_result, result_q[127:32]} >> (32 * (4 - anzahl_req));
        end
        else result_d = {alu_result, result_q[127:32]};
      end
    endcase
  end

//   //=============================================================================
//   // Assertions
//   //=============================================================================
  
//   `ifdef SIMULATION
//     // Check that operation completes
//     assert property (@(posedge clk_i) disable iff (!rst_ni)
//                      v_req_i |=> valid_o)
//       else $error("Vector ALU operation did not complete");
//   `endif

endmodule
