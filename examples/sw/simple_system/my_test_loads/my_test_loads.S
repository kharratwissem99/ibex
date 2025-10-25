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
    # BASIC VECTOR STORE TESTS (Known working)
    # =============================================================================
    
    # Test VSE8.V instruction 
    # EXPECTED: Aligned 8-bit store at data_section base address
    # Address: data_section + 0 (word-aligned)
    # Data: v1 elements as bytes, misalignment handling: NONE
    # Instruction: vse8.v v1, (a0)
    # Encoding: 31:26=000000, 25=0, 24:20=00000, 19:15=01010(a0), 14:12=000, 11:7=00001(v1), 6:0=0100111
    # Binary: 0000_0000_0000_0101_0000_0000_1010_0111
    .word 0x000500A7  # vse8.v v1, (a0)
    
    # VERIFY: Load back the stored data to check correctness
    lw t0, 0(a0)        # Load first word from base address
    lw t1, 4(a0)        # Load second word
    # Expected with vl=4: t0 = 0x12345678 (4 bytes: 0x78,0x56,0x34,0x12 packed)
    # t1 may contain remaining bytes or next vector elements
    
    # Test VSE16.V instruction - aligned store at offset 8
    addi a2, a0, 8
    # EXPECTED: Aligned 16-bit store at base + 8
    # Address: data_section + 8 (word-aligned)
    # Data: v1 elements as halfwords, misalignment handling: NONE
    # Instruction: vse16.v v1, (a2)
    # Encoding: 31:26=000000, 25=0, 24:20=00000, 19:15=01100(a2), 14:12=101, 11:7=00001(v1), 6:0=0100111
    # Binary: 0000_0000_0000_0110_0101_0000_1010_0111
    .word 0x000650A7  # vse16.v v1, (a2)
    
    # VERIFY: Load back 16-bit data
    lw t4, 8(a0)        # Load from offset 8
    lw t5, 12(a0)       # Load from offset 12
    # Expected with vl=4: t4 = 0x12345678 (2 hwords: 0x5678,0x1234 packed)
    # t5 = 0xABCDEF00 (next 2 hwords: 0xEF00,0xABCD packed)
    
    # Test VSE32.V instruction - aligned store at offset 16
    addi a3, a0, 16  
    # EXPECTED: Aligned 32-bit store at base + 16
    # Address: data_section + 16 (word-aligned)
    # Data: v1 elements as words, misalignment handling: NONE
    # Instruction: vse32.v v1, (a3)
    # Encoding: 31:26=000000, 25=0, 24:20=00000, 19:15=01101(a3), 14:12=110, 11:7=00001(v1), 6:0=0100111
    # Binary: 0000_0000_0000_0110_1110_0000_1010_0111
    .word 0x0006E0A7  # vse32.v v1, (a3)
    
    # VERIFY: Load back 32-bit data
    lw t6, 16(a0)       # Load from offset 16
    lw s2, 20(a0)       # Load from offset 20
    # Expected with vl=4: t6 = 0x12345678 (1st word), s2 = 0xABCDEF00 (2nd word)
    # vse32.v with vl=4 stores exactly 4 words (16 bytes)

    # =============================================================================
    # VECTOR LOAD UNIT TESTS - NEW FUNCTIONALITY
    # =============================================================================
    
    # Initialize test data for loads - write known patterns to memory
    # Pattern 1: Sequential bytes for VLE8 test
    li t0, 0x03020100       # Bytes: 0x00, 0x01, 0x02, 0x03
    li t1, 0x07060504       # Bytes: 0x04, 0x05, 0x06, 0x07
    sw t0, 32(a0)           # Store at offset 32
    sw t1, 36(a0)           # Store at offset 36
    
    # Pattern 2: Sequential halfwords for VLE16 test  
    li t2, 0x10011000       # Halfwords: 0x1000, 0x1001
    li t3, 0x10031002       # Halfwords: 0x1002, 0x1003
    sw t2, 40(a0)           # Store at offset 40
    sw t3, 44(a0)           # Store at offset 44
    
    # Pattern 3: Sequential words for VLE32 test
    li t4, 0x20000000       # Word: 0x20000000
    li t5, 0x20000001       # Word: 0x20000001
    li t6, 0x20000002       # Word: 0x20000002
    li s2, 0x20000003       # Word: 0x20000003
    sw t4, 48(a0)           # Store at offset 48
    sw t5, 52(a0)           # Store at offset 52
    sw t6, 56(a0)           # Store at offset 56
    sw s2, 60(a0)           # Store at offset 60
    
    # TEST VLE8.V - Load 8-bit elements (bytes)
    addi a4, a0, 32         # Address for VLE8 test data
    # EXPECTED: Load 4 bytes from memory into vector register v10
    # Address: data_section + 32 (word-aligned)
    # Data: Load 4 bytes from memory, vl=4
    # Instruction: vle8.v v10, (a4)
    # Encoding: 31:26=000000, 25=0, 24:20=00000, 19:15=01110(a4), 14:12=000, 11:7=01010(v10), 6:0=0000111
    # Binary: 0000_0000_0000_0111_0000_0101_0000_0111
    .word 0x00070507  # vle8.v v10, (a4)
    
    # Verify VLE8 by storing v10 back to memory and reading
    addi a4, a0, 64         # Use offset 64 for verification
    # Store v10 back to memory to verify load worked
    # Instruction: vse8.v v10, (a4)
    # Encoding: 31:26=000000, 25=0, 24:20=00000, 19:15=01110(a4), 14:12=000, 11:7=01010(v10), 6:0=0100111
    # Binary: 0000_0000_0000_0111_0000_0101_0010_0111
    .word 0x00070527  # vse8.v v10, (a4)
    
    # Read back and verify
    lw s3, 64(a0)           # Should contain 0x03020100 (loaded bytes)
    
    # TEST VLE16.V - Load 16-bit elements (halfwords)
    addi a5, a0, 40         # Address for VLE16 test data
    # EXPECTED: Load 4 halfwords from memory into vector register v11
    # Address: data_section + 40 (word-aligned)
    # Data: Load 4 halfwords from memory, vl=4
    # Instruction: vle16.v v11, (a5)
    # Encoding: 31:26=000000, 25=0, 24:20=00000, 19:15=01111(a5), 14:12=101, 11:7=01011(v11), 6:0=0000111
    # Binary: 0000_0000_0000_0111_1101_0101_1000_0111
    .word 0x0007D587  # vle16.v v11, (a5)
    
    # Verify VLE16 by storing v11 back to memory and reading
    addi a5, a0, 68         # Use offset 68 for verification
    # Store v11 back to memory to verify load worked
    # Instruction: vse16.v v11, (a5)
    # Encoding: 31:26=000000, 25=0, 24:20=00000, 19:15=01111(a5), 14:12=101, 11:7=01011(v11), 6:0=0100111
    # Binary: 0000_0000_0000_0111_1101_0101_1010_0111
    .word 0x0007D5A7  # vse16.v v11, (a5)
    
    # Read back and verify
    lw s4, 68(a0)           # Should contain 0x10011000 (loaded halfwords)
    lw s5, 72(a0)           # Should contain 0x10031002 (loaded halfwords)
    
    # TEST VLE32.V - Load 32-bit elements (words)
    addi a6, a0, 48         # Address for VLE32 test data
    # EXPECTED: Load 4 words from memory into vector register v12
    # Address: data_section + 48 (word-aligned)
    # Data: Load 4 words from memory, vl=4
    # Instruction: vle32.v v12, (a6)
    # Encoding: 31:26=000000, 25=0, 24:20=00000, 19:15=10000(a6), 14:12=110, 11:7=01100(v12), 6:0=0000111
    # Binary: 0000_0000_0000_1000_0110_0110_0000_0111
    .word 0x00086607  # vle32.v v12, (a6)
    
    # Verify VLE32 by storing v12 back to memory and reading
    addi a6, a0, 76         # Use offset 76 for verification
    # Store v12 back to memory to verify load worked
    # Instruction: vse32.v v12, (a6)
    # Encoding: 31:26=000000, 25=0, 24:20=00000, 19:15=10000(a6), 14:12=110, 11:7=01100(v12), 6:0=0100111
    # Binary: 0000_0000_0000_1000_0110_0110_0010_0111
    .word 0x00086627  # vse32.v v12, (a6)
    
    # Read back and verify
    lw s6, 76(a0)           # Should contain 0x20000000 (1st loaded word)
    lw s7, 80(a0)           # Should contain 0x20000001 (2nd loaded word)
    lw s8, 84(a0)           # Should contain 0x20000002 (3rd loaded word)
    lw s9, 88(a0)           # Should contain 0x20000003 (4th loaded word)

    # =============================================================================
    # MISALIGNED VECTOR LOAD TESTS
    # =============================================================================
    
    # Test misaligned VLE8.V - load from offset 33 (misaligned by 1 byte)
    addi a7, a0, 33         # Misaligned address (base + 33)
    # EXPECTED: Misaligned 8-bit load
    # Address: data_section + 33 (misaligned by 1 byte)
    # Data: Load 4 bytes from misaligned address, vl=4
    # Instruction: vle8.v v13, (a7)
    # Encoding: 31:26=000000, 25=0, 24:20=00000, 19:15=10001(a7), 14:12=000, 11:7=01101(v13), 6:0=0000111
    # Binary: 0000_0000_0000_1000_1000_0110_1000_0111
    .word 0x00088687  # vle8.v v13, (a7)
    
    # Verify misaligned VLE8 by storing back
    addi a7, a0, 92         # Use offset 92 for verification
    # Store v13 back to memory
    # Instruction: vse8.v v13, (a7)
    # Encoding: 31:26=000000, 25=0, 24:20=00000, 19:15=10001(a7), 14:12=000, 11:7=01101(v13), 6:0=0100111
    # Binary: 0000_0000_0000_1000_1000_0110_1010_0111
    .word 0x000886A7  # vse8.v v13, (a7)
    
    # Read back misaligned result
    lw s10, 92(a0)          # Should contain shifted data from misaligned load
    
    # Test misaligned VLE16.V - load from offset 41 (misaligned by 1 byte)
    addi t2, a0, 41         # Misaligned address for halfwords
    # EXPECTED: Misaligned 16-bit load
    # Address: data_section + 41 (misaligned by 1 byte from halfword boundary)
    # Data: Load 4 halfwords from misaligned address, vl=4
    # Instruction: vle16.v v14, (t2)
    # Encoding: 31:26=000000, 25=0, 24:20=00000, 19:15=00111(t2), 14:12=101, 11:7=01110(v14), 6:0=0000111
    # Binary: 0000_0000_0000_0011_1101_0111_0000_0111
    .word 0x0003D707  # vle16.v v14, (t2)
    
    # Verify misaligned VLE16 by storing back
    addi t2, a0, 96         # Use offset 96 for verification
    # Store v14 back to memory
    # Instruction: vse16.v v14, (t2)
    # Encoding: 31:26=000000, 25=0, 24:20=00000, 19:15=00111(t2), 14:12=101, 11:7=01110(v14), 6:0=0100111
    # Binary: 0000_0000_0000_0011_1101_0111_0010_0111
    .word 0x0003D727  # vse16.v v14, (t2)
    
    # Read back misaligned result
    lw s11, 96(a0)          # Should contain shifted data from misaligned load
    
    # =============================================================================
    # ADDITIONAL VECTOR REGISTER TESTS
    # =============================================================================
    
    # Test with vector register v2
    addi a4, a0, 24
    # EXPECTED: Aligned 8-bit store with different vector register
    # Address: data_section + 24 (word-aligned)
    # Data: v2 elements (different from v1), misalignment handling: NONE
    # Instruction: vse8.v v2, (a4)
    # Encoding: 31:26=000000, 25=0, 24:20=00000, 19:15=01110(a4), 14:12=000, 11:7=00010(v2), 6:0=0100111
    # Binary: 0000_0000_0000_0111_0000_0001_0010_0111
    .word 0x00070127  # vse8.v v2, (a4)
    
    # VERIFY: Load back v2 data
    lw s3, 24(a0)       # Load v2 data from offset 24
    # Expected: s3 should contain v2[0] bytes (different pattern from v1)

    # =============================================================================
    # STORE-LOAD ROUND-TRIP TESTS - Verify complete functionality
    # =============================================================================
    
    # Round-trip test 1: Store v1 and load it back into v20
    addi t0, a0, 100        # Use offset 100 for round-trip test
    
    # Store v1 using vse32.v
    # Instruction: vse32.v v1, (t0)
    # Encoding: 31:26=000000, 25=0, 24:20=00000, 19:15=00101(t0), 14:12=110, 11:7=00001(v1), 6:0=0100111
    # Binary: 0000_0000_0000_0010_1110_0000_1010_0111
    .word 0x0002E0A7  # vse32.v v1, (t0)
    
    # Load the stored data back into v20
    # Instruction: vle32.v v20, (t0)
    # Encoding: 31:26=000000, 25=0, 24:20=00000, 19:15=00101(t0), 14:12=110, 11:7=10100(v20), 6:0=0000111
    # Binary: 0000_0000_0000_0010_1110_1010_0000_0111
    .word 0x0002EA07  # vle32.v v20, (t0)
    
    # Verify round-trip by storing v20 to a different location
    addi t1, a0, 116        # Use offset 116 for verification
    # Instruction: vse32.v v20, (t1)
    # Encoding: 31:26=000000, 25=0, 24:20=00000, 19:15=00110(t1), 14:12=110, 11:7=10100(v20), 6:0=0100111
    # Binary: 0000_0000_0000_0011_0110_1010_0010_0111
    .word 0x00036A27  # vse32.v v20, (t1)
    
    # Read verification data
    lw t2, 116(a0)          # Should match original v1[0] = 0x12345678
    lw t3, 120(a0)          # Should match original v1[1] = 0xABCDEF00

    # =============================================================================
    # FINAL MEMORY DUMP - Simple register loads only
    # =============================================================================
    # Load final data to verify vector stores and loads worked correctly
    # Just load the data into registers - no function calls that might hang
    
    # Load first 8 words from data_section
    lw t0, 0(a0)        # [0x00] Final result
    lw t1, 4(a0)        # [0x04] Final result  
    lw t2, 8(a0)        # [0x08] Final result
    lw t3, 12(a0)       # [0x0C] Final result
    lw t4, 16(a0)       # [0x10] Final result
    lw t5, 20(a0)       # [0x14] Final result
    lw t6, 24(a0)       # [0x18] Final result
    lw s2, 28(a0)       # [0x1C] Final result
    
    # Load vector load test verification data
    lw s3, 64(a0)       # [0x40] VLE8 verification
    lw s4, 68(a0)       # [0x44] VLE16 verification part 1
    lw s5, 72(a0)       # [0x48] VLE16 verification part 2
    lw s6, 76(a0)       # [0x4C] VLE32 verification part 1
    lw s7, 80(a0)       # [0x50] VLE32 verification part 2
    lw s8, 84(a0)       # [0x54] VLE32 verification part 3
    lw s9, 88(a0)       # [0x58] VLE32 verification part 4
    
    # Load round-trip test verification data
    lw s10, 116(a0)     # [0x74] Round-trip v1[0] verification
    lw s11, 120(a0)     # [0x78] Round-trip v1[1] verification
    
    # Return from main - SIMPLE EXIT
    li a0, 0                    # return 0
    ret

.section .data
data_section:
    .space 128  # Reserve 128 bytes for extended vector store testing