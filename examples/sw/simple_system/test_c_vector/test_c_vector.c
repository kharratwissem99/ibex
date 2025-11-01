// Copyright lowRISC contributors.
// Licensed under the Apache License, Version 2.0, see LICENSE for details.
// SPDX-License-Identifier: Apache-2.0

#include "simple_system_common.h"
#include <riscv_vector.h>

int main(int argc, char **argv) {
  // be careful should be aligned access if you work with 32 bits elements
  int32_t avl = 4;
  size_t vl = __riscv_vsetvl_e32m1(avl);
  int32_t a[4] = {1, 2, 3, 4};
  int32_t b[4] = {10, 20, 30, 40};
  int32_t c[4];
  vint32m1_t va = __riscv_vle32_v_i32m1(a, vl);
  vint32m1_t vb = __riscv_vle32_v_i32m1(b, vl);
  vint32m1_t vc = __riscv_vadd_vv_i32m1(va, vb, vl);
  __riscv_vse32_v_i32m1(c, vc, vl);

  for (int i = 0; i < 4; i++)
      puthex(c[i]);
  putchar('\n');

  return 0;
}
