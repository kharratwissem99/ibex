// Copyright 2021 ETH Zurich and University of Bologna.
// Solderpad Hardware License, Version 0.51, see LICENSE for details.
// SPDX-License-Identifier: SHL-0.51
//
// Author: Matheus Cavalcante <matheusd@iis.ee.ethz.ch>
// Description:
// Ara's SIMD ALU, operating on elements 64-bit wide, and generating 64 bits per cycle.

module vector_alu import ibex_pkg::*; (
    input  logic [32-1:0]      operand_a_i,
    input  logic [32-1:0]      operand_b_i,
    input  logic       valid_i,
    // input  logic       vm_i, // todo: not supported
    // input  strb_t      mask_i, // todo: not supported
    // input  logic       narrowing_select_i, // todo: not supported
    input  v_alu_op_e    op_i,
    input  vew_e       vew_i,
    output logic [32-1:0]      result_o
  );

  ///////////////////
  //  Definitions  //
  ///////////////////

  typedef union packed {
    logic [0:0][31:0] w32;
    logic [1:0][15:0] w16;
    logic [3:0][ 7:0] w8;
  } alu_operand_t;

  alu_operand_t opa, opb, res;
  assign opa      = operand_a_i;
  assign opb      = operand_b_i;
  assign result_o = res;

  ///////////////////
  //  Comparisons  //
  ///////////////////

  // Comparison instructions that use signed operands
  logic is_signed;
  assign is_signed = op_i inside {VMAX, VMIN};
  // assign is_signed = op_i inside {VMAX, VREDMAX, VMIN, VREDMIN, VMSLT, VMSLE, VMSGT}; // todo: VMSLT, VMSLE, VMSGT are not supported
  // Compare operands.
  // For vew_i = EW8, all bits are valid.
  // For vew_i = EW16, bits 0, 2, 4, and 6 are valid.
  // For vew_i = EW32, bits 0 and 4 are valid.
  // For vew_i = EW64, only bit 0 indicates the result of the comparison.
  logic [3:0] less;
  logic [3:0] equal;

  always_comb begin: p_comparison
    // Default assignment
    less  = '0;
    equal = '0;

    if (valid_i) begin
      unique case (vew_i)
        EW8 : for (int b = 0; b < 4; b++) less[1*b] =
            $signed({is_signed & opb.w8 [b][ 7], opb.w8 [b]}) <
            $signed({is_signed & opa.w8 [b][ 7], opa.w8 [b]});
        EW16: for (int b = 0; b < 2; b++) less[2*b] =
            $signed({is_signed & opb.w16[b][15], opb.w16[b]}) <
            $signed({is_signed & opa.w16[b][15], opa.w16[b]});
        EW32: for (int b = 0; b < 1; b++) less[4*b] =
            $signed({is_signed & opb.w32[b][31], opb.w32[b]}) <
            $signed({is_signed & opa.w32[b][31], opa.w32[b]});
        default:;
      endcase

      unique case (vew_i)
        EW8 : for (int b = 0; b < 4; b++) equal[1*b] = opa.w8 [b] == opb.w8 [b];
        EW16: for (int b = 0; b < 2; b++) equal[2*b] = opa.w16[b] == opb.w16[b];
        EW32: for (int b = 0; b < 1; b++) equal[4*b] = opa.w32[b] == opb.w32[b];
        default:;
      endcase
    end
  end : p_comparison

  ///////////
  //  ALU  //
  ///////////

  always_comb begin: p_alu
    // Default assignment
    res       = '0;

    if (valid_i)
      unique case (op_i)
        // Logical operations // todo: VREDAND, VREDOR, VREDXOR not supported
        // VAND, VREDAND: res = operand_a_i & operand_b_i;
        // VOR, VREDOR  : res = operand_a_i | operand_b_i;
        // VXOR, VREDXOR: res = operand_a_i ^ operand_b_i;
        VAND: res = operand_a_i & operand_b_i;
        VOR: res = operand_a_i | operand_b_i;
        VXOR: res = operand_a_i ^ operand_b_i;

        // Mask logical operations // todo: not supported
        // VMAND   : res = operand_a_i & operand_b_i;
        // VMANDNOT: res = ~operand_a_i & operand_b_i;
        // VMNAND  : res = ~(operand_a_i & operand_b_i);
        // VMOR    : res = operand_a_i | operand_b_i;
        // VMNOR   : res = ~(operand_a_i | operand_b_i);
        // VMORNOT : res = ~operand_a_i | operand_b_i;
        // VMXOR   : res = operand_a_i ^ operand_b_i;
        // VMXNOR  : res = ~(operand_a_i ^ operand_b_i);

        // Mask operands pass-through // todo: not supported
        // VCPOP, VFIRST, VMSBF, VMSOF, VMSIF, VIOTA: res = operand_b_i;

        // Mask operands pass-through // todo: not supported
        // VRGATHER, VRGATHEREI16, VCOMPRESS: res = operand_a_i;

        // todo: VADC, VMADC are not supported
        // VADD, VADC, VMADC, VREDSUM, VWREDSUMU, VWREDSUM: unique case (vew_i) 
        //     EW8: for (int b = 0; b < 4; b++) begin
        //         automatic logic [ 8:0] sum = opa.w8 [b] + opb.w8 [b] +
        //         logic'(op_i inside {VADC, VMADC} && mask_i[1*b] & ~vm_i);
        //         res.w8[b] = (op_i == VMADC) ? {6'b0, 1'b1, sum[8]} : sum[7:0];
        //       end
        //     EW16: for (int b = 0; b < 2; b++) begin
        //         automatic logic [16:0] sum = opa.w16[b] + opb.w16[b] +
        //         logic'(op_i inside {VADC, VMADC} && mask_i[2*b] & ~vm_i);
        //         res.w16[b] = (op_i == VMADC) ? {14'b0, 1'b1, sum[16]} : sum[15:0];
        //       end
        //     EW32: for (int b = 0; b < 1; b++) begin
        //         automatic logic [32:0] sum = opa.w32[b] + opb.w32[b] +
        //         logic'(op_i inside {VADC, VMADC} && mask_i[4*b] & ~vm_i);
        //         res.w32[b] = (op_i == VMADC) ? {30'b0, 1'b1, sum[32]} : sum[31:0];
        //       end
        //   endcase
        // VSUB, VSBC, VMSBC: unique case (vew_i) todo: VSBC, VMSBC are not supported. mask_i and vm_i are not available
        //     EW8: for (int b = 0; b < 4; b++) begin
        //         automatic logic [ 8:0] sub = opb.w8 [b] - opa.w8 [b] -
        //         logic'(op_i inside {VSBC, VMSBC} && mask_i[1*b] & ~vm_i);
        //         res.w8[b] = (op_i == VMSBC) ? {6'b0, 1'b1, sub[8]} : sub[7:0];
        //       end
        //     EW16: for (int b = 0; b < 2; b++) begin
        //         automatic logic [16:0] sub = opb.w16[b] - opa.w16[b] -
        //         logic'(op_i inside {VSBC, VMSBC} && mask_i[2*b] & ~vm_i);
        //         res.w16[b] = (op_i == VMSBC) ? {14'b0, 1'b1, sub[16]} : sub[15:0];
        //       end
        //     EW32: for (int b = 0; b < 1; b++) begin
        //         automatic logic [32:0] sub = opb.w32[b] - opa.w32[b] -
        //         logic'(op_i inside {VSBC, VMSBC} && mask_i[4*b] & ~vm_i);
        //         res.w32[b] = (op_i == VMSBC) ? {30'b0, 1'b1, sub[32]} : sub[31:0];
        //       end
        //   endcase
        // VADD, VREDSUM, VWREDSUMU, VWREDSUM: unique case (vew_i) // todo: VREDSUM, VWREDSUMU, VWREDSUM not supported
        //     EW8: for (int b = 0; b < 4; b++) begin
        //         automatic logic [ 8:0] sum = opa.w8 [b] + opb.w8 [b];
        //         res.w8[b] = sum[7:0];
        //       end
        //     EW16: for (int b = 0; b < 2; b++) begin
        //         automatic logic [16:0] sum = opa.w16[b] + opb.w16[b];
        //         res.w16[b] = sum[15:0];
        //       end
        //     EW32: for (int b = 0; b < 1; b++) begin
        //         automatic logic [32:0] sum = opa.w32[b] + opb.w32[b];
        //         res.w32[b] = sum[31:0];
        //       end
        //   endcase
          VADD: unique case (vew_i)
            EW8: for (int b = 0; b < 4; b++) begin
                automatic logic [ 8:0] sum = opa.w8 [b] + opb.w8 [b];
                res.w8[b] = sum[7:0];
              end
            EW16: for (int b = 0; b < 2; b++) begin
                automatic logic [16:0] sum = opa.w16[b] + opb.w16[b];
                res.w16[b] = sum[15:0];
              end
            EW32: for (int b = 0; b < 1; b++) begin
                automatic logic [32:0] sum = opa.w32[b] + opb.w32[b];
                res.w32[b] = sum[31:0];
              end
          endcase
        VSUB: unique case (vew_i)
            EW8: for (int b = 0; b < 4; b++) begin
                automatic logic [ 8:0] sub = opb.w8 [b] - opa.w8 [b];
                res.w8[b] = sub[7:0];
              end
            EW16: for (int b = 0; b < 2; b++) begin
                automatic logic [16:0] sub = opb.w16[b] - opa.w16[b];
                res.w16[b] = sub[15:0];
              end
            EW32: for (int b = 0; b < 1; b++) begin
                automatic logic [32:0] sub = opb.w32[b] - opa.w32[b];
                res.w32[b] = sub[31:0];
              end
          endcase
        VRSUB: unique case (vew_i)
            EW8 : for (int b = 0; b < 4; b++) res.w8 [b] = opa.w8 [b] - opb.w8 [b];
            EW16: for (int b = 0; b < 2; b++) res.w16[b] = opa.w16[b] - opb.w16[b];
            EW32: for (int b = 0; b < 1; b++) res.w32[b] = opa.w32[b] - opb.w32[b];
          endcase

        // Shift instructions
        VSLL: unique case (vew_i)
            EW8 : for (int b = 0; b < 4; b++) res.w8 [b] = opb.w8 [b] << opa.w8 [b][2:0];
            EW16: for (int b = 0; b < 2; b++) res.w16[b] = opb.w16[b] << opa.w16[b][3:0];
            EW32: for (int b = 0; b < 1; b++) res.w32[b] = opb.w32[b] << opa.w32[b][4:0];
          endcase
        VSRL: unique case (vew_i)
            EW8 : for (int b = 0; b < 4; b++) res.w8 [b] = opb.w8 [b] >> opa.w8 [b][2:0];
            EW16: for (int b = 0; b < 2; b++) res.w16[b] = opb.w16[b] >> opa.w16[b][3:0];
            EW32: for (int b = 0; b < 1; b++) res.w32[b] = opb.w32[b] >> opa.w32[b][4:0];
          endcase
        VSRA: unique case (vew_i)
            EW8 : for (int b = 0; b < 4; b++) res.w8 [b] = $signed(opb.w8 [b]) >>> opa.w8 [b][2:0];
            EW16: for (int b = 0; b < 2; b++) res.w16[b] = $signed(opb.w16[b]) >>> opa.w16[b][3:0];
            EW32: for (int b = 0; b < 1; b++) res.w32[b] = $signed(opb.w32[b]) >>> opa.w32[b][4:0];
          endcase
        // VNSRL: unique case (vew_i) // todo : not supported. narrowing_select_i signal needed to support it
        //     EW8 : for (int b = 0; b < 4; b++) res.w8 [2*b + narrowing_select_i] = opb.w16[b] >>
        //         opa.w16[b][3:0];
        //     EW16: for (int b = 0; b < 2; b++) res.w16[2*b + narrowing_select_i] = opb.w32[b] >>
        //         opa.w32[b][4:0];
        //     EW32: for (int b = 0; b < 1; b++) res.w32[2*b + narrowing_select_i] = opb.w64[b] >>
        //         opa.w64[b][5:0];
        //   endcase
        // VNSRA: unique case (vew_i)
        //     EW8 : for (int b = 0; b < 4; b++) res.w8 [2*b + narrowing_select_i] =
        //         $signed(opb.w16[b]) >>> opa.w16[b][3:0];
        //     EW16: for (int b = 0; b < 2; b++) res.w16[2*b + narrowing_select_i] =
        //         $signed(opb.w32[b]) >>> opa.w32[b][4:0];
        //     EW32: for (int b = 0; b < 1; b++) res.w32[2*b + narrowing_select_i] =
        //         $signed(opb.w64[b]) >>> opa.w64[b][5:0];
        //   endcase

        // Merge instructions // todo : not supported. mask_i signal needed to support it
        // VMERGE: unique case (vew_i)
        //     EW8 : for (int b = 0; b < 4; b++) res.w8 [b] = mask_i[1*b] ? opa.w8 [b] : opb.w8 [b];
        //     EW16: for (int b = 0; b < 2; b++) res.w16[b] = mask_i[2*b] ? opa.w16[b] : opb.w16[b];
        //     EW32: for (int b = 0; b < 1; b++) res.w32[b] = mask_i[4*b] ? opa.w32[b] : opb.w32[b];
        //   endcase

        // Scalar move
        // VMVSX, VFMVSF: res = opa; // todo: these are not vector-vector ops. VFMVSF is to a move a float. should we support it?

        // Comparison instructions todo: VREDMINU, VREDMIN, VREDMAXU, VREDMAX not supported
        // VMIN, VMINU, VMAX, VMAXU,
        // VREDMINU, VREDMIN, VREDMAXU, VREDMAX: unique case (vew_i)
        //     EW8 : for (int b = 0; b < 4; b++) res.w8 [b] =
        //         (less[1*b] ^ (op_i == VMAX || op_i == VMAXU || op_i == VREDMAXU || op_i == VREDMAX)) ? opb.w8 [b] : opa.w8 [b];
        //     EW16: for (int b = 0; b < 2; b++) res.w16[b] =
        //         (less[2*b] ^ (op_i == VMAX || op_i == VMAXU || op_i == VREDMAXU || op_i == VREDMAX)) ? opb.w16[b] : opa.w16[b];
        //     EW32: for (int b = 0; b < 1; b++) res.w32[b] =
        //         (less[4*b] ^ (op_i == VMAX || op_i == VMAXU || op_i == VREDMAXU || op_i == VREDMAX)) ? opb.w32[b] : opa.w32[b];
        //   endcase
        VMIN, VMINU, VMAX, VMAXU: unique case (vew_i)
            EW8 : for (int b = 0; b < 4; b++) res.w8 [b] =
                (less[1*b] ^ (op_i == VMAX || op_i == VMAXU)) ? opb.w8 [b] : opa.w8 [b];
            EW16: for (int b = 0; b < 2; b++) res.w16[b] =
                (less[2*b] ^ (op_i == VMAX || op_i == VMAXU)) ? opb.w16[b] : opa.w16[b];
            EW32: for (int b = 0; b < 1; b++) res.w32[b] =
                (less[4*b] ^ (op_i == VMAX || op_i == VMAXU)) ? opb.w32[b] : opa.w32[b];
          endcase
        // VMSEQ, VMSNE: unique case (vew_i) // todo: not supported. mask_i signal needed to be supported
        //     EW8 : for (int b = 0; b < 4; b++) res.w8 [b][1:0] =
        //         {mask_i[1*b], equal[1*b] ^ (op_i == VMSNE)};
        //     EW16: for (int b = 0; b < 2; b++) res.w16[b][1:0] =
        //         {mask_i[2*b], equal[2*b] ^ (op_i == VMSNE)};
        //     EW32: for (int b = 0; b < 1; b++) res.w32[b][1:0] =
        //         {mask_i[4*b], equal[4*b] ^ (op_i == VMSNE)};
        //   endcase
        // VMSLT, VMSLTU: unique case (vew_i)
        //     EW8 : for (int b = 0; b < 4; b++) res.w8 [b][1:0] = {mask_i[1*b], less[1*b]};
        //     EW16: for (int b = 0; b < 2; b++) res.w16[b][1:0] = {mask_i[2*b], less[2*b]};
        //     EW32: for (int b = 0; b < 1; b++) res.w32[b][1:0] = {mask_i[4*b], less[4*b]};
        //   endcase
        // VMSLE, VMSLEU, VMSGT, VMSGTU: unique case (vew_i)
        //     EW8 : for (int b = 0; b < 4; b++) res.w8 [b][1:0] =
        //         {mask_i[1*b], (less[1*b] || equal[1*b]) ^ (op_i inside {VMSGT, VMSGTU})};
        //     EW16: for (int b = 0; b < 2; b++) res.w16[b][1:0] =
        //         {mask_i[2*b], (less[2*b] || equal[2*b]) ^ (op_i inside {VMSGT, VMSGTU})};
        //     EW32: for (int b = 0; b < 1; b++) res.w32[b][1:0] =
        //         {mask_i[4*b], (less[4*b] || equal[4*b]) ^ (op_i inside {VMSGT, VMSGTU})};
        //   endcase

        default:;
      endcase
  end : p_alu

  //////////////////
  //  Assertions  //
  //////////////////

  // if (DataWidth != $bits(alu_operand_t))
  //   $error("[simd_valu] The SIMD vector ALU only works for a datapath 64-bit wide.");

endmodule : vector_alu
