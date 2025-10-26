# VSETVLI Test Quick Reference

## Instruction Encodings Used

| Test | Instruction | Encoding | Description |
|------|-------------|----------|-------------|
| 1.1 | `vsetvli x1, t0, e8,m1` | 0x0002F057 | vl=4, SEW=8, LMUL=0 |
| 1.2 | `vsetvli x2, t1, e16,m1` | 0x00837057 | vl=8, SEW=16, LMUL=0 |  
| 1.3 | `vsetvli x3, t2, e32,m1` | 0x0103F057 | vl=16, SEW=32, LMUL=0 |
| 2.1 | `vsetvli x4, x0, e8,m1` | 0x00007157 | VLMAX, SEW=8, LMUL=0 |
| 2.2 | `vsetvli x5, x0, e16,m1` | 0x000072D7 | VLMAX, SEW=16, LMUL=0 |
| 3.1 | `vsetvli x6, t3, e8,m1` | 0x00047357 | vl=1, SEW=8, LMUL=0 |
| 3.2 | `vsetvli x7, t4, e32,m1` | 0x0104F3D7 | vl=2, SEW=32, LMUL=0 |
| 4.1 | `vsetvli x8, t5, e8,m1` | 0x00057457 | vl=0, SEW=8, LMUL=0 |
| 4.2 | `vsetvli x9, t6, e8,m1` | 0x0005F4D7 | vl=1000→VLMAX, SEW=8, LMUL=0 |
| 5 | `vsetvli x10, t0, e32,m1` | 0x0102F557 | vl=4, SEW=32, LMUL=0 |
| 6.1 | `vsetvli x11, t0, e16,m1` | 0x0082F5D7 | vl=2, SEW=16, LMUL=0 |
| 6.2 | `vsetvli x12, t1, e8,m1` | 0x00037657 | vl=8, SEW=8, LMUL=0 |
| 6.3 | `vsetvli x13, x0, e8,m1` | 0x000076D7 | Read current vl |
| 7 | `vsetvli x14, t0, e64,m1` | 0x01827757 | Invalid SEW=64 |

## VTYPEI Encoding Reference

| Field | Bits | Values | Description |
|-------|------|--------|-------------|
| SEW | [5:3] | 000=8, 001=16, 010=32 | Standard Element Width (64 not supported) |
| LMUL | [2:0] | Always 000 (m1) | Length Multiplier (not implemented) |
| Reserved | [10:6] | Must be 0 | Reserved for future use |

## Expected Register Values After Test

| Register | Expected Value | Description |
|----------|----------------|-------------|
| x1 | 4 (or impl limit) | vl for e8,m1 with req=4 |
| x2 | 8 (or impl limit) | vl for e16,m1 with req=8 |
| x3 | 16 (or impl limit) | vl for e32,m1 with req=16 |
| x4 | VLMAX for e8,m1 | VLMAX configuration |
| x5 | VLMAX for e16,m1 | VLMAX configuration |
| x6 | 1 (or impl limit) | vl for e8,m1 with req=1 |
| x7 | 2 (or impl limit) | vl for e32,m1 with req=2 |
| x8 | 0 | vl=0 request |
| x9 | VLMAX for e8,m1 | Large request clamped |
| x10 | 4 (or impl limit) | vl for vector ops test |
| x11 | 2 (or impl limit) | vl for e16,m1 with req=2 |
| x12 | 8 (or impl limit) | vl for e8,m1 with req=8 |
| x13 | Same as x12 | Current vl read |
| x14 | 0 or exception | Invalid SEW=64 |

## Debug Points

1. **Check CSR Updates**: Verify that vl and vtype CSRs are updated
2. **Vector Operations**: Confirm that vector load/store use configured vl
3. **VLMAX Calculation**: Verify VLMAX = VLEN / SEW (since LMUL=1 always)
4. **Clamping**: Large vl requests should be clamped to VLMAX
5. **Zero Handling**: vl=0 request should result in vl=0