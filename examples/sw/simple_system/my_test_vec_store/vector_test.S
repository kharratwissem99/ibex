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
    
    # Return from main
    li a0, 0                    # return 0
    ret

.section .data
data_section:
    .space 64  # Reserve 64 bytes for vector store testing