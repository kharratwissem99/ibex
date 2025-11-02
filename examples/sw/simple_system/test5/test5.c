// Copyright lowRISC contributors.
// Licensed under the Apache License, Version 2.0, see LICENSE for details.
// SPDX-License-Identifier: Apache-2.0

#include "simple_system_common.h"
#include <riscv_vector.h>

int main(int argc, char **argv) {
  //EW16 AVL5
  size_t vl = __riscv_vsetvl_e16m1(5);
  int16_t a[8] = {1, 2, 3, 4, 5, 6, 7, 8};
  int16_t b[8] = {10, 20, 30, 40, 50, 60, 70, 80};
  int16_t c[8] = {22, 33, 44, 55, 66, 78, 89, 100};

  int16_t expected_c16[8] = {11, 22, 33, 44, 55, 78, 89, 100};

  vint16m1_t va = __riscv_vle16_v_i16m1(a, vl);
  vint16m1_t vb = __riscv_vle16_v_i16m1(b, vl);
  vint16m1_t vc = __riscv_vadd_vv_i16m1(va, vb, vl);
  __riscv_vse16_v_i16m1(c, vc, vl);

  for (int i = 0; i < 8; i++){
    if (expected_c16[i] != c[i]){
        puts("failed ");
    }
    else{
        puts("passed ");
    }
    puts("is: ");
    puthex(c[i]);
    puts(" soll: ");
    puthex(expected_c16[i]);
    putchar('\n');
  }
  putchar('\n');

  return 0;
}
