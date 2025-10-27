.option norvc            # keep it plain RV32I (no compressed)
.text
.globl main
.type  main, @function

main:
    # =============================================================================
    # VSETVLI INSTRUCTION TESTS
    # =============================================================================
    # The vsetvli instruction sets vector length (vl) and vector type (vtype)
    # Format: vsetvli rd, rs1, vtypei
    # rd = destination register (receives actual vl set)
    # rs1 = source register (requested vl, or x0 for VLMAX)
    # vtypei = immediate encoding vector type configuration
    
    # Initialize test registers
    # Note: x1 is used as link register (ra) - do not clear it!
    li x2, 0                # Clear x2 for test results
    li x3, 0                # Clear x3 for test results
    li x4, 0                # Clear x4 for test results
    li x5, 0                # Clear x5 for test results

    # =============================================================================
    # TEST 1: Basic VSETVLI with different vector lengths
    # =============================================================================
    
    # Test 1.1: Request vl=4, SEW=8, LMUL=0 (m1)
    li t0, 4                # Request vector length of 4
    # vsetvli s0, t0, e8,m1  (use s0 instead of x1 to preserve return address)
    # Encoding: vsetvli rd, rs1, vtypei
    # vtypei for e8,m1: SEW=8 (000), LMUL=0 (000) → vtypei = 0
    # Instruction format: 0_vtypei[10:0]_rs1[4:0]_111_rd[4:0]_1010111
    # Binary: 0_00000000000_00101_111_01000_1010111 (rd=s0=x8)
    # Hex: 0x0002F457
    .word 0x0002F457        # vsetvli s0, t0, e8,m1
    
    # Expected: s0 should contain actual vl set (should be 4 if supported)
    
    # Test 1.2: Request vl=8, SEW=16, LMUL=0 (m1)  
    li t1, 8                # Request vector length of 8
    # vsetvli s1, t1, e16,m1
    # vtypei for e16,m1: SEW=16 (001), LMUL=0 (000) → vtypei = 8 (0x008)
    # Binary: 0_00000001000_00110_111_01001_1010111 (rd=s1=x9)
    # Hex: 0x008374D7
    .word 0x008374D7        # vsetvli s1, t1, e16,m1
    
    # Expected: s1 should contain actual vl set (should be 8 if supported)
    
    # Test 1.3: Request vl=16, SEW=32, LMUL=0 (m1)
    li t2, 16               # Request vector length of 16
    # vsetvli s2, t2, e32,m1
    # vtypei for e32,m1: SEW=32 (010), LMUL=0 (000) → vtypei = 16 (0x010)
    # Binary: 0_00000010000_00111_111_10010_1010111 (rd=s2=x18)
    # Hex: 0x0103F957
    .word 0x0103F957        # vsetvli s2, t2, e32,m1
    
    # Expected: x3 should contain actual vl set (should be 16 if supported)

    # =============================================================================
    # TEST 2: VLMAX tests (rs1 = x0)
    # =============================================================================
    
    # Test 2.1: Set to VLMAX with SEW=8, LMUL=0 (m1)
    # vsetvli s3, x0, e8,m1
    # vtypei for e8,m1: SEW=8 (000), LMUL=0 (000) → vtypei = 0
    # Binary: 0_00000000000_00000_111_10011_1010111 (rd=s3=x19)
    # Hex: 0x000079D7
    .word 0x000079D7        # vsetvli s3, x0, e8,m1
    
    # Expected: s3 should contain VLMAX for e8,m1 configuration
    
    # Test 2.2: Set to VLMAX with SEW=16, LMUL=0 (m1)
    # vsetvli s4, x0, e16,m1
    # vtypei for e16,m1: SEW=16 (001), LMUL=0 (000) → vtypei = 8 (0x008)
    # Binary: 0_00000001000_00000_111_10100_1010111 (rd=s4=x20)
    # Hex: 0x00007A57
    .word 0x00007A57        # vsetvli s4, x0, e16,m1
    
    # Expected: s4 should contain VLMAX for e16,m1 configuration

    # =============================================================================
    # TEST 3: Different SEW values (LMUL always 0)
    # =============================================================================
    
    # Test 3.1: Another SEW=8 test with different vl
    li t3, 1
    # vsetvli s5, t3, e8,m1
    # vtypei for e8,m1: SEW=8 (000), LMUL=0 (000) → vtypei = 0 (0x000)
    # Binary: 0_00000000000_11100_111_10101_1010111 (rd=s5=x21)
    # Hex: 0x0007FAD7
    .word 0x0007FAD7        # vsetvli s5, t3, e8,m1
    
    # Test 3.2: Another SEW=32 test with different vl
    li t4, 2
    # vsetvli s6, t4, e32,m1
    # vtypei for e32,m1: SEW=32 (010), LMUL=0 (000) → vtypei = 16 (0x010)
    # Binary: 0_00000010000_11101_111_10110_1010111 (rd=s6=x22)
    # Hex: 0x010EFB57
    .word 0x010EFB57        # vsetvli s6, t4, e32,m1

    # =============================================================================
    # TEST 4: Edge cases and special configurations
    # =============================================================================
    
    # Test 4.1: Request vl=0 (should result in vl=0)
    li t5, 0
    # vsetvli s7, t5, e8,m1
    # vtypei for e8,m1: SEW=8 (000), LMUL=0 (000) → vtypei = 0
    # Binary: 0_00000000000_11110_111_10111_1010111 (rd=s7=x23)
    # Hex: 0x0007FBD7
    .word 0x0007FBD7        # vsetvli s7, t5, e8,m1
    
    # Expected: s7 should be 0
    
    # Test 4.2: Request very large vl (should be clamped to VLMAX)
    li t6, 1000             # Request impossibly large vl
    # vsetvli s8, t6, e8,m1
    # Binary: 0_00000000000_11111_111_11000_1010111 (rd=s8=x24)
    # Hex: 0x000FFC57
    .word 0x000FFC57        # vsetvli s8, t6, e8,m1
    
    # Expected: s8 should be clamped to VLMAX for e8,m1

    # =============================================================================
    # TEST 5: Verify vsetvli results with vector operations
    # =============================================================================
    
    # Set vl=4 for testing
    li t0, 4
    # vsetvli s9, t0, e32,m1
    # vtypei for e32,m1: SEW=32 (010), LMUL=0 (000) → vtypei = 16 (0x010)
    # Binary: 0_00000010000_00101_111_11001_1010111 (rd=s9=x25)
    # Hex: 0x0102FCD7
    .word 0x0102FCD7        # vsetvli s9, t0, e32,m1
    
    # Now test a vector operation with this configuration
    la a0, test_data
    
    # Test vector store with the configured vl
    li t0, 0x12345678
    li t1, 0xABCDEF00
    li t2, 0xDEADBEEF
    li t3, 0xCAFEBABE
    
    # Store test data for vector operations
    sw t0, 0(a0)
    sw t1, 4(a0)
    sw t2, 8(a0)
    sw t3, 12(a0)
    
    # Perform a vector load operation to verify vl is working
    # vle32.v v1, (a0)
    # Encoding for vle32.v: 000000_0_00000_01010_110_00001_0000111
    # Binary: 000000_0_00000_01010_110_00001_0000111
    # Hex: 0x00056087
    .word 0x00056087        # vle32.v v1, (a0)
    
    # Store the loaded data back to verify
    addi a1, a0, 16
    # vse32.v v1, (a1)
    # Encoding for vse32.v: 000000_0_00000_01011_110_00001_0100111
    # Binary: 000000_0_00000_01011_110_00001_0100111
    # Hex: 0x0005E0A7
    .word 0x0005E0A7        # vse32.v v1, (a1)
    
    # Load back to verify vector operations worked with set vl
    lw s0, 16(a0)           # Should match first element
    lw s1, 20(a0)           # Should match second element  
    lw s2, 24(a0)           # Should match third element
    lw s3, 28(a0)           # Should match fourth element

    # =============================================================================
    # TEST 6: Multiple vsetvli calls (state persistence)
    # =============================================================================
    
    # Test that vsetvli updates the state correctly
    li t0, 2
    # vsetvli s10, t0, e16,m1
    # vtypei for e16,m1: SEW=16 (001), LMUL=0 (000) → vtypei = 8 (0x008)
    # Binary: 0_00000001000_00101_111_11010_1010111 (rd=s10=x26)
    # Hex: 0x0082FD57
    .word 0x0082FD57        # vsetvli s10, t0, e16,m1
    
    # Then change to different configuration
    li t1, 8
    # vsetvli s11, t1, e8,m1
    # vtypei for e8,m1: SEW=8 (000), LMUL=0 (000) → vtypei = 0 (0x000)
    # Binary: 0_00000000000_00110_111_11011_1010111 (rd=s11=x27)
    # Hex: 0x00037DD7
    .word 0x00037DD7        # vsetvli s11, t1, e8,m1
    
    # Read current vl without changing it (rs1=x0, rd!=x0)
    # vsetvli t3, x0, e8,m1
    # Binary: 0_00000000000_00000_111_11100_1010111 (rd=t3=x28)
    # Hex: 0x00007E57
    .word 0x00007E57        # vsetvli t3, x0, e8,m1
    
    # Expected: t3 should match s11 (current vl for e8,m1)

    # =============================================================================
    # TEST 7: Invalid/Reserved configurations (if applicable)
    # =============================================================================
    
    # Test with invalid SEW value (SEW=64 which is not supported)
    li t0, 4
    # Try vsetvli with invalid SEW=64 (011)
    # vtypei for e64,m1: SEW=64 (011), LMUL=0 (000) → vtypei = 24 (0x018)
    # Binary: 0_00000011000_00101_111_11101_1010111 (rd=t4=x29)
    # Hex: 0x0182FED7
    .word 0x0182FED7        # vsetvli t4, t0, e64,m1 (invalid SEW)
    
    # Expected: Should set vl=0 or cause illegal instruction (implementation-specific)

    # =============================================================================
    # FINAL VERIFICATION - Load all results
    # =============================================================================
    
    # Read all vsetvli results for verification
    # s0-s11, t3-t4 contain the vl values returned by vsetvli
    # We can examine these in the trace to verify correct operation
    
    # Also read vector operation verification data
    lw a2, 0(a0)            # Original data element 0
    lw a3, 4(a0)            # Original data element 1  
    lw a4, 8(a0)            # Original data element 2
    lw a5, 12(a0)           # Original data element 3
    
    lw a6, 16(a0)           # Vector loaded/stored element 0
    lw a7, 20(a0)           # Vector loaded/stored element 1
    lw t0, 24(a0)           # Vector loaded/stored element 2
    lw t1, 28(a0)           # Vector loaded/stored element 3

    # Return successfully (x1/ra contains the correct return address)
    li a0, 0
    ret

.section .data
test_data:
    .space 64               # Space for vector operation testing