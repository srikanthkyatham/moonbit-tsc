// MoonBit TypeScript Compiler - C FFI Interface
// Header file for Zig integration
#ifndef MOONBIT_TSC_H
#define MOONBIT_TSC_H

#include <stdint.h>

#ifdef __cplusplus
extern "C" {
#endif

// Initialize the MoonBit runtime (must be called once before any other function)
void moonbit_tsc_init(void);

// Compile TypeScript source to JavaScript
// Returns: 1 on success, 0 on failure
// Use moonbit_tsc_result_* functions to retrieve the result
int32_t moonbit_tsc_compile(
    const char* source, int32_t source_len,
    const char* file_path, int32_t file_path_len,
    int32_t target,      // 0=ES5, 1=ES2015, ..., 7=ESNext
    int32_t source_map,  // 0=false, 1=true
    int32_t declaration  // 0=false, 1=true
);

// Parse TypeScript source (syntax check only)
// Returns: 1 on success, 0 on failure
int32_t moonbit_tsc_parse(
    const char* source, int32_t source_len,
    const char* file_path, int32_t file_path_len
);

// Scan TypeScript source (lexical analysis only)
// Returns: number of tokens
int32_t moonbit_tsc_scan(
    const char* source, int32_t source_len,
    const char* file_path, int32_t file_path_len
);

// Get compiler version string
const char* moonbit_tsc_get_version(void);

// Result retrieval functions
int32_t moonbit_tsc_result_success(void);
const char* moonbit_tsc_result_javascript(void);
int32_t moonbit_tsc_result_javascript_len(void);
const char* moonbit_tsc_result_error(void);
int32_t moonbit_tsc_result_error_len(void);

// Free the current result (call after retrieving results)
void moonbit_tsc_result_free(void);

#ifdef __cplusplus
}
#endif

#endif // MOONBIT_TSC_H
