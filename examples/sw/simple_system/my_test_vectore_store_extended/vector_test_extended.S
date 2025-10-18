.option norvc            # keep it plain RV32I (no compressed)
.text
.globl main
.type  main, @function

main:
    # Initialize base address for stores
    la a0, data_section

    # =============================================================================
    # SCALAR STORE REFERENCES (for comparison)
    # =============================================================================
    
    # Test normal aligned scalar store (32-bit)
    li t0, 0x12345678       # Load test data
    sw t0, 0(a0)            # Store word at aligned address
    
    # Test misaligned scalar store (32-bit)
    li t1, 0xABCDEF00       # Load different test data  
    addi a1, a0, 1          # Misaligned address (base + 1)
    sw t1, 0(a1)            # Store word at misaligned address
    
    # =============================================================================
    # BASIC VECTOR STORE TESTS
    # =============================================================================
    
    # Test VSE8.V instruction (should be decoded as vector store)
    # Encoding: vse8.v v1, (a0)
    # 31:26=000000, 25=0, 24:20=00000 (vs2=unused), 19:15=01010 (a0=x10), 14:12=000, 11:7=00001 (v1), 6:0=0100111
    .word 0x000500A7  # vse8.v v1, (a0)
    
    # Test misaligned store
    addi a1, a0, 1
    # Encoding: vse8.v v1, (a1)
    # 31:26=000000, 25=0, 24:20=00000 (vs2=unused), 19:15=01011 (a1=x11), 14:12=000, 11:7=00001 (v1), 6:0=0100111
    .word 0x000580A7  # vse8.v v1, (a1) 
    
    # Test 16-bit store  
    addi a2, a0, 8
    # Encoding: vse16.v v1, (a2)
    # 31:26=000000, 25=0, 24:20=00000 (vs2=unused), 19:15=01100 (a2=x12), 14:12=101, 11:7=00001 (v1), 6:0=0100111
    .word 0x000650A7  # vse16.v v1, (a2)
    
    # Test 32-bit store
    addi a3, a0, 16  
    # Encoding: vse32.v v1, (a3)
    # 31:26=000000, 25=0, 24:20=00000 (vs2=unused), 19:15=01101 (a3=x13), 14:12=110, 11:7=00001 (v1), 6:0=0100111
    .word 0x0006E0A7  # vse32.v v1, (a3)
    
    # =============================================================================
    # DIFFERENT VECTOR REGISTERS
    # =============================================================================
    
    # Test with different vector register (v2)
    addi a4, a0, 24
    # Encoding: vse8.v v2, (a4)
    # 31:26=000000, 25=0, 24:20=00000 (vs2=unused), 19:15=01110 (a4=x14), 14:12=000, 11:7=00010 (v2), 6:0=0100111
    .word 0x000700A7  # vse8.v v2, (a4)
    
    # Test with vector register v3
    addi a5, a0, 32
    # Encoding: vse16.v v3, (a5)
    # 31:26=000000, 25=0, 24:20=00000 (vs2=unused), 19:15=01111 (a5=x15), 14:12=101, 11:7=00011 (v3), 6:0=0100111
    .word 0x0007D8A7  # vse16.v v3, (a5)
    
    # Test with vector register v4
    addi a6, a0, 40
    # Encoding: vse32.v v4, (a6)
    # 31:26=000000, 25=0, 24:20=00000 (vs2=unused), 19:15=10000 (a6=x16), 14:12=110, 11:7=00100 (v4), 6:0=0100111
    .word 0x00080E20A7  # vse32.v v4, (a6)
    
    # =============================================================================
    # MISALIGNMENT EDGE CASES
    # =============================================================================
    
    # Test 16-bit store misaligned by 1 byte
    addi a7, a0, 49
    # Encoding: vse16.v v1, (a7)
    # 31:26=000000, 25=0, 24:20=00000 (vs2=unused), 19:15=10001 (a7=x17), 14:12=101, 11:7=00001 (v1), 6:0=0100111
    .word 0x0008D0A7  # vse16.v v1, (a7)
    
    # Test 16-bit store misaligned by 3 bytes
    addi t2, a0, 51
    # Encoding: vse16.v v1, (t2)
    # 31:26=000000, 25=0, 24:20=00000 (vs2=unused), 19:15=00111 (t2=x7), 14:12=101, 11:7=00001 (v1), 6:0=0100111
    .word 0x000385A7  # vse16.v v1, (t2)
    
    # Test 32-bit store misaligned by 1 byte
    addi t3, a0, 53
    # Encoding: vse32.v v1, (t3)
    # 31:26=000000, 25=0, 24:20=00000 (vs2=unused), 19:15=11100 (t3=x28), 14:12=110, 11:7=00001 (v1), 6:0=0100111
    .word 0x000E0E0A7  # vse32.v v1, (t3)
    
    # Test 32-bit store misaligned by 2 bytes
    addi t4, a0, 58
    # Encoding: vse32.v v1, (t4)
    # 31:26=000000, 25=0, 24:20=00000 (vs2=unused), 19:15=11101 (t4=x29), 14:12=110, 11:7=00001 (v1), 6:0=0100111
    .word 0x000E8E0A7  # vse32.v v1, (t4)
    
    # Test 32-bit store misaligned by 3 bytes
    addi t5, a0, 61
    # Encoding: vse32.v v1, (t5)
    # 31:26=000000, 25=0, 24:20=00000 (vs2=unused), 19:15=11110 (t5=x30), 14:12=110, 11:7=00001 (v1), 6:0=0100111
    .word 0x000F0E0A7  # vse32.v v1, (t5)
    
    # =============================================================================
    # CONSECUTIVE OPERATIONS TEST
    # =============================================================================
    
    # Test multiple consecutive operations to same base
    # vse8.v v1, (a0) - Second time to same address
    .word 0x000500A7  # vse8.v v1, (a0)
    
    # Immediately followed by 16-bit store to same address with different vector reg
    # vse16.v v2, (a0) 
    # 31:26=000000, 25=0, 24:20=00000 (vs2=unused), 19:15=01010 (a0=x10), 14:12=101, 11:7=00010 (v2), 6:0=0100111
    .word 0x000550A7  # vse16.v v2, (a0)
    
    # Followed by 32-bit store to same address with different vector reg
    # vse32.v v3, (a0)
    # 31:26=000000, 25=0, 24:20=00000 (vs2=unused), 19:15=01010 (a0=x10), 14:12=110, 11:7=00011 (v3), 6:0=0100111
    .word 0x000560A7  # vse32.v v3, (a0)
    
    # =============================================================================
    # REGISTER BOUNDARY TESTS
    # =============================================================================
    
    # Test with higher vector registers
    # vse8.v v31, (a0) - Last vector register
    # 31:26=000000, 25=0, 24:20=00000 (vs2=unused), 19:15=01010 (a0=x10), 14:12=000, 11:7=11111 (v31), 6:0=0100111
    .word 0x00051FA7  # vse8.v v31, (a0)
    
    # vse16.v v16, (a0) - Mid-range vector register
    # 31:26=000000, 25=0, 24:20=00000 (vs2=unused), 19:15=01010 (a0=x10), 14:12=101, 11:7=10000 (v16), 6:0=0100111
    .word 0x000580A7  # vse16.v v16, (a0)
    
    # Return from main
    li a0, 0                    # return 0
    ret

.section .data
data_section:
    .space 128  # Reserve 128 bytes for extended vector store testing