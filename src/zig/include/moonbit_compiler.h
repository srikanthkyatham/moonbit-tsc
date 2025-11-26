// FFI Header for MoonBit TypeScript Compiler
// Defines C ABI interface between Zig and MoonBit
//
// NOTE: MoonBit exports functions with mangled names based on module paths.
// The mangled names use URL-encoding (e.g., - becomes $2d$).
// We use __asm__ labels to map clean names to mangled symbols.

#ifndef MOONBIT_COMPILER_H
#define MOONBIT_COMPILER_H

#include <stddef.h>
#include <stdint.h>

#ifdef __cplusplus
extern "C" {
#endif

// ============================================================================
// MoonBit Types (opaque pointers)
// ============================================================================

typedef void* MBFixedArrayByte;  // MoonBit FixedArray[Byte]
typedef void* MBBytes;           // MoonBit Bytes

// ============================================================================
// Target ECMAScript Versions
// ============================================================================

typedef enum {
    MB_TARGET_ES5     = 0,
    MB_TARGET_ES2015  = 1,
    MB_TARGET_ES2016  = 2,
    MB_TARGET_ES2017  = 3,
    MB_TARGET_ES2018  = 4,
    MB_TARGET_ES2019  = 5,
    MB_TARGET_ES2020  = 6,
    MB_TARGET_ESNEXT  = 7
} MBTarget;

// ============================================================================
// Core Compilation Functions
// ============================================================================

// Compile TypeScript source to JavaScript
// Parameters:
//   source_ptr, source_len: Source code as FixedArray[Byte]
//   file_path_ptr, file_path_len: File path as FixedArray[Byte]
//   target: Target ECMAScript version (MBTarget enum)
//   source_map: Generate source map (0=false, 1=true)
//   declaration: Generate .d.ts (0=false, 1=true)
// Returns: 1 on success, 0 on failure
// Call mb_result_* functions to retrieve results
int32_t mb_compile(
    MBFixedArrayByte source_ptr, int32_t source_len,
    MBFixedArrayByte file_path_ptr, int32_t file_path_len,
    int32_t target, int32_t source_map, int32_t declaration
) __asm__("_$moonbit$2d$ts$2d$compiler$ffi_lib$moonbit_tsc_compile");

// Parse TypeScript source (syntax check only, no type checking)
// Returns: 1 on success, 0 on failure
int32_t mb_parse(
    MBFixedArrayByte source_ptr, int32_t source_len,
    MBFixedArrayByte file_path_ptr, int32_t file_path_len
) __asm__("_$moonbit$2d$ts$2d$compiler$ffi_lib$moonbit_tsc_parse");

// Scan TypeScript source (lexical analysis only)
// Returns: number of tokens
int32_t mb_scan(
    MBFixedArrayByte source_ptr, int32_t source_len,
    MBFixedArrayByte file_path_ptr, int32_t file_path_len
) __asm__("_$moonbit$2d$ts$2d$compiler$ffi_lib$moonbit_tsc_scan");

// ============================================================================
// Result Retrieval Functions
// ============================================================================

// Get compiler version string (returns FixedArray[Byte])
MBFixedArrayByte mb_get_version(void)
    __asm__("_$moonbit$2d$ts$2d$compiler$ffi_lib$moonbit_tsc_get_version");

// Check if last compilation was successful
// Returns: 1 if successful, 0 otherwise
int32_t mb_result_success(void)
    __asm__("_$moonbit$2d$ts$2d$compiler$ffi_lib$moonbit_tsc_result_success");

// Get JavaScript output from last compilation
// Returns: FixedArray[Byte] pointer (data starts at pointer)
MBFixedArrayByte mb_result_javascript(void)
    __asm__("_$moonbit$2d$ts$2d$compiler$ffi_lib$moonbit_tsc_result_javascript");

// Get length of JavaScript output
int32_t mb_result_javascript_len(void)
    __asm__("_$moonbit$2d$ts$2d$compiler$ffi_lib$moonbit_tsc_result_javascript_len");

// Get error message from last compilation
// Returns: FixedArray[Byte] pointer
MBFixedArrayByte mb_result_error(void)
    __asm__("_$moonbit$2d$ts$2d$compiler$ffi_lib$moonbit_tsc_result_error");

// Get length of error message
int32_t mb_result_error_len(void)
    __asm__("_$moonbit$2d$ts$2d$compiler$ffi_lib$moonbit_tsc_result_error_len");

// Free the current result (call after retrieving results)
void mb_result_free(void)
    __asm__("_$moonbit$2d$ts$2d$compiler$ffi_lib$moonbit_tsc_result_free");

// ============================================================================
// MoonBit Runtime Functions
// ============================================================================

// Initialize MoonBit runtime (must be called once before any other function)
void moonbit_runtime_init(int argc, char** argv);

// Allocate MoonBit FixedArray
// kind: MOONBIT_BLOCK_KIND_FIXED_ARRAY (2)
// elem_size_shift: 0 for bytes (2^0 = 1 byte)
// len: number of elements
void* moonbit_malloc_array(int kind, int elem_size_shift, int32_t len);

#define MOONBIT_BLOCK_KIND_FIXED_ARRAY 2

// ============================================================================
// Helper Macros
// ============================================================================

// Create a MoonBit FixedArray[Byte] from C data
static inline MBFixedArrayByte mb_make_bytes(const char* data, int32_t len) {
    void* arr = moonbit_malloc_array(MOONBIT_BLOCK_KIND_FIXED_ARRAY, 0, len);
    if (arr && data) {
        for (int32_t i = 0; i < len; i++) {
            ((char*)arr)[i] = data[i];
        }
    }
    return arr;
}

// Extract C string pointer from MoonBit FixedArray[Byte]
static inline const char* mb_get_cstr(MBFixedArrayByte arr) {
    return (const char*)arr;
}

#ifdef __cplusplus
}
#endif

#endif // MOONBIT_COMPILER_H
