.option norvc            # keep it plain RV32I (no compressed)
.text
.globl main
.type  main, @function

main:
    # Test 1: Aligned store and load
    la    t0, test_data             # Load base address (aligned)
    li    t1, 0x12345678           # t1 = test pattern
    sw    t1, 0(t0)                # Store to aligned address (offset 0)
    lw    t2, 0(t0)                # Load from aligned address (offset 0)
    
    # Test 2: Misaligned store and load (offset +1)
    la    t0, test_data             # Load base address
    addi  t0, t0, 1                # Make address misaligned (+1 byte)
    li    t1, 0xABCDEF00           # t1 = different test pattern
    sw    t1, 0(t0)                # Store to misaligned address (will cause exception or multi-cycle)
    lw    t2, 0(t0)                # Load from misaligned address (will cause exception or multi-cycle)
    
    # Test 3: Misaligned store and load (offset +2)
    la    t0, test_data             # Load base address
    addi  t0, t0, 2                # Make address misaligned (+2 bytes)
    li    t1, 0xDEADBEEF           # t1 = another test pattern
    sw    t1, 0(t0)                # Store to misaligned address (offset +2)
    lw    t2, 0(t0)                # Load from misaligned address (offset +2)
    
    # Test 4: Misaligned store and load (offset +3)
    la    t0, test_data             # Load base address
    addi  t0, t0, 3                # Make address misaligned (+3 bytes)
    li    t1, 0xCAFEBABE           # t1 = final test pattern
    sw    t1, 0(t0)                # Store to misaligned address (offset +3)
    lw    t2, 0(t0)                # Load from misaligned address (offset +3)
    
    li    a0, 0                    # return 0
    ret

.section .data
.align 4
test_data:
    .word 0, 0, 0, 0, 0, 0, 0, 0   # Provide enough space for all misaligned accesses