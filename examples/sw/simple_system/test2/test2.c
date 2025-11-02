// Copyright lowRISC contributors.
// Licensed under the Apache License, Version 2.0, see LICENSE for details.
// SPDX-License-Identifier: Apache-2.0

#include "simple_system_common.h"
#include <riscv_vector.h>

int main(int argc, char **argv) {
  //EW32 AVL3
  int32_t avl = 3;
  size_t vl = __riscv_vsetvl_e32m1(avl);
  int32_t a[4] = {1, 2, 3, 4};
  int32_t b[4] = {10, 20, 30, 40};
  int32_t c[4] = {22, 33, 44, 55};

  int32_t expected_c32[4] = {11, 22, 33, 55};

  vint32m1_t va = __riscv_vle32_v_i32m1(a, vl);
  vint32m1_t vb = __riscv_vle32_v_i32m1(b, vl);
  vint32m1_t vc = __riscv_vadd_vv_i32m1(va, vb, vl);
  __riscv_vse32_v_i32m1(c, vc, vl);

  for (int i = 0; i < 4; i++){
    if (expected_c32[i] != c[i]){
        puts("failed ");
    }
    else{
        puts("passed ");
    }
    puts("is: ");
    puthex(c[i]);
    puts(" soll: ");
    puthex(expected_c32[i]);
    putchar('\n');
  }
  putchar('\n');

  return 0;
}
