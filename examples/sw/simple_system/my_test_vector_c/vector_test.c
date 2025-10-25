#include <stdint.h>

// Use functions from simple_system_common.c directly
// No need for external declarations - they're linked in

// Inline assembly wrapper functions for vector stores
static inline void vse8_v1_to_addr(uint32_t* addr) {
    asm volatile(".word 0x000500A7" : : "r"(addr) : "memory");
}

static inline void vse16_v1_to_addr(uint32_t* addr) {
    asm volatile(".word 0x000580A7" : : "r"(addr) : "memory");
}

static inline void vse32_v1_to_addr(uint32_t* addr) {
    asm volatile(".word 0x000650A7" : : "r"(addr) : "memory");
}

static inline void vse8_v2_to_addr(uint32_t* addr) {
    asm volatile(".word 0x00070127" : : "r"(addr) : "memory");
}

static inline void vse16_v3_to_addr(uint32_t* addr) {
    asm volatile(".word 0x0007D1A7" : : "r"(addr) : "memory");
}

static inline void vse32_v4_to_addr(uint32_t* addr) {
    asm volatile(".word 0x00086227" : : "r"(addr) : "memory");
}

static inline void vse8_v5_to_addr(uint32_t* addr) {
    asm volatile(".word 0x000F82A7" : : "r"(addr) : "memory");
}

static inline void vse8_v31_to_addr(uint32_t* addr) {
    asm volatile(".word 0x00048fa7" : : "r"(addr) : "memory");
}

// Test data section - 128 bytes aligned
static uint32_t data_section[32] __attribute__((aligned(128)));

void print_data_word(const char* label, uint32_t value) {
    puts(label);
    puthex(value);
    putchar('\n');
}

void dump_memory_section(uint32_t* base, int start_offset, int count) {
    char label[16];
    for (int i = 0; i < count; i++) {
        int offset = start_offset + (i * 4);
        uint32_t value = base[start_offset/4 + i];
        
        // Format offset as hex string manually (since sprintf not available)
        label[0] = '[';
        label[1] = '0';
        label[2] = 'x';
        label[3] = '0' + ((offset >> 4) & 0xF);
        if (label[3] > '9') label[3] = 'A' + (label[3] - '0' - 10);
        label[4] = '0' + (offset & 0xF);
        if (label[4] > '9') label[4] = 'A' + (label[4] - '0' - 10);
        label[5] = ']';
        label[6] = ':';
        label[7] = ' ';
        label[8] = '0';
        label[9] = 'x';
        label[10] = '\0';
        
        print_data_word(label, value);
    }
}

int main(void) {
    // Initialize data section to zero
    for (int i = 0; i < 32; i++) {
        data_section[i] = 0;
    }
    
        puts("\n=== VECTOR STORE TEST SUITE (C VERSION) ===\n");
    
    // =============================================================================
    // SCALAR REFERENCE TESTS
    // =============================================================================
    puts("1. Scalar Reference Tests:");
    
    // Normal aligned scalar store
    data_section[0] = 0x12345678;
    puts("   Aligned scalar store: data_section[0] = 0x12345678");
    
    // Misaligned scalar store (simulate with byte pointer)
    uint8_t* byte_ptr = (uint8_t*)data_section;
    uint32_t misaligned_value = 0xABCDEF00;
    byte_ptr[1] = misaligned_value & 0xFF;
    byte_ptr[2] = (misaligned_value >> 8) & 0xFF;
    byte_ptr[3] = (misaligned_value >> 16) & 0xFF;
    byte_ptr[4] = (misaligned_value >> 24) & 0xFF;
    puts("   Misaligned scalar store: at offset 1");
    
    puts("   Memory after scalar tests:");
    dump_memory_section(data_section, 0, 2);
    
    // =============================================================================
    // BASIC VECTOR STORE TESTS
    // =============================================================================
    puts("\n2. Basic Vector Store Tests:");
    
    // Test vse8.v v1 - aligned
    puts("   Testing vse8.v v1 at offset 0 (aligned)");
    vse8_v1_to_addr(&data_section[0]);
    print_data_word("   Result [0x00]: 0x", data_section[0]);
    
    // Test vse16.v v1 - aligned at offset 8
    puts("   Testing vse16.v v1 at offset 8 (aligned)");
    vse16_v1_to_addr(&data_section[2]);  // offset 8 bytes = index 2
    print_data_word("   Result [0x08]: 0x", data_section[2]);
    print_data_word("   Result [0x0C]: 0x", data_section[3]);
    
    // Test vse32.v v1 - aligned at offset 16
    puts("   Testing vse32.v v1 at offset 16 (aligned)");
    vse32_v1_to_addr(&data_section[4]);  // offset 16 bytes = index 4
    print_data_word("   Result [0x10]: 0x", data_section[4]);
    print_data_word("   Result [0x14]: 0x", data_section[5]);
    print_data_word("   Result [0x18]: 0x", data_section[6]);
    print_data_word("   Result [0x1C]: 0x", data_section[7]);
    
    // =============================================================================
    // DIFFERENT VECTOR REGISTERS
    // =============================================================================
    puts("\n3. Different Vector Register Tests:");
    
    // Test vse8.v v2 at offset 24
    puts("   Testing vse8.v v2 at offset 24");
    vse8_v2_to_addr(&data_section[6]);  // offset 24 bytes = index 6
    print_data_word("   v2 Result [0x18]: 0x", data_section[6]);
    
    // Test vse16.v v3 at offset 32
    puts("   Testing vse16.v v3 at offset 32");
    vse16_v3_to_addr(&data_section[8]);  // offset 32 bytes = index 8
    print_data_word("   v3 Result [0x20]: 0x", data_section[8]);
    print_data_word("   v3 Result [0x24]: 0x", data_section[9]);
    
    // Test vse32.v v4 at offset 40
    puts("   Testing vse32.v v4 at offset 40");
    vse32_v4_to_addr(&data_section[10]); // offset 40 bytes = index 10
    print_data_word("   v4 Result [0x28]: 0x", data_section[10]);
    print_data_word("   v4 Result [0x2C]: 0x", data_section[11]);
    print_data_word("   v4 Result [0x30]: 0x", data_section[12]);
    print_data_word("   v4 Result [0x34]: 0x", data_section[13]);
    
    // =============================================================================
    // MISALIGNMENT TESTS
    // =============================================================================
    puts("\n4. Misalignment Tests:");
    
    // Test misaligned vse8.v v1 at offset 49 (misaligned by 1 byte)
    puts("   Testing misaligned vse8.v v1 at offset 49");
    uint8_t* misaligned_ptr = (uint8_t*)data_section + 49;
    vse8_v1_to_addr((uint32_t*)misaligned_ptr);
    print_data_word("   Misaligned [0x30]: 0x", data_section[12]);
    print_data_word("   Misaligned [0x34]: 0x", data_section[13]);
    
    // =============================================================================
    // STRESS TESTS
    // =============================================================================
    puts("\n5. Stress Tests:");
    
    // Multiple operations to same location
    puts("   Multiple vse operations to same address (overwrite test)");
    vse8_v1_to_addr(&data_section[18]);   // offset 72
    vse8_v5_to_addr(&data_section[18]);   // overwrite with v5
    print_data_word("   Final [0x48]: 0x", data_section[18]);
    
    // =============================================================================
    // BOUNDARY TESTS
    // =============================================================================
    puts("\n6. Boundary Tests:");
    
    // Test near end of data section
    puts("   Testing vse8.v v1 near end (offset 120)");
    vse8_v1_to_addr(&data_section[30]);  // offset 120 bytes = index 30
    print_data_word("   Boundary [0x78]: 0x", data_section[30]);
    
    // Test with maximum vector register v31
    puts("   Testing vse8.v v31 at end (offset 124)");
    uint8_t* end_ptr = (uint8_t*)data_section + 124;
    vse8_v31_to_addr((uint32_t*)end_ptr);
    print_data_word("   v31 [0x7C]: 0x", data_section[31]);
    
    // =============================================================================
    // FINAL MEMORY DUMP
    // =============================================================================
    puts("\n=== FINAL MEMORY DUMP (First 16 words) ===");
    dump_memory_section(data_section, 0, 16);
    
    puts("\n=== VECTOR STORE TEST COMPLETED ===");
    
    return 0;
}