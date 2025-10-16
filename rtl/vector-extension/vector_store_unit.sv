module vector_store_unit (
  input  logic         clk_i,
  input  logic         rst_ni,

  input  logic [31:0]  adder_result_ex_i,
  input  logic [4:0]   vl_i,               // vector length 
  input  logic [2:0]   request_type_i,     // 000=8bit, 101=16bit, 010=32bit

  output logic         addr_incr_req_o,

  input  logic         st_req,
  output logic         st_done,
  output logic         store_err_o,
  
  // interface to ibex_vrf
  output logic         rd_en_o,            // Add read enable
  output logic [1:0]   rd_bank_o,
  input  logic [31:0]  rd_rdata_i,

  // interface to memory
  output logic         data_req_o,
  output logic [31:0]  data_addr_o,
  output logic         data_we_o,
  output logic [3:0]   data_be_o,
  output logic [31:0]  data_wdata_o,

  input  logic         data_gnt_i,
  input  logic         data_rvalid_i,
  input  logic         data_err_i,

  output logic         busy_o
);

  // State machine and control signals
  typedef enum logic [1:0] {
    ST_IDLE,
    ST_WAIT_GNT,
    ST_REQ
  } st_state_e;
  
  st_state_e st_state_q, st_state_d;

  // Control signals
  logic store_err;
  logic last_req, last_valid;
  logic all_grants_done_q, all_grants_done_d;
  
  assign store_err = data_rvalid_i & data_err_i;
  assign store_err_o = store_err;
  assign busy_o = (st_state_q != ST_IDLE) || all_grants_done_q;
  // st_done only when all grants AND all valids are received
  assign st_done = all_grants_done_q && last_valid;

  // Address and data processing
  logic [31:0] data_addr;
  logic [31:0] data_addr_w_aligned;
  logic [1:0]  data_offset;
  
  assign data_addr = adder_result_ex_i;
  assign data_offset = data_addr[1:0];
  assign data_addr_w_aligned = {data_addr[31:2], 2'b00};

  // Element size calculation
  logic [1:0] EEW_BYTES;
  logic [1:0] SHIFT_FAKTOR;
  
  always_comb begin
    case (request_type_i)
      3'b000: begin // SEW=8
        EEW_BYTES = 2'd1;
        SHIFT_FAKTOR = 2'd0;
      end
      3'b101: begin // SEW=16
        EEW_BYTES = 2'd2;
        SHIFT_FAKTOR = 2'd1;
      end
      3'b010: begin // SEW=32
        EEW_BYTES = 2'd4;
        SHIFT_FAKTOR = 2'd2;
      end
      default: begin
        EEW_BYTES = 2'd1;
        SHIFT_FAKTOR = 2'd0;
      end
    endcase
  end

  // Request counting
  logic [6:0] total_bytes;
  logic [2:0] anzahl_req;
  
  assign total_bytes = data_offset + (vl_i << SHIFT_FAKTOR);
  assign anzahl_req = total_bytes[6:2] + |total_bytes[1:0]; // Ceiling division by 4

  logic [1:0] gnt_cnt_q, gnt_cnt_d;
  logic [1:0] valid_cnt_q, valid_cnt_d;
  
  assign rd_bank_o = gnt_cnt_q;
  assign rd_en_o = (st_state_q != ST_IDLE) || st_req;

  // Grant and valid counters
  always_comb begin
    gnt_cnt_d = gnt_cnt_q;
    last_req = 1'b0;
    all_grants_done_d = all_grants_done_q;
    
    if (data_gnt_i && (st_state_q != ST_IDLE)) begin
      if (gnt_cnt_q + 1 == anzahl_req) begin
        last_req = 1'b1;
        all_grants_done_d = 1'b1; // Mark that all grants are done
        gnt_cnt_d = 2'd0; // Reset for next operation
      end else begin
        gnt_cnt_d = gnt_cnt_q + 1;
      end
    end
    
    if (st_req && (st_state_q == ST_IDLE)) begin
      gnt_cnt_d = 2'd0; // Reset at start
      all_grants_done_d = 1'b0; // Reset grants done flag
    end
  end

  always_comb begin
    valid_cnt_d = valid_cnt_q;
    last_valid = 1'b0;
    
    if (data_rvalid_i && (st_state_q != ST_IDLE || all_grants_done_q)) begin
      if (valid_cnt_q + 1 == anzahl_req) begin
        last_valid = 1'b1;
        valid_cnt_d = 2'd0; // Reset for next operation
      end else begin
        valid_cnt_d = valid_cnt_q + 1;
      end
    end
    
    if (st_req && (st_state_q == ST_IDLE)) begin
      valid_cnt_d = 2'd0; // Reset at start
    end
  end

  // Mask generation for first and last transfers
  logic [3:0] first_mask, last_mask, current_mask;
  // logic [6:0] remaining_bytes;
  
  // First transfer mask (based on address alignment)
  always_comb begin
    case (data_offset)
      2'b00: first_mask = 4'b1111;
      2'b01: first_mask = 4'b1110;
      2'b10: first_mask = 4'b1100;
      2'b11: first_mask = 4'b1000;
    endcase
  end

  // Last transfer mask (based on remaining bytes)
  // assign remaining_bytes = total_bytes - (gnt_cnt_q << 2);
  // always_comb begin
  //   if (remaining_bytes >= 7'd4) begin
  //     last_mask = 4'b1111;
  //   end else begin
  //     case (remaining_bytes[1:0])
  //       2'b00: last_mask = 4'b0000; // Should not happen
  //       2'b01: last_mask = 4'b0001;
  //       2'b10: last_mask = 4'b0011;
  //       2'b11: last_mask = 4'b0111;
  //     endcase
  //   end
  // end

  // // Current mask selection
  // always_comb begin
  //   if (gnt_cnt_q == 2'd0) begin
  //     // First transfer
  //     if (last_req) begin
  //       current_mask = first_mask & last_mask;
  //     end else begin
  //       current_mask = first_mask;
  //     end
  //   end else if (last_req) begin
  //     // Last transfer (but not first)
  //     current_mask = last_mask;
  //   end else begin
  //     // Middle transfers
  //     current_mask = 4'b1111;
  //   end
  // end

  


  logic [31:0] last_rf_data_d, last_rf_data_q;
  // Data rotation for misaligned accesses
  logic [31:0] data_wdata;
  always_comb begin
    case (data_offset)
      2'b00: data_wdata = rd_rdata_i;
      2'b01: data_wdata = {rd_rdata_i[23:0], last_rf_data_q[31:24]};
      2'b10: data_wdata = {rd_rdata_i[15:0], last_rf_data_q[31:16]};
      2'b11: data_wdata = {rd_rdata_i[7:0],  last_rf_data_q[31:8]};
    endcase
  end
  // Main state machine
  always_comb begin
    st_state_d = st_state_q;
    
    // Memory interface defaults
    data_req_o = 1'b0;
    data_addr_o = '0;
    data_we_o = 1'b0;
    data_wdata_o = '0;
    data_be_o = 4'b0000;
    
    addr_incr_req_o = 1'b0;

    last_rf_data_d = last_rf_data_q;

    case (st_state_q)
      ST_IDLE: begin
        if (st_req) begin
          data_req_o = 1'b1;
          data_addr_o = data_addr_w_aligned;
          data_we_o = 1'b1;
          data_wdata_o = data_wdata;
          data_be_o = current_mask;

          last_rf_data_d = rd_rdata_i;
          
          if (data_gnt_i) begin
            if (last_req) begin
              st_state_d = ST_IDLE; // Single transfer complete
            end else begin
              st_state_d = ST_REQ;
            end
          end else begin
            st_state_d = ST_WAIT_GNT;
          end
        end
      end

      ST_WAIT_GNT: begin
        // Repeat last request until granted
        data_req_o = 1'b1;
        data_addr_o = data_addr_w_aligned;
        data_we_o = 1'b1;
        data_wdata_o = data_wdata;
        data_be_o = current_mask;
        
        if (data_gnt_i) begin
          if (last_req) begin
            st_state_d = ST_IDLE; // Return to IDLE after last grant
          end else begin
            st_state_d = ST_REQ;
          end
        end
      end

      ST_REQ: begin
        // New request for next transfer
        data_req_o = 1'b1;
        data_addr_o = data_addr_w_aligned;
        data_we_o = 1'b1;
        data_wdata_o = data_wdata;
        data_be_o = current_mask;
        // Tell ID/EX stage to prepare next address (like normal LSU)
        addr_incr_req_o = 1'b1;

        last_rf_data_d = rd_rdata_i;
        
        if (data_gnt_i) begin
          if (last_req) begin
            st_state_d = ST_IDLE;
          end else begin
            // Stay in ST_REQ for next transfer
          end
        end else begin
          st_state_d = ST_WAIT_GNT;
        end
      end
    endcase
  end

  // Sequential logic
  always_ff @(posedge clk_i or negedge rst_ni) begin
    if (!rst_ni) begin
      st_state_q <= ST_IDLE;
      gnt_cnt_q <= '0;
      valid_cnt_q <= '0;
      last_rf_data_q <= '0;
      all_grants_done_q <= 1'b0;
    end else begin
      last_rf_data_q <= '0;
      st_state_q <= st_state_d;
      gnt_cnt_q <= gnt_cnt_d;
      valid_cnt_q <= valid_cnt_d;
      all_grants_done_q <= all_grants_done_d;
      
      // Clear all_grants_done when st_done is asserted
      if (st_done) begin
        all_grants_done_q <= 1'b0;
      end
    end
  end

endmodule
