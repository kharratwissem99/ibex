// todo verifizieren durch ein paar Testfälle

module vector_load_unit (
  input  logic         clk_i,
  input  logic         rst_ni,

  input  logic [31:0]  adder_result_ex_i,
  input  logic [4:0]   vl_i,               // vector length 
  input  logic [2:0]   request_type_i,     // 000=8bit, 101=16bit, 010=32bit

  output logic         addr_incr_req_o,

  input  logic         ld_req,
  output logic         ld_done,
  output logic         load_err_o,

  output logic [31:0]  addr_last_o,

  output logic         ld_resp_valid_o,     // LSU has response from transaction -> to ID/EX // this is important for stalling the memory

  output  logic            wr_en_o,
  output  logic [127:0]    wr_wdata_o,

  // Interface to memory
  output logic         data_req_o,
  output logic [31:0]  data_addr_o,
  output logic         data_we_o,
  output logic [3:0]   data_be_o, // we will not use this anymore
  output logic [31:0]  data_wdata_o, // we will not use this anymore

  input  logic         data_gnt_i,
  input  logic         data_rvalid_i,
  input  logic         data_err_i,

  input  logic [31:0] data_rdata_i, // todo drive this in also

     // this signals will be later used
//   input  logic         data_bus_err_i,
//   input  logic         data_pmp_err_i,

  output logic         busy_o
);

  //======checked section==========
  // State machine and control signals
  typedef enum logic [1:0] {
    LD_IDLE,
    LD_WAIT_GNT,
    LD_REQ
  } st_state_e;
  
  st_state_e st_state_q, st_state_d;

  logic [127:0] result_d, result_q; 

  // Address and data processing
  logic [31:0] data_addr;
  logic [31:0] data_addr_w_aligned;
  logic [1:0]  data_offset;
  // logic         addr_update;
  
  assign data_addr = adder_result_ex_i;
  assign data_offset = data_addr[1:0];
  assign data_addr_w_aligned = {data_addr[31:2], 2'b00};

  // Element size calculation
  logic [2:0] EEW_BYTES;
  logic [1:0] SHIFT_FAKTOR;
  
  always_comb begin
    case (request_type_i)
      3'b000: begin // SEW=8
        EEW_BYTES = 3'd1;
        SHIFT_FAKTOR = 2'd0;
      end
      3'b101: begin // SEW=16
        EEW_BYTES = 3'd2;
        SHIFT_FAKTOR = 2'd1;
      end
      3'b010: begin // SEW=32
        EEW_BYTES = 3'd4;
        SHIFT_FAKTOR = 2'd2;
      end
      default: begin
        EEW_BYTES = 3'd1;
        SHIFT_FAKTOR = 2'd0;
      end
    endcase
  end

  // Request counting
  logic [6:0] total_bytes;
  logic [6:0] total_bytes_without_offset;
  logic [2:0] anzahl_req;
  
  assign total_bytes_without_offset = (vl_i << SHIFT_FAKTOR);
  assign total_bytes = data_offset + total_bytes_without_offset;
  assign anzahl_req = total_bytes[6:2] + |total_bytes[1:0]; // Ceiling division by 4

  logic [31:0]  addr_last_q, addr_last_d;

  // output to ID stage: mtval + AGU for misaligned transactions
  assign addr_last_o   = addr_last_q;

  // TODO: later
  // Store last address for mtval + AGU for misaligned transactions.  Do not update in case of
  // errors, mtval needs the (first) failing address.  Where an aligned access or the first half of
  // a misaligned access sees an error provide the calculated access address. For the second half of
  // a misaligned access provide the word aligned address of the second half.
  // assign addr_last_d = addr_incr_req_o ? data_addr_w_aligned : data_addr;

  // always_ff @(posedge clk_i or negedge rst_ni) begin
  //   if (!rst_ni) begin
  //     addr_last_q <= '0;
  //   end else if (addr_update) begin
  //     addr_last_q <= addr_last_d;
  //   end
  // end

  always_ff @(posedge clk_i or negedge rst_ni) begin
    if (!rst_ni) begin
      addr_last_q <= '0;
    end else begin
      addr_last_q <= addr_last_d;
    end
  end

  //============end checked section==============
  // Mask generation for first and last transfers
  logic [3:0] first_mask, last_mask;
  
  // First transfer mask (based on address alignment)
  // always_comb begin
  //   case (data_offset)
  //     2'b00: first_mask = 4'b1111;
  //     2'b01: first_mask = 4'b1110;
  //     2'b10: first_mask = 4'b1100;
  //     2'b11: first_mask = 4'b1000;
  //   endcase
  // end

  always_comb begin
    unique case (total_bytes[1:0])
      2'b00:   last_mask =  4'b1111;
      2'b01:   last_mask =  4'b0001;
      2'b10:   last_mask =  4'b0011;
      2'b11:   last_mask =  4'b0111;
      default: last_mask =  4'b1111;
    endcase // case (n[1:0])
  end

  // Control signals
  logic store_err;
  logic last_req, last_valid;
  logic [3:0] last_mask_q, last_mask_d;

  logic st_error_q, st_error_d;
  
  assign store_err = st_error_q;
  assign load_err_o = store_err;
  assign busy_o = (st_state_q != LD_IDLE);

  // (lsu_req_i | (ls_fsm_cs != IDLE)) & (ls_fsm_ns == IDLE);
  assign ld_done =  last_req; // give back done when the last request is accepted todo:(or issued??)

  logic [2:0] gnt_cnt_q, gnt_cnt_d;
  logic [2:0] valid_cnt_q, valid_cnt_d;

  assign ld_resp_valid_o   = (data_rvalid_i) & (last_valid);

  // Grant and valid counters
  always_comb begin
    gnt_cnt_d = gnt_cnt_q;
    last_req = 1'b0;
    
    if (data_gnt_i && ((st_state_q != LD_IDLE) || ld_req)) begin // todo: blockieren, dass data_gnt incrementiert wird, es soll nicht incrementiert werden, wenn die vector store unit unactiv ist
      if (gnt_cnt_q + 1 == anzahl_req) begin
        last_req = 1'b1;
        gnt_cnt_d = 2'd0; // Reset for next operation
      end else begin
        gnt_cnt_d = gnt_cnt_q + 1;
      end
    end
    
    // todo: Es ist vielleicht nutzlos. Nur wenn wir einen Abbruch machen, können wir das brauchen.
    //if (ld_req && (st_state_q == LD_IDLE)) begin
    //  gnt_cnt_d = 2'd0; // Reset at start
    //end
  end

    logic [127 + 32:0] assembled_data;
    always_comb begin
        // Default assignments to prevent latches
        valid_cnt_d = valid_cnt_q;
        last_valid = 1'b0;
        st_error_d = st_error_q;
        result_d = result_q;
        wr_en_o = 1'b0;
        wr_wdata_o = '0;
        
        if (data_rvalid_i & (~ld_req)) begin
        if (data_err_i) st_error_d = 1'b1;
        if (valid_cnt_q + 1 == anzahl_req) begin //last valid signal
            last_valid = 1'b1;
            valid_cnt_d = 2'd0; // Reset for next operation
            wr_en_o = 1'b1;
            result_d = '0;
            
            // OLD CODE - kept for reference:
            // if (anzahl_req == 1) wr_wdata_o = {95'b0, data_rdata_i} >> (data_offset * 8);
            // else if (anzahl_req == 2) wr_wdata_o = {95'b0, data_rdata_i, } >> (data_offset * 8);
            // result_d = {data_rdata_i, result_q[127:32]};
            // Special case logic:
            // if (anzahl_req == 5) begin 
            //     big_data = {data_rdata_i & last_mask, result_q};
            //     big_data = big_data >> (data_offset * 8);
            //     wr_wdata_o = big_data[127:0];
            // end
            // else wr_wdata_o = {data_rdata_i & last_mask, result_q[127:32]} >> (32 * (4 - anzahl_req) + data_offset * 8);
            // Build full assembled data from all memory responses
            assembled_data = {data_rdata_i & last_mask, result_q};
            
            if (anzahl_req >= 4) begin
                // For 4+ requests: just shift by alignment offset
                // wr_wdata_o = (assembled_data >> (data_offset * 8))[127:0];
                wr_wdata_o = (assembled_data >> (data_offset * 8));
            end else begin
                // For <4 requests: shift by alignment + position adjustment
                // wr_wdata_o = (assembled_data >> (data_offset * 8 + 32 * (4 - anzahl_req)))[127:0];
                wr_wdata_o = (assembled_data >> (data_offset * 8 + 32 * (4 - anzahl_req)));
            end

        end else begin
            valid_cnt_d = valid_cnt_q + 1;
            result_d = {data_rdata_i, result_q[127:32]};
        end
        end
        
        if (ld_req && (st_state_q == LD_IDLE)) begin
        valid_cnt_d = 2'd0; // Reset at start
        st_error_d = 1'b0; // Reset error flag
        end
    end

  // logic [31:0] last_rf_data_d, last_rf_data_q;
  // Data rotation for misaligned accesses
  // logic [31:0] data_wdata;
  // // todo rd_data_i not needed foe load only for store
  // always_comb begin
  //   case (data_offset)
  //     2'b00: data_wdata = rd_rdata_i;
  //     2'b01: data_wdata = {last_rf_data_q[7:0],rd_rdata_i[31:8]};
  //     2'b10: data_wdata = {rd_rdata_i[15:0], last_rf_data_q[31:16]};
  //     2'b11: data_wdata = {rd_rdata_i[7:0],  last_rf_data_q[31:8]};
  //   endcase
  // end
  // Main state machine
  always_comb begin
    st_state_d = st_state_q;

    // Memory interface defaults
    data_req_o = 1'b0;
    data_addr_o = '0;
    data_we_o = 1'b0; // always 0
    addr_incr_req_o = 1'b0;
    addr_last_d = addr_last_q;

    // last_rf_data_d = last_rf_data_q;
    // last_mask_d = last_mask_q;
    case (st_state_q)
      LD_IDLE: begin
        if (ld_req) begin
          data_req_o = 1'b1;
          data_addr_o = data_addr_w_aligned;
          data_we_o = 1'b0;
          
          if (data_gnt_i) begin
            if (last_req) begin
              st_state_d = LD_IDLE; // Single transfer complete
            end else begin
              addr_last_d = data_addr;
              st_state_d = LD_REQ;
            end
          end else begin
            st_state_d = LD_WAIT_GNT;
          end
        end
      end

      LD_WAIT_GNT: begin
        // Repeat last request until granted
        data_req_o = 1'b1;
        data_addr_o = data_addr_w_aligned;
        
        if (data_gnt_i) begin
          if (last_req) begin
            st_state_d = LD_IDLE; // Return to IDLE after last grant
          end else begin
            addr_last_d = data_addr;
            st_state_d = LD_REQ;
          end
        end
      end

      LD_REQ: begin
        // New request for next transfer
        data_req_o = 1'b1;
        data_addr_o = data_addr_w_aligned;
        // Tell ID/EX stage to prepare next address (like normal LSU)
        addr_incr_req_o = 1'b1;
        
        if (data_gnt_i) begin
          if (last_req) begin
            st_state_d = LD_IDLE;
          end else begin
            // Stay in LD_REQ for next transfer
            addr_last_d = data_addr;
          end
        end else begin
          st_state_d = LD_WAIT_GNT;
        end
      end
    endcase
  end

  // Sequential logic
  always_ff @(posedge clk_i or negedge rst_ni) begin
    if (!rst_ni) begin
      st_error_q <= '0;
      st_state_q <= LD_IDLE;
      gnt_cnt_q <= '0;
      valid_cnt_q <= '0;
      result_q <= '0;
      // last_rf_data_q <= '0;
      // last_mask_q <= '0;
    end else begin
      st_error_q <= st_error_d;
      // last_rf_data_q <= last_rf_data_d;
      st_state_q <= st_state_d;
      gnt_cnt_q <= gnt_cnt_d;
      valid_cnt_q <= valid_cnt_d;
      result_q <= result_d;
      // last_mask_q <= last_mask_d;
    end
  end

endmodule
