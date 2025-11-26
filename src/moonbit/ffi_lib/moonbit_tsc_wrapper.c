// MoonBit TypeScript Compiler - C FFI Wrapper
// Provides clean C interface over MoonBit-generated mangled names

#include "moonbit_tsc.h"
#include <stdint.h>
#include <string.h>

// MoonBit types (forward declarations to match generated code)
typedef void* moonbit_bytes_t;
typedef void* moonbit_fixedarray_t;

// MoonBit runtime functions
extern void moonbit_runtime_init(int argc, char** argv);
extern moonbit_bytes_t moonbit_make_bytes(int32_t len);

// Forward declarations of MoonBit-generated functions (mangled names)
// The $ characters in the names are URL-encoded module paths
extern int32_t moonbit_tsc_compile_impl(
    moonbit_fixedarray_t source_ptr, int32_t source_len,
    moonbit_fixedarray_t file_path_ptr, int32_t file_path_len,
    int32_t target, int32_t source_map, int32_t declaration)
    __asm__("$moonbit$2d$ts$2d$compiler$ffi_lib$moonbit_tsc_compile");

extern int32_t moonbit_tsc_parse_impl(
    moonbit_fixedarray_t source_ptr, int32_t source_len,
    moonbit_fixedarray_t file_path_ptr, int32_t file_path_len)
    __asm__("$moonbit$2d$ts$2d$compiler$ffi_lib$moonbit_tsc_parse");

extern int32_t moonbit_tsc_scan_impl(
    moonbit_fixedarray_t source_ptr, int32_t source_len,
    moonbit_fixedarray_t file_path_ptr, int32_t file_path_len)
    __asm__("$moonbit$2d$ts$2d$compiler$ffi_lib$moonbit_tsc_scan");

extern moonbit_fixedarray_t moonbit_tsc_get_version_impl(void)
    __asm__("$moonbit$2d$ts$2d$compiler$ffi_lib$moonbit_tsc_get_version");

extern int32_t moonbit_tsc_result_success_impl(void)
    __asm__("$moonbit$2d$ts$2d$compiler$ffi_lib$moonbit_tsc_result_success");

extern moonbit_fixedarray_t moonbit_tsc_result_javascript_impl(void)
    __asm__("$moonbit$2d$ts$2d$compiler$ffi_lib$moonbit_tsc_result_javascript");

extern int32_t moonbit_tsc_result_javascript_len_impl(void)
    __asm__("$moonbit$2d$ts$2d$compiler$ffi_lib$moonbit_tsc_result_javascript_len");

extern moonbit_fixedarray_t moonbit_tsc_result_error_impl(void)
    __asm__("$moonbit$2d$ts$2d$compiler$ffi_lib$moonbit_tsc_result_error");

extern int32_t moonbit_tsc_result_error_len_impl(void)
    __asm__("$moonbit$2d$ts$2d$compiler$ffi_lib$moonbit_tsc_result_error_len");

extern int32_t moonbit_tsc_result_free_impl(void)
    __asm__("$moonbit$2d$ts$2d$compiler$ffi_lib$moonbit_tsc_result_free");

// MoonBit memory allocation (from generated code)
extern void* moonbit_malloc_array(int kind, int elem_size_shift, int32_t len);

// Constants from MoonBit runtime
#define MOONBIT_BLOCK_KIND_FIXED_ARRAY 2

static int moonbit_initialized = 0;

void moonbit_tsc_init(void) {
    if (!moonbit_initialized) {
        moonbit_runtime_init(0, (char**)0);
        moonbit_initialized = 1;
    }
}

// Helper to create MoonBit FixedArray[Byte] from C buffer
static moonbit_fixedarray_t make_fixed_array_bytes(const char* data, int32_t len) {
    // Allocate a MoonBit FixedArray[Byte]
    // elem_size_shift = 0 for bytes (1 byte = 2^0)
    moonbit_fixedarray_t arr = moonbit_malloc_array(MOONBIT_BLOCK_KIND_FIXED_ARRAY, 0, len);
    if (arr && data) {
        memcpy(arr, data, len);
    }
    return arr;
}

// Helper to extract C string from MoonBit FixedArray[Byte]
static const char* fixedarray_to_cstr(moonbit_fixedarray_t arr) {
    // MoonBit FixedArray data starts directly at the pointer
    return (const char*)arr;
}

int32_t moonbit_tsc_compile(
    const char* source, int32_t source_len,
    const char* file_path, int32_t file_path_len,
    int32_t target, int32_t source_map, int32_t declaration
) {
    moonbit_tsc_init();
    moonbit_fixedarray_t src = make_fixed_array_bytes(source, source_len);
    moonbit_fixedarray_t path = make_fixed_array_bytes(file_path, file_path_len);
    return moonbit_tsc_compile_impl(src, source_len, path, file_path_len, target, source_map, declaration);
}

int32_t moonbit_tsc_parse(
    const char* source, int32_t source_len,
    const char* file_path, int32_t file_path_len
) {
    moonbit_tsc_init();
    moonbit_fixedarray_t src = make_fixed_array_bytes(source, source_len);
    moonbit_fixedarray_t path = make_fixed_array_bytes(file_path, file_path_len);
    return moonbit_tsc_parse_impl(src, source_len, path, file_path_len);
}

int32_t moonbit_tsc_scan(
    const char* source, int32_t source_len,
    const char* file_path, int32_t file_path_len
) {
    moonbit_tsc_init();
    moonbit_fixedarray_t src = make_fixed_array_bytes(source, source_len);
    moonbit_fixedarray_t path = make_fixed_array_bytes(file_path, file_path_len);
    return moonbit_tsc_scan_impl(src, source_len, path, file_path_len);
}

const char* moonbit_tsc_get_version(void) {
    moonbit_tsc_init();
    moonbit_fixedarray_t arr = moonbit_tsc_get_version_impl();
    return fixedarray_to_cstr(arr);
}

int32_t moonbit_tsc_result_success(void) {
    return moonbit_tsc_result_success_impl();
}

const char* moonbit_tsc_result_javascript(void) {
    moonbit_fixedarray_t arr = moonbit_tsc_result_javascript_impl();
    return fixedarray_to_cstr(arr);
}

int32_t moonbit_tsc_result_javascript_len(void) {
    return moonbit_tsc_result_javascript_len_impl();
}

const char* moonbit_tsc_result_error(void) {
    moonbit_fixedarray_t arr = moonbit_tsc_result_error_impl();
    return fixedarray_to_cstr(arr);
}

int32_t moonbit_tsc_result_error_len(void) {
    return moonbit_tsc_result_error_len_impl();
}

void moonbit_tsc_result_free(void) {
    moonbit_tsc_result_free_impl();
}
