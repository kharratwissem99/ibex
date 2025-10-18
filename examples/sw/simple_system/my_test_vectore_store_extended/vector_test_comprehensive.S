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
    
    # Test misaligned 8-bit store
    addi a1, a0, 1
    # EXPECTED: Misaligned 8-bit store at base + 1
    # Address: data_section + 1 (misaligned by 1 byte)
    # Data: v1 elements as bytes, misalignment handling: data rotation + multiple mem ops
    # Instruction: vse8.v v1, (a1)
    # Encoding: 31:26=000000, 25=0, 24:20=00000, 19:15=01011(a1), 14:12=000, 11:7=00001(v1), 6:0=0100111
    # Binary: 0000_0000_0000_0101_1000_0000_1010_0111
    .word 0x000580A7  # vse8.v v1, (a1) 
    
    # VERIFY: Load back misaligned data
    lw t2, 0(a1)        # Load from misaligned address (will get partial data)
    lw t3, 4(a1)        # Load next word
    # Expected: Data should be rotated due to misalignment
    
    # Test 16-bit store  
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
    
    # Test 32-bit store
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
    # ADDITIONAL TEST CASES - Different Vector Registers
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
    
    # Test with vector register v3  
    addi a5, a0, 32
    # EXPECTED: Aligned 16-bit store with vector register v3
    # Address: data_section + 32 (word-aligned)
    # Data: v3 elements as halfwords, misalignment handling: NONE
    # Instruction: vse16.v v3, (a5)
    # Encoding: 31:26=000000, 25=0, 24:20=00000, 19:15=01111(a5), 14:12=101, 11:7=00011(v3), 6:0=0100111
    # Binary: 0000_0000_0000_0111_1101_0001_1010_0111
    .word 0x0007D1A7  # vse16.v v3, (a5)
    
    # VERIFY: Load back v3 data
    lw s4, 32(a0)       # Load v3 data from offset 32
    # Expected: s4 should contain v3[0] halfwords
    
    # Test with vector register v4
    addi a6, a0, 40  
    # EXPECTED: Aligned 32-bit store with vector register v4
    # Address: data_section + 40 (word-aligned)
    # Data: v4 elements as words, misalignment handling: NONE
    # Instruction: vse32.v v4, (a6)
    # Encoding: 31:26=000000, 25=0, 24:20=00000, 19:15=10000(a6), 14:12=110, 11:7=00100(v4), 6:0=0100111
    # Binary: 0000_0000_0000_1000_0110_0010_0010_0111
    .word 0x00086227  # vse32.v v4, (a6)
    
    # VERIFY: Load back v4 data
    lw s5, 40(a0)       # Load v4 data from offset 40
    # Expected: s5 should contain v4[0] as word
    
    # =============================================================================
    # MISALIGNMENT EDGE CASES  
    # =============================================================================
    
    # Test 16-bit store misaligned by 1 byte
    addi a7, a0, 49
    # EXPECTED: Misaligned 16-bit store (halfword boundary violation)
    # Address: data_section + 49 (misaligned by 1 byte from halfword boundary)
    # Data: v1 elements as halfwords, misalignment handling: data rotation + multiple mem ops
    # Instruction: vse16.v v1, (a7)
    # Encoding: 31:26=000000, 25=0, 24:20=00000, 19:15=10001(a7), 14:12=101, 11:7=00001(v1), 6:0=0100111
    # Binary: 0000_0000_0000_1000_1101_0000_1010_0111
    .word 0x0008D0A7  # vse16.v v1, (a7)
    
    # VERIFY: Load back misaligned 16-bit data
    lw s6, 48(a0)       # Load word containing misaligned data (offset 49 spans this word)
    lw s7, 52(a0)       # Load next word
    # Expected: Data should span across word boundaries due to misalignment
    
    # Test 16-bit store misaligned by 3 bytes
    addi t2, a0, 51
    # EXPECTED: Misaligned 16-bit store (3-byte offset from word boundary)
    # Address: data_section + 51 (misaligned by 3 bytes from word boundary)
    # Data: v1 elements as halfwords, misalignment handling: data rotation + multiple mem ops
    # Instruction: vse16.v v1, (t2)
    # Encoding: 31:26=000000, 25=0, 24:20=00000, 19:15=00111(t2), 14:12=101, 11:7=00001(v1), 6:0=0100111
    # Binary: 0000_0000_0000_0011_1101_0000_1010_0111
    .word 0x0003D0A7  # vse16.v v1, (t2)
    
    # VERIFY: Load back data from offset 51
    lw s8, 48(a0)       # Load word at 48 (covers offset 51)
    lw s9, 52(a0)       # Load word at 52
    # Expected: More misaligned data spanning word boundaries
    
    # Test 32-bit store misaligned by 1 byte
    addi t3, a0, 53
    # EXPECTED: Misaligned 32-bit store (1-byte offset from word boundary)
    # Address: data_section + 53 (misaligned by 1 byte from word boundary)
    # Data: v1 elements as words, misalignment handling: data rotation + multiple mem ops
    # Instruction: vse32.v v1, (t3)
    # Encoding: 31:26=000000, 25=0, 24:20=00000, 19:15=11100(t3), 14:12=110, 11:7=00001(v1), 6:0=0100111
    # Binary: 0000_0000_0000_1110_0110_0000_1010_0111
    .word 0x000E60A7  # vse32.v v1, (t3) 
    
    # VERIFY: Load back misaligned 32-bit data
    lw s10, 52(a0)      # Load word containing start of misaligned data
    lw s11, 56(a0)      # Load word containing continuation
    # Expected: 32-bit data split across multiple words due to 1-byte misalignment 
    
    # Test 32-bit store misaligned by 2 bytes
    addi t4, a0, 58
    # EXPECTED: Misaligned 32-bit store (2-byte offset from word boundary)
    # Address: data_section + 58 (misaligned by 2 bytes from word boundary)
    # Data: v1 elements as words, misalignment handling: data rotation + multiple mem ops
    # Instruction: vse32.v v1, (t4)
    # Encoding: 31:26=000000, 25=0, 24:20=00000, 19:15=11101(t4), 14:12=110, 11:7=00001(v1), 6:0=0100111
    # Binary: 0000_0000_0000_1110_1110_0000_1010_0111
    .word 0x000EE0A7  # vse32.v v1, (t4)
    
    # Test 32-bit store misaligned by 3 bytes  
    addi t5, a0, 61
    # EXPECTED: Misaligned 32-bit store (3-byte offset from word boundary)
    # Address: data_section + 61 (misaligned by 3 bytes from word boundary)
    # Data: v1 elements as words, misalignment handling: data rotation + multiple mem ops
    # Instruction: vse32.v v1, (t5)
    # Encoding: 31:26=000000, 25=0, 24:20=00000, 19:15=11110(t5), 14:12=110, 11:7=00001(v1), 6:0=0100111
    # Binary: 0000_0000_0000_1111_0110_0000_1010_0111
    .word 0x000F60A7  # vse32.v v1, (t5)
    
    # =============================================================================
    # STRESS TESTS - Multiple operations
    # =============================================================================
    
    # Rapid consecutive operations to test state machine
    # EXPECTED: Back-to-back vector stores to same address with different element sizes
    # Address: data_section + 0 (all three operations to same base address)
    # Data: Different vector registers (v1, v2, v3) with different element widths
    # Purpose: Test state machine transitions and data overwrites
    
    # Instruction: vse8.v v1, (a0) - repeat
    # Encoding: 31:26=000000, 25=0, 24:20=00000, 19:15=01010(a0), 14:12=000, 11:7=00001(v1), 6:0=0100111
    # Binary: 0000_0000_0000_0101_0000_0000_1010_0111
    .word 0x000500A7  # vse8.v v1, (a0) - repeat
    
    # Instruction: vse16.v v2, (a0)
    # Encoding: 31:26=000000, 25=0, 24:20=00000, 19:15=01010(a0), 14:12=101, 11:7=00010(v2), 6:0=0100111
    # Binary: 0000_0000_0000_0101_0101_0001_0010_0111
    .word 0x000550A7  # vse16.v v2, (a0) 
    
    # Instruction: vse32.v v3, (a0)
    # Encoding: 31:26=000000, 25=0, 24:20=00000, 19:15=01010(a0), 14:12=110, 11:7=00011(v3), 6:0=0100111
    # Binary: 0000_0000_0000_0101_0110_0001_1010_0111
    .word 0x000560A7  # vse32.v v3, (a0)
    
    # Test all three sizes back-to-back with same vector register
    addi t6, a0, 70
    # EXPECTED: Same vector register (v5) with different element sizes at same address
    # Address: data_section + 70 (all three operations to same offset)
    # Data: Same vector register v5 with different element interpretations
    # Purpose: Test element size handling with identical source data
    
    # Instruction: vse8.v v5, (t6)
    # Encoding: 31:26=000000, 25=0, 24:20=00000, 19:15=11111(t6), 14:12=000, 11:7=00101(v5), 6:0=0100111
    # Binary: 0000_0000_0000_1111_1000_0010_1010_0111
    .word 0x000F82A7  # vse8.v v5, (t6)
    
    # Instruction: vse16.v v5, (t6)
    # Encoding: 31:26=000000, 25=0, 24:20=00000, 19:15=11111(t6), 14:12=101, 11:7=00101(v5), 6:0=0100111
    # Binary: 0000_0000_0000_1111_1101_0010_1010_0111
    .word 0x000FD2A7  # vse16.v v5, (t6)
    
    # Instruction: vse32.v v5, (t6)
    # Encoding: 31:26=000000, 25=0, 24:20=00000, 19:15=11111(t6), 14:12=110, 11:7=00101(v5), 6:0=0100111
    # Binary: 0000_0000_0000_1111_1110_0010_1010_0111
    .word 0x000FE2A7  # vse32.v v5, (t6)
    
    # =============================================================================
    # BOUNDARY CONDITIONS
    # =============================================================================
    
    # Test near end of data section
    addi s0, a0, 120  # Close to end of 128-byte section
    # EXPECTED: Store near memory boundary (boundary test)
    # Address: data_section + 120 (8 bytes from end of 128-byte section)
    # Data: v1 elements as bytes, misalignment handling: NONE (aligned)
    # Purpose: Test memory boundary conditions and potential overflow detection
    # Instruction: vse8.v v1, (s0)
    # Encoding: 31:26=000000, 25=0, 24:20=00000, 19:15=01000(s0), 14:12=000, 11:7=00001(v1), 6:0=0100111
    # Binary: 0000_0000_0000_0100_0000_0000_1010_0111
    .word 0x000400A7  # vse8.v v1, (s0)
    
    # VERIFY: Load back boundary data
    lw t0, 120(a0)      # Load from near end of section (use t0 instead of ra)
    # Expected: t0 should contain v1[0] bytes
    
    # Test with maximum vector register number  
    addi s1, a0, 124
    # EXPECTED: Store with highest vector register number (register boundary test)
    # Address: data_section + 124 (4 bytes from end of 128-byte section)
    # Data: v31 elements as bytes, misalignment handling: NONE (aligned)
    # Purpose: Test maximum vector register addressing and VRF boundary
    # Instruction: vse8.v v31, (s1)
    # Encoding: 31:26=000000, 25=0, 24:20=00000, 19:15=01001(s1), 14:12=000, 11:7=11111(v31), 6:0=0100111
    # Binary: 0000_0000_0000_0100_1000_1111_1010_0111
    .word 0x00048fa7  # vse8.v v31, (s1)
    
    # VERIFY: Load back v31 data
    lw t1, 124(a0)      # Load v31 data from offset 124 (use t1 instead of sp)
    # Expected: t1 should contain v31[0] bytes (0xFFFFFFFF pattern)
    
    # =============================================================================
    # VERIFICATION SUMMARY - Expected Values with vl=4
    # =============================================================================
    # Based on VRF initialization in ibex_vrf.sv and FIXED vl=4:
    #
    # Vector Register Contents (128-bit each, 4 banks of 32-bit):
    # v1  = {0xCAFEBABE, 0xDEADBEEF, 0xABCDEF00, 0x12345678} (banks 3,2,1,0)
    # v2  = {0xAFEBABEC, 0xEADBEEF0, 0xBCDEF011, 0x23456789}
    # v3  = {0xFEBABECA, 0xADBEEF01, 0xCDEF0122, 0x3456789A}
    # v4  = {0x35014543, 0x21524110, 0x543210FF, 0xEDCBA987}
    # v5  = {0x5555AAAA, 0xAAAA5555, 0x5555AAAA, 0xAAAA5555}
    # v31 = {0x0F0F0F0F, 0xF0F0F0F0, 0x00000000, 0xFFFFFFFF}
    #
    # With vl=4, each vector store will write exactly 4 elements:
    #
    # vse8.v  v1: Stores 4 bytes  = 0x78, 0x56, 0x34, 0x12 (from v1[0])
    # vse16.v v1: Stores 4 hwords = 0x5678, 0x1234, 0xEF00, 0xABCD (from v1[0:1])
    # vse32.v v1: Stores 4 words  = 0x12345678, 0xABCDEF00, 0xDEADBEEF, 0xCAFEBABE
    #
    # Expected register values after verification loads:
    # First t0  = 0x12345678 (word containing 4 bytes from vse8.v v1 at offset 0)
    # First t1  = 0xABCDEF00 (next word from vse8.v v1 - may contain partial/next elements)  
    # t6  = 0x12345678 (first word from vse32.v v1 at offset 16)
    # s2  = 0xABCDEF00 (second word from vse32.v v1 at offset 20)
    # s3  = 0x23456789 (word containing 4 bytes from vse8.v v2 at offset 24)
    # s4  = 0x3456789A (word containing 2 hwords from vse16.v v3 at offset 32)
    # s5  = 0xEDCBA987 (first word from vse32.v v4 at offset 40)
    # Final t0 = 0x12345678 (word containing 4 bytes from vse8.v v1 at offset 120)
    # Final t1 = 0xFFFFFFFF (word containing 4 bytes from vse8.v v31 at offset 124)
    #
    # Memory Layout with vl=4:
    # - vse8.v stores exactly 4 bytes per operation
    # - vse16.v stores exactly 8 bytes (4 halfwords) per operation  
    # - vse32.v stores exactly 16 bytes (4 words) per operation
    
    # Return from main
    li a0, 0                    # return 0
    ret

.section .data
data_section:
    .space 128  # Reserve 128 bytes for extended vector store testing