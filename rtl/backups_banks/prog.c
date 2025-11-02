// Copyright lowRISC contributors.
// Licensed under the Apache License, Version 2.0, see LICENSE for details.
// SPDX-License-Identifier: Apache-2.0

#include "simple_system_common.h"
#include <riscv_vector.h>

int main(int argc, char **argv) {
  
  // ============================================================================
  // EW32 Tests
  // ============================================================================
  puts("=== EW32 Tests ===\n");
  int32_t avl32 = 4;
  size_t vl32 = __riscv_vsetvl_e32m1(avl32);
  
  // Test 1: Vector Addition EW32
  puts("Test 1: VADD EW32\n");
  int32_t a32[4] = {1, 2, 3, 4};
  int32_t b32[4] = {10, 20, 30, 40};
  int32_t c32[4];
//   int32_t expected_c32[4] = {11, 22, 33, 44};
  vint32m1_t va32 = __riscv_vle32_v_i32m1(a32, vl32);
  vint32m1_t vb32 = __riscv_vle32_v_i32m1(b32, vl32);
  vint32m1_t vc32 = __riscv_vadd_vv_i32m1(va32, vb32, vl32);
  __riscv_vse32_v_i32m1(c32, vc32, vl32);
//   int pass = 1;
  for (int i = 0; i < 4; i++) {
      puthex(c32[i]);
      putchar('\n');
    //   if (c32[i] != expected_c32[i]) pass = 0;
  }
//   puts(pass ? " PASS\n" : " FAIL\n");

  // Test 2: Vector Subtraction EW32
//   puts("Test 2: VSUB EW32\n");
//   int32_t d32[4];
//   int32_t expected_d32[4] = {9, 18, 27, 36};
//   vint32m1_t vd32 = __riscv_vsub_vv_i32m1(vb32, va32, vl32);
//   __riscv_vse32_v_i32m1(d32, vd32, vl32);
//   pass = 1;
//   for (int i = 0; i < 4; i++) {
//       puthex(d32[i]);
//       if (d32[i] != expected_d32[i]) pass = 0;
//   }
//   puts(pass ? " PASS\n" : " FAIL\n");

//   // Test 3: Vector AND EW32
//   puts("Test 3: VAND EW32\n");
//   int32_t e32[4] = {0xFF, 0xFF00, 0xFF0000, 0xFF000000};
//   int32_t f32[4] = {0xF0, 0xF000, 0xF00000, 0xF0000000};
//   int32_t g32[4];
//   int32_t expected_g32[4] = {0xF0, 0xF000, 0xF00000, 0xF0000000};
//   vint32m1_t ve32 = __riscv_vle32_v_i32m1(e32, vl32);
//   vint32m1_t vf32 = __riscv_vle32_v_i32m1(f32, vl32);
//   vint32m1_t vg32 = __riscv_vand_vv_i32m1(ve32, vf32, vl32);
//   __riscv_vse32_v_i32m1(g32, vg32, vl32);
//   pass = 1;
//   for (int i = 0; i < 4; i++) {
//       puthex(g32[i]);
//       if (g32[i] != expected_g32[i]) pass = 0;
//   }
//   puts(pass ? " PASS\n" : " FAIL\n");

//   // ============================================================================
//   // EW16 Tests
//   // ============================================================================
//   puts("=== EW16 Tests ===\n");
//   int16_t avl16 = 8;
//   size_t vl16 = __riscv_vsetvl_e16m1(avl16);
  
//   // Test 4: Vector Addition EW16
//   puts("Test 4: VADD EW16\n");
//   int16_t a16[8] = {1, 2, 3, 4, 5, 6, 7, 8};
//   int16_t b16[8] = {10, 20, 30, 40, 50, 60, 70, 80};
//   int16_t c16[8];
//   int16_t expected_c16[8] = {11, 22, 33, 44, 55, 66, 77, 88};
//   vint16m1_t va16 = __riscv_vle16_v_i16m1(a16, vl16);
//   vint16m1_t vb16 = __riscv_vle16_v_i16m1(b16, vl16);
//   vint16m1_t vc16 = __riscv_vadd_vv_i16m1(va16, vb16, vl16);
//   __riscv_vse16_v_i16m1(c16, vc16, vl16);
//   pass = 1;
//   for (int i = 0; i < 8; i++) {
//       puthex(c16[i]);
//       if (c16[i] != expected_c16[i]) pass = 0;
//   }
//   puts(pass ? " PASS\n" : " FAIL\n");

//   // Test 5: Vector OR EW16
//   puts("Test 5: VOR EW16\n");
//   int16_t d16[8] = {0x00FF, 0x0F00, 0x00FF, 0x0F00, 0x00FF, 0x0F00, 0x00FF, 0x0F00};
//   int16_t e16[8] = {0x00F0, 0x000F, 0x00F0, 0x000F, 0x00F0, 0x000F, 0x00F0, 0x000F};
//   int16_t f16[8];
//   int16_t expected_f16[8] = {0x00FF, 0x0F0F, 0x00FF, 0x0F0F, 0x00FF, 0x0F0F, 0x00FF, 0x0F0F};
//   vint16m1_t vd16 = __riscv_vle16_v_i16m1(d16, vl16);
//   vint16m1_t ve16 = __riscv_vle16_v_i16m1(e16, vl16);
//   vint16m1_t vf16 = __riscv_vor_vv_i16m1(vd16, ve16, vl16);
//   __riscv_vse16_v_i16m1(f16, vf16, vl16);
//   pass = 1;
//   for (int i = 0; i < 8; i++) {
//       puthex(f16[i]);
//       if (f16[i] != expected_f16[i]) pass = 0;
//   }
//   puts(pass ? " PASS\n" : " FAIL\n");

//   // ============================================================================
//   // EW8 Tests
//   // ============================================================================
//   puts("=== EW8 Tests ===\n");
//   int8_t avl8 = 16;
//   size_t vl8 = __riscv_vsetvl_e8m1(avl8);
  
//   // Test 6: Vector Addition EW8
//   puts("Test 6: VADD EW8\n");
//   int8_t a8[16] = {1, 2, 3, 4, 5, 6, 7, 8, 9, 10, 11, 12, 13, 14, 15, 16};
//   int8_t b8[16] = {10, 20, 30, 40, 50, 60, 70, 80, 90, 100, 110, 120, 127, 127, 127, 127};
//   int8_t c8[16];
//   int8_t expected_c8[16] = {11, 22, 33, 44, 55, 66, 77, 88, 99, 110, 121, -124, -116, -115, -114, -113};
//   vint8m1_t va8 = __riscv_vle8_v_i8m1(a8, vl8);
//   vint8m1_t vb8 = __riscv_vle8_v_i8m1(b8, vl8);
//   vint8m1_t vc8 = __riscv_vadd_vv_i8m1(va8, vb8, vl8);
//   __riscv_vse8_v_i8m1(c8, vc8, vl8);
//   pass = 1;
//   for (int i = 0; i < 16; i++) {
//       puthex(c8[i]);
//       if (c8[i] != expected_c8[i]) pass = 0;
//   }
//   puts(pass ? " PASS\n" : " FAIL\n");

//   // Test 7: Vector XOR EW8
//   puts("Test 7: VXOR EW8\n");
//   int8_t d8[16] = {0xFF, 0xAA, 0x55, 0x0F, 0xFF, 0xAA, 0x55, 0x0F, 0xFF, 0xAA, 0x55, 0x0F, 0xFF, 0xAA, 0x55, 0x0F};
//   int8_t e8[16] = {0x0F, 0x55, 0xAA, 0xFF, 0x0F, 0x55, 0xAA, 0xFF, 0x0F, 0x55, 0xAA, 0xFF, 0x0F, 0x55, 0xAA, 0xFF};
//   int8_t f8[16];
//   int8_t expected_f8[16] = {0xF0, 0xFF, 0xFF, 0xF0, 0xF0, 0xFF, 0xFF, 0xF0, 0xF0, 0xFF, 0xFF, 0xF0, 0xF0, 0xFF, 0xFF, 0xF0};
//   vint8m1_t vd8 = __riscv_vle8_v_i8m1(d8, vl8);
//   vint8m1_t ve8 = __riscv_vle8_v_i8m1(e8, vl8);
//   vint8m1_t vf8 = __riscv_vxor_vv_i8m1(vd8, ve8, vl8);
//   __riscv_vse8_v_i8m1(f8, vf8, vl8);
//   pass = 1;
//   for (int i = 0; i < 16; i++) {
//       puthex(f8[i]);
//       if (f8[i] != expected_f8[i]) pass = 0;
//   }
//   puts(pass ? " PASS\n" : " FAIL\n");

//   // ============================================================================
//   // Partial Vector Length Tests
//   // ============================================================================
//   puts("=== Partial VL Tests ===\n");
  
//   // Test 8: EW32 with vl=2 (only use 2 elements)
//   puts("Test 8: VADD EW32, vl=2\n");
//   size_t vl32_2 = __riscv_vsetvl_e32m1(2);
//   int32_t a32_2[4] = {100, 200, 999, 999};  // Last 2 elements should not be touched
//   int32_t b32_2[4] = {1, 2, 999, 999};
//   int32_t c32_2[4] = {0, 0, 0, 0};
//   int32_t expected_c32_2[4] = {101, 202, 0, 0};
//   vint32m1_t va32_2 = __riscv_vle32_v_i32m1(a32_2, vl32_2);
//   vint32m1_t vb32_2 = __riscv_vle32_v_i32m1(b32_2, vl32_2);
//   vint32m1_t vc32_2 = __riscv_vadd_vv_i32m1(va32_2, vb32_2, vl32_2);
//   __riscv_vse32_v_i32m1(c32_2, vc32_2, vl32_2);
//   pass = 1;
//   for (int i = 0; i < 4; i++) {
//       puthex(c32_2[i]);
//       if (c32_2[i] != expected_c32_2[i]) pass = 0;
//   }
//   puts(pass ? " PASS\n" : " FAIL\n");

//   // Test 9: EW16 with vl=4 (only use 4 out of 8 elements)
//   puts("Test 9: VSUB EW16, vl=4\n");
//   size_t vl16_4 = __riscv_vsetvl_e16m1(4);
//   int16_t a16_4[8] = {50, 60, 70, 80, 999, 999, 999, 999};
//   int16_t b16_4[8] = {5, 6, 7, 8, 999, 999, 999, 999};
//   int16_t c16_4[8] = {0, 0, 0, 0, 0, 0, 0, 0};
//   int16_t expected_c16_4[8] = {45, 54, 63, 72, 0, 0, 0, 0};
//   vint16m1_t va16_4 = __riscv_vle16_v_i16m1(a16_4, vl16_4);
//   vint16m1_t vb16_4 = __riscv_vle16_v_i16m1(b16_4, vl16_4);
//   vint16m1_t vc16_4 = __riscv_vsub_vv_i16m1(va16_4, vb16_4, vl16_4);
//   __riscv_vse16_v_i16m1(c16_4, vc16_4, vl16_4);
//   pass = 1;
//   for (int i = 0; i < 8; i++) {
//       puthex(c16_4[i]);
//       if (c16_4[i] != expected_c16_4[i]) pass = 0;
//   }
//   puts(pass ? " PASS\n" : " FAIL\n");

//   // Test 10: EW8 with vl=8 (only use 8 out of 16 elements)
//   puts("Test 10: VAND EW8, vl=8\n");
//   size_t vl8_8 = __riscv_vsetvl_e8m1(8);
//   int8_t a8_8[16] = {0xFF, 0xFF, 0xFF, 0xFF, 0xFF, 0xFF, 0xFF, 0xFF, 
//                      0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00};
//   int8_t b8_8[16] = {0x0F, 0xF0, 0x0F, 0xF0, 0x0F, 0xF0, 0x0F, 0xF0,
//                      0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00};
//   int8_t c8_8[16] = {0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0};
//   int8_t expected_c8_8[16] = {0x0F, 0xF0, 0x0F, 0xF0, 0x0F, 0xF0, 0x0F, 0xF0, 0, 0, 0, 0, 0, 0, 0, 0};
//   vint8m1_t va8_8 = __riscv_vle8_v_i8m1(a8_8, vl8_8);
//   vint8m1_t vb8_8 = __riscv_vle8_v_i8m1(b8_8, vl8_8);
//   vint8m1_t vc8_8 = __riscv_vand_vv_i8m1(va8_8, vb8_8, vl8_8);
//   __riscv_vse8_v_i8m1(c8_8, vc8_8, vl8_8);
//   pass = 1;
//   for (int i = 0; i < 16; i++) {
//       puthex(c8_8[i]);
//       if (c8_8[i] != expected_c8_8[i]) pass = 0;
//   }
//   puts(pass ? " PASS\n" : " FAIL\n");

//   // Test 11: EW32 with vl=1 (only use 1 element)
//   puts("Test 11: VOR EW32, vl=1\n");
//   size_t vl32_1 = __riscv_vsetvl_e32m1(1);
//   int32_t a32_1[4] = {0xAAAA, 0xDEAD, 0xBEEF, 0xCAFE};
//   int32_t b32_1[4] = {0x5555, 0xDEAD, 0xBEEF, 0xCAFE};
//   int32_t c32_1[4] = {0, 0, 0, 0};
//   int32_t expected_c32_1[4] = {0xFFFF, 0, 0, 0};
//   vint32m1_t va32_1 = __riscv_vle32_v_i32m1(a32_1, vl32_1);
//   vint32m1_t vb32_1 = __riscv_vle32_v_i32m1(b32_1, vl32_1);
//   vint32m1_t vc32_1 = __riscv_vor_vv_i32m1(va32_1, vb32_1, vl32_1);
//   __riscv_vse32_v_i32m1(c32_1, vc32_1, vl32_1);
//   pass = 1;
//   for (int i = 0; i < 4; i++) {
//       puthex(c32_1[i]);
//       if (c32_1[i] != expected_c32_1[i]) pass = 0;
//   }
//   puts(pass ? " PASS\n" : " FAIL\n");

  puts("All tests done!\n");
  return 0;
}
