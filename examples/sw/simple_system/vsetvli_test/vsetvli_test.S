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
    li x1, 0                # Clear x1 for test results
    li x2, 0                # Clear x2 for test results
    li x3, 0                # Clear x3 for test results
    li x4, 0                # Clear x4 for test results
    li x5, 0                # Clear x5 for test results

    # =============================================================================
    # TEST 1: Basic VSETVLI with different vector lengths
    # =============================================================================
    
    # Test 1.1: Request vl=4, SEW=8, LMUL=1
    li t0, 4                # Request vector length of 4
    # vsetvli x1, t0, e8,m1
    # Encoding: vsetvli rd, rs1, vtypei
    # vtypei for e8,m1: SEW=8 (000), LMUL=1 (000) → vtypei = 0
    # Instruction format: 0_vtypei[10:0]_rs1[4:0]_111_rd[4:0]_1010111
    # Binary: 0_00000000000_00101_111_00001_1010111
    # Hex: 0x0002F0D7
    .word 0x0002F0D7        # vsetvli x1, t0, e8,m1
    
    # Expected: x1 should contain actual vl set (should be 4 if supported)
    
    # Test 1.2: Request vl=8, SEW=16, LMUL=0 (m1)  
    li t1, 8                # Request vector length of 8
    # vsetvli x2, t1, e16,m1
    # vtypei for e16,m1: SEW=16 (001), LMUL=0 (000) → vtypei = 8 (0x008)
    # Binary: 0_00000001000_00110_111_00010_1010111
    # Hex: 0x00837157
    .word 0x00837157        # vsetvli x2, t1, e16,m1
    
    # Expected: x2 should contain actual vl set (should be 8 if supported)
    
    # Test 1.3: Request vl=16, SEW=32, LMUL=0 (m1)
    li t2, 16               # Request vector length of 16
    # vsetvli x3, t2, e32,m1
    # vtypei for e32,m1: SEW=32 (010), LMUL=0 (000) → vtypei = 16 (0x010)
    # Binary: 0_00000010000_00111_111_00011_1010111
    # Hex: 0x0103F1D7
    .word 0x0103F1D7        # vsetvli x3, t2, e32,m1
    
    # Expected: x3 should contain actual vl set (should be 16 if supported)

    # =============================================================================
    # TEST 2: VLMAX tests (rs1 = x0)
    # =============================================================================
    
    # Test 2.1: Set to VLMAX with SEW=8, LMUL=0 (m1)
    # vsetvli x4, x0, e8,m1
    # vtypei for e8,m1: SEW=8 (000), LMUL=0 (000) → vtypei = 0
    # Binary: 0_00000000000_00000_111_00100_1010111
    # Hex: 0x00007257
    .word 0x00007257        # vsetvli x4, x0, e8,m1
    
    # Expected: x4 should contain VLMAX for e8,m1 configuration
    
    # Test 2.2: Set to VLMAX with SEW=16, LMUL=0 (m1)
    # vsetvli x5, x0, e16,m1
    # vtypei for e16,m1: SEW=16 (001), LMUL=0 (000) → vtypei = 8 (0x008)
    # Binary: 0_00000001000_00000_111_00101_1010111
    # Hex: 0x008072D7
    .word 0x008072D7        # vsetvli x5, x0, e16,m1
    
    # Expected: x5 should contain VLMAX for e16,m1 configuration

    # =============================================================================
    # TEST 3: Different SEW values (LMUL always 0)
    # =============================================================================
    
    # Test 3.1: Another SEW=8 test with different vl
    li t3, 1
    # vsetvli x6, t3, e8,m1
    # vtypei for e8,m1: SEW=8 (000), LMUL=0 (000) → vtypei = 0 (0x000)
    # Binary: 0_00000000000_01000_111_00110_1010111
    # Hex: 0x00047357
    .word 0x00047357        # vsetvli x6, t3, e8,m1
    
    # Test 3.2: Another SEW=32 test with different vl
    li t4, 2
    # vsetvli x7, t4, e32,m1
    # vtypei for e32,m1: SEW=32 (010), LMUL=0 (000) → vtypei = 16 (0x010)
    # Binary: 0_00000010000_01001_111_00111_1010111
    # Hex: 0x0104F3D7
    .word 0x0104F3D7        # vsetvli x7, t4, e32,m1

    # =============================================================================
    # TEST 4: Edge cases and special configurations
    # =============================================================================
    
    # Test 4.1: Request vl=0 (should result in vl=0)
    li t5, 0
    # vsetvli x8, t5, e8,m1
    # vtypei for e8,m1: SEW=8 (000), LMUL=1 (000) → vtypei = 0
    # Binary: 0_00000000000_01010_111_01000_1010111
    # Hex: 0x00057457
    .word 0x00057457        # vsetvli x8, t5, e8,m1
    
    # Expected: x8 should be 0
    
    # Test 4.2: Request very large vl (should be clamped to VLMAX)
    li t6, 1000             # Request impossibly large vl
    # vsetvli x9, t6, e8,m1
    # Binary: 0_00000000000_01011_111_01001_1010111
    # Hex: 0x0005F4D7
    .word 0x0005F4D7        # vsetvli x9, t6, e8,m1
    
    # Expected: x9 should be clamped to VLMAX for e8,m1

    # =============================================================================
    # TEST 5: Verify vsetvli results with vector operations
    # =============================================================================
    
    # Set vl=4 for testing
    li t0, 4
    # vsetvli x10, t0, e32,m1
    # vtypei for e32,m1: SEW=32 (010), LMUL=1 (000) → vtypei = 16 (0x010)
    # Binary: 0_00000010000_00101_111_01010_1010111
    # Hex: 0x0102F557
    .word 0x0102F557        # vsetvli x10, t0, e32,m1
    
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
    # vsetvli x11, t0, e16,m1
    # vtypei for e16,m1: SEW=16 (001), LMUL=0 (000) → vtypei = 8 (0x008)
    # Binary: 0_00000001000_00101_111_01011_1010111
    # Hex: 0x0082F5D7
    .word 0x0082F5D7        # vsetvli x11, t0, e16,m1
    
    # Then change to different configuration
    li t1, 8
    # vsetvli x12, t1, e8,m1
    # vtypei for e8,m1: SEW=8 (000), LMUL=0 (000) → vtypei = 0 (0x000)
    # Binary: 0_00000000000_00110_111_01100_1010111
    # Hex: 0x00037657
    .word 0x00037657        # vsetvli x12, t1, e8,m1
    
    # Read current vl without changing it (rs1=x0, rd!=x0)
    # vsetvli x13, x0, e8,m1
    # Binary: 0_00000000000_00000_111_01101_1010111
    # Hex: 0x000076D7
    .word 0x000076D7        # vsetvli x13, x0, e8,m1
    
    # Expected: x13 should match x12 (current vl for e8,m1)

    # =============================================================================
    # TEST 7: Invalid/Reserved configurations (if applicable)
    # =============================================================================
    
    # Test with invalid SEW value (SEW=64 which is not supported)
    li t0, 4
    # Try vsetvli with invalid SEW=64 (011)
    # vtypei for e64,m1: SEW=64 (011), LMUL=0 (000) → vtypei = 24 (0x018)
    # Binary: 0_00000011000_00101_111_01110_1010111
    # Hex: 0x0182F757
    .word 0x01827757        # vsetvli x14, t0, e64,m1 (invalid SEW)
    
    # Expected: Should set vl=0 or cause illegal instruction (implementation-specific)

    # =============================================================================
    # FINAL VERIFICATION - Load all results
    # =============================================================================
    
    # Read all vsetvli results for verification
    # x1 through x14 contain the vl values returned by vsetvli
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

    # Return successfully
    li a0, 0
    ret

.section .data
test_data:
    .space 64               # Space for vector operation testing