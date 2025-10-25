#include <stdint.h>

// Test data section - 128 bytes aligned
static uint32_t data_section[32] __attribute__((aligned(128)));

// Inline assembly wrapper functions for vector stores
static inline void vse8_v1_to_addr(void* addr) {
    register void* a0 asm("a0") = addr;
    asm volatile(".word 0x000500A7" : : "r"(a0) : "memory");
}

static inline void vse16_v1_to_addr(void* addr) {
    register void* a1 asm("a1") = addr;
    asm volatile(".word 0x000580A7" : : "r"(a1) : "memory");
}

static inline void vse32_v1_to_addr(void* addr) {
    register void* a2 asm("a2") = addr;
    asm volatile(".word 0x000650A7" : : "r"(a2) : "memory");
}

static inline void vse8_v2_to_addr(void* addr) {
    register void* a4 asm("a4") = addr;
    asm volatile(".word 0x00070127" : : "r"(a4) : "memory");
}

static inline void vse16_v3_to_addr(void* addr) {
    register void* a5 asm("a5") = addr;
    asm volatile(".word 0x0007D1A7" : : "r"(a5) : "memory");
}

static inline void vse32_v4_to_addr(void* addr) {
    register void* a6 asm("a6") = addr;
    asm volatile(".word 0x00086227" : : "r"(a6) : "memory");
}

static inline void vse8_v5_to_addr(void* addr) {
    register void* t6 asm("t6") = addr;
    asm volatile(".word 0x000F82A7" : : "r"(t6) : "memory");
}

static inline void vse8_v31_to_addr(void* addr) {
    register void* s1 asm("s1") = addr;
    asm volatile(".word 0x00048fa7" : : "r"(s1) : "memory");
}

int main(void) {
    // Initialize data section to zero
    for (int i = 0; i < 32; i++) {
        data_section[i] = 0;
    }
    
    // =============================================================================
    // SCALAR REFERENCE TESTS
    // =============================================================================
    
    // Normal aligned scalar store
    data_section[0] = 0x12345678;
    
    // Misaligned scalar store (simulate with byte pointer)
    uint8_t* byte_ptr = (uint8_t*)data_section;
    uint32_t misaligned_value = 0xABCDEF00;
    byte_ptr[1] = misaligned_value & 0xFF;
    byte_ptr[2] = (misaligned_value >> 8) & 0xFF;
    byte_ptr[3] = (misaligned_value >> 16) & 0xFF;
    byte_ptr[4] = (misaligned_value >> 24) & 0xFF;
    
    // Verification load
    uint32_t verify_scalar1 = data_section[0];
    uint32_t verify_scalar2 = data_section[1];
    
    // =============================================================================
    // BASIC VECTOR STORE TESTS
    // =============================================================================
    
    // Test vse8.v v1 - aligned at offset 0
    vse8_v1_to_addr(&data_section[0]);
    uint32_t result_vse8_0 = data_section[0];
    
    // Test vse16.v v1 - aligned at offset 8
    vse16_v1_to_addr(&data_section[2]);  // offset 8 bytes = index 2
    uint32_t result_vse16_8 = data_section[2];
    uint32_t result_vse16_12 = data_section[3];
    
    // Test vse32.v v1 - aligned at offset 16
    vse32_v1_to_addr(&data_section[4]);  // offset 16 bytes = index 4
    uint32_t result_vse32_16 = data_section[4];
    uint32_t result_vse32_20 = data_section[5];
    uint32_t result_vse32_24 = data_section[6];
    uint32_t result_vse32_28 = data_section[7];
    
    // =============================================================================
    // DIFFERENT VECTOR REGISTERS
    // =============================================================================
    
    // Test vse8.v v2 at offset 24
    vse8_v2_to_addr(&data_section[6]);  // offset 24 bytes = index 6
    uint32_t result_v2_24 = data_section[6];
    
    // Test vse16.v v3 at offset 32
    vse16_v3_to_addr(&data_section[8]);  // offset 32 bytes = index 8
    uint32_t result_v3_32 = data_section[8];
    uint32_t result_v3_36 = data_section[9];
    
    // Test vse32.v v4 at offset 40
    vse32_v4_to_addr(&data_section[10]); // offset 40 bytes = index 10
    uint32_t result_v4_40 = data_section[10];
    uint32_t result_v4_44 = data_section[11];
    uint32_t result_v4_48 = data_section[12];
    uint32_t result_v4_52 = data_section[13];
    
    // =============================================================================
    // MISALIGNMENT TESTS
    // =============================================================================
    
    // Test misaligned vse8.v v1 at offset 49 (misaligned by 1 byte)
    uint8_t* misaligned_ptr = (uint8_t*)data_section + 49;
    vse8_v1_to_addr(misaligned_ptr);
    uint32_t result_misaligned_48 = data_section[12];
    uint32_t result_misaligned_52 = data_section[13];
    
    // =============================================================================
    // STRESS TESTS
    // =============================================================================
    
    // Multiple operations to same location
    vse8_v1_to_addr(&data_section[18]);   // offset 72
    vse8_v5_to_addr(&data_section[18]);   // overwrite with v5
    uint32_t result_stress_72 = data_section[18];
    
    // =============================================================================
    // BOUNDARY TESTS
    // =============================================================================
    
    // Test near end of data section
    vse8_v1_to_addr(&data_section[30]);  // offset 120 bytes = index 30
    uint32_t result_boundary_120 = data_section[30];
    
    // Test with maximum vector register v31
    uint8_t* end_ptr = (uint8_t*)data_section + 124;
    vse8_v31_to_addr(end_ptr);
    uint32_t result_v31_124 = data_section[31];
    
    // =============================================================================
    // FINAL VERIFICATION - Load all results for trace visibility
    // =============================================================================
    
    // Load first 16 words for verification
    uint32_t final_results[16];
    for (int i = 0; i < 16; i++) {
        final_results[i] = data_section[i];
    }
    
    // Load boundary results
    uint32_t boundary_120 = data_section[30];
    uint32_t boundary_124 = data_section[31];
    
    // Store key verification values in registers for trace visibility
    register uint32_t verify_reg_0 asm("t0") = final_results[0];   // [0x00]
    register uint32_t verify_reg_1 asm("t1") = final_results[2];   // [0x08]
    register uint32_t verify_reg_2 asm("t2") = final_results[4];   // [0x10]
    register uint32_t verify_reg_3 asm("t3") = final_results[6];   // [0x18]
    register uint32_t verify_reg_4 asm("t4") = final_results[8];   // [0x20]
    register uint32_t verify_reg_5 asm("t5") = final_results[10];  // [0x28]
    register uint32_t verify_reg_6 asm("t6") = boundary_120;       // [0x78]
    register uint32_t verify_reg_7 asm("s2") = boundary_124;       // [0x7C]
    
    // Use the registers to prevent optimization
    asm volatile("" : : "r"(verify_reg_0), "r"(verify_reg_1), "r"(verify_reg_2), "r"(verify_reg_3),
                        "r"(verify_reg_4), "r"(verify_reg_5), "r"(verify_reg_6), "r"(verify_reg_7));
    
    return 0;
}