// FFI Header for MoonBit Compiler
// Defines C ABI interface between Zig and MoonBit

#ifndef MOONBIT_COMPILER_H
#define MOONBIT_COMPILER_H

#include <stddef.h>
#include <stdint.h>
#include <stdbool.h>

#ifdef __cplusplus
extern "C" {
#endif

// ============================================================================
// Opaque Types
// ============================================================================

// Core types (opaque pointers to MoonBit data structures)
typedef struct MBSourceFile MBSourceFile;
typedef struct MBToken MBToken;
typedef struct MBTokenArray MBTokenArray;
typedef struct MBDiagnostic MBDiagnostic;
typedef struct MBDiagnosticArray MBDiagnosticArray;
typedef struct MBTypeChecker MBTypeChecker;
typedef struct MBProgram MBProgram;
typedef struct MBModuleGraph MBModuleGraph;

// ============================================================================
// Structures with C ABI
// ============================================================================

// Position in source file
typedef struct {
    int32_t line;
    int32_t column;
    int32_t offset;
} MBPosition;

// Source location
typedef struct {
    const char* file_path;
    size_t file_path_len;
    MBPosition start;
    MBPosition end;
} MBSourceLocation;

// Diagnostic category
typedef enum {
    MB_DIAG_ERROR = 0,
    MB_DIAG_WARNING = 1,
    MB_DIAG_MESSAGE = 2,
    MB_DIAG_SUGGESTION = 3
} MBDiagnosticCategory;

// Diagnostic (for returning to Zig)
typedef struct {
    const char* message;
    size_t message_len;
    MBSourceLocation location;
    MBDiagnosticCategory category;
    int32_t code;
} MBDiagnosticData;

// Compilation result
typedef struct {
    bool success;
    MBDiagnosticArray* diagnostics;
} MBCompileResult;

// Emit result
typedef struct {
    bool success;
    const char* javascript;
    size_t javascript_len;
    const char* source_map;
    size_t source_map_len;
    const char* declaration;
    size_t declaration_len;
} MBEmitResult;

// Compiler options
typedef struct {
    const char* target;  // "es5", "es2015", "esnext", etc.
    bool strict;
    bool no_implicit_any;
    bool source_map;
    bool declaration;
    bool incremental;
    // Add more options as needed
} MBCompilerOptions;

// ============================================================================
// Scanner Functions
// ============================================================================

// Scan source file into tokens
// Returns: Array of tokens (caller must free with mb_destroy_token_array)
MBTokenArray* mb_scan_source(
    const char* source,
    size_t source_len,
    const char* file_path,
    size_t file_path_len
);

// Get token count from array
size_t mb_token_array_length(const MBTokenArray* tokens);

// Get token at index (for debugging)
const char* mb_token_to_string(const MBTokenArray* tokens, size_t index);

// Destroy token array
void mb_destroy_token_array(MBTokenArray* tokens);

// ============================================================================
// Parser Functions
// ============================================================================

// Parse source file
// Returns: Parsed AST (caller must free with mb_destroy_source_file)
MBSourceFile* mb_parse_source(
    const char* source,
    size_t source_len,
    const char* file_path,
    size_t file_path_len,
    MBCompilerOptions* options
);

// Async version for use with MoonBit's async runtime
// Note: This will integrate with Zig's async system
MBSourceFile* mb_parse_source_async(
    const char* source,
    size_t source_len,
    const char* file_path,
    size_t file_path_len,
    MBCompilerOptions* options
);

// Destroy parsed source file
void mb_destroy_source_file(MBSourceFile* file);

// ============================================================================
// Binder Functions
// ============================================================================

// Bind source file (symbol resolution)
MBCompileResult mb_bind_source_file(
    MBSourceFile* file,
    MBProgram* program
);

// ============================================================================
// Type Checker Functions
// ============================================================================

// Create type checker
MBTypeChecker* mb_create_type_checker(MBCompilerOptions* options);

// Type check a source file
MBCompileResult mb_check_source_file(
    MBSourceFile* file,
    MBTypeChecker* checker
);

// Destroy type checker
void mb_destroy_type_checker(MBTypeChecker* checker);

// ============================================================================
// Transformer & Emitter Functions
// ============================================================================

// Transform and emit source file
MBEmitResult mb_emit_source_file(
    MBSourceFile* file,
    MBCompilerOptions* options
);

// Async version
MBEmitResult mb_emit_source_file_async(
    MBSourceFile* file,
    MBCompilerOptions* options
);

// ============================================================================
// Program & Module Resolution Functions
// ============================================================================

// Create program
MBProgram* mb_create_program(
    const char** root_files,
    size_t root_files_count,
    MBCompilerOptions* options
);

// Resolve module graph (async)
MBModuleGraph* mb_resolve_modules_async(
    const char** root_files,
    size_t root_files_count,
    MBCompilerOptions* options
);

// Get files from module graph
size_t mb_module_graph_file_count(const MBModuleGraph* graph);
const char* mb_module_graph_get_file(const MBModuleGraph* graph, size_t index);

// Destroy module graph
void mb_destroy_module_graph(MBModuleGraph* graph);

// Destroy program
void mb_destroy_program(MBProgram* program);

// ============================================================================
// Diagnostic Functions
// ============================================================================

// Get diagnostic count
size_t mb_diagnostic_array_length(const MBDiagnosticArray* diagnostics);

// Get diagnostic at index
MBDiagnosticData mb_get_diagnostic(
    const MBDiagnosticArray* diagnostics,
    size_t index
);

// Destroy diagnostic array
void mb_destroy_diagnostic_array(MBDiagnosticArray* diagnostics);

// ============================================================================
// Language Service Functions (for future TSServer)
// ============================================================================

// Get completions at position
typedef struct MBCompletionList MBCompletionList;

MBCompletionList* mb_get_completions(
    MBProgram* program,
    const char* file_path,
    size_t file_path_len,
    int32_t line,
    int32_t column
);

void mb_destroy_completion_list(MBCompletionList* completions);

// ============================================================================
// Utility Functions
// ============================================================================

// Initialize MoonBit runtime (call once at startup)
void mb_init_runtime(void);

// Shutdown MoonBit runtime (call at exit)
void mb_shutdown_runtime(void);

// Get version string
const char* mb_get_version(void);

#ifdef __cplusplus
}
#endif

#endif // MOONBIT_COMPILER_H
