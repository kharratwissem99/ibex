.option norvc            # keep it plain RV32I (no compressed)
.text
.globl main
.type  main, @function

main:
    la    t0, result                # Load address of result (pseudo-instruction)
    li    t1, 42                    # t1 = 42
    sw    t1, 0(t0)                 # *result = 42
    li    a0, 0                     # return 0
    ret

.section .data
.align 4
result:
    .word 0