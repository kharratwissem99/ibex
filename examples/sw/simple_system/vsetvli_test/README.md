# VSETVLI Instruction Test

This test suite comprehensively validates the `vsetvli` (Vector Set Type and Length Immediate) instruction implementation.

## Test Overview

The `vsetvli` instruction is a crucial part of the RISC-V Vector Extension that configures the vector processing unit by setting:
- **vl (Vector Length)**: Number of elements to process in vector operations
- **vtype**: Vector type configuration including SEW (Standard Element Width) and LMUL (Length Multiplier)

## Test Categories

### 1. Basic Vector Length Tests
- **Test 1.1**: Request vl=4 with SEW=8, LMUL=1
- **Test 1.2**: Request vl=8 with SEW=16, LMUL=1  
- **Test 1.3**: Request vl=16 with SEW=32, LMUL=1

### 2. VLMAX Tests  
- **Test 2.1**: Set to VLMAX with SEW=8, LMUL=1 (rs1=x0)
- **Test 2.2**: Set to VLMAX with SEW=16, LMUL=2 (rs1=x0)

### 3. SEW Variations (LMUL always 0)
- **Test 3.1**: SEW=8, LMUL=0 (m1) with vl=1
- **Test 3.2**: SEW=32, LMUL=0 (m1) with vl=2

### 4. Edge Cases
- **Test 4.1**: Request vl=0 (should result in vl=0)
- **Test 4.2**: Request very large vl (should clamp to VLMAX)

### 5. Vector Operation Integration
- **Test 5**: Use vsetvli result with actual vector load/store operations
- Verify that configured vl affects vector instruction behavior

### 6. State Persistence
- **Test 6**: Multiple vsetvli calls to verify state updates
- Test reading current vl without modification

### 7. Error Handling
- **Test 7**: Invalid SEW=64 configuration (not supported)

## Expected Results

For each `vsetvli` instruction, the destination register should contain:
- **Actual vl set**: May be less than requested if implementation limits apply
- **0**: For invalid configurations or vl=0 requests
- **VLMAX**: When rs1=x0 or when requested vl exceeds maximum

## Instruction Encoding

The test uses manually encoded `vsetvli` instructions with format:
```
vsetvli rd, rs1, vtypei
31    30      20 19   15 14  12 11    7 6      0
0  vtypei[10:0]  rs1[4:0] 111  rd[4:0] 1010111
```

Where `vtypei` encodes:
- **SEW**: Standard Element Width (8, 16, 32 bits only)
- **LMUL**: Always 0 (m1) - Length Multiplier not implemented
- **Reserved bits**: Must be zero

## Building and Running

```bash
# Build the test
make

# Run simulation
make run

# Clean artifacts  
make clean
```

## Verification

The test results can be verified by examining:
1. **Register values**: x1-x14 contain vl values returned by vsetvli
2. **Vector operations**: Successful vector load/store indicates correct vl/vtype
3. **Trace logs**: Detailed execution trace for debugging

## Implementation Notes

This test assumes your `vsetvli` implementation:
- Supports SEW=8,16,32 only (no 64-bit support)
- Uses LMUL=0 (m1) always - LMUL variations not implemented
- Handles VLMAX requests (rs1=x0)
- Properly clamps large vl requests
- Updates internal vl/vtype state for subsequent vector operations