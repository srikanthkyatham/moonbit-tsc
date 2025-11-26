// MoonBit FFI Bindings for Zig
// Provides high-level Zig interface to the MoonBit TypeScript compiler
//
// Usage:
//   const mbt = @import("moonbit_ffi.zig");
//   mbt.init();
//   defer mbt.deinit();
//   const result = mbt.compile(source, file_path, .es2015, false, false);
//

const std = @import("std");

/// Target ECMAScript versions
pub const Target = enum(i32) {
    es5 = 0,
    es2015 = 1,
    es2016 = 2,
    es2017 = 3,
    es2018 = 4,
    es2019 = 5,
    es2020 = 6,
    esnext = 7,

    pub fn fromString(s: []const u8) ?Target {
        const map = std.StaticStringMap(Target).initComptime(.{
            .{ "es5", .es5 },
            .{ "es2015", .es2015 },
            .{ "es6", .es2015 },
            .{ "es2016", .es2016 },
            .{ "es7", .es2016 },
            .{ "es2017", .es2017 },
            .{ "es2018", .es2018 },
            .{ "es2019", .es2019 },
            .{ "es2020", .es2020 },
            .{ "esnext", .esnext },
            .{ "latest", .esnext },
        });
        return map.get(s);
    }
};

/// MoonBit FixedArray[Byte] - opaque pointer
const MBFixedArrayByte = ?*anyopaque;

/// Compilation result
pub const CompileResult = struct {
    success: bool,
    javascript: ?[]const u8,
    error_message: ?[]const u8,

    pub fn deinit(self: *CompileResult) void {
        // Call MoonBit to free the result
        mb_result_free();
        self.* = .{
            .success = false,
            .javascript = null,
            .error_message = null,
        };
    }
};

// ============================================================================
// External FFI Functions (MoonBit library)
// ============================================================================

// Note: These symbol names are mangled by MoonBit.
// The actual symbols have URL-encoded package paths.

extern fn moonbit_runtime_init(argc: c_int, argv: ?[*]?[*:0]u8) void;
extern fn moonbit_malloc_array(kind: c_int, elem_size_shift: c_int, len: i32) ?*anyopaque;

// We need to use comptime string manipulation to reference the mangled names
// Since Zig doesn't support __asm__ labels, we'll use dynamic linking

// Mangled symbol names from MoonBit
const MB_COMPILE = "$moonbit$2d$ts$2d$compiler$ffi_lib$moonbit_tsc_compile";
const MB_PARSE = "$moonbit$2d$ts$2d$compiler$ffi_lib$moonbit_tsc_parse";
const MB_SCAN = "$moonbit$2d$ts$2d$compiler$ffi_lib$moonbit_tsc_scan";
const MB_GET_VERSION = "$moonbit$2d$ts$2d$compiler$ffi_lib$moonbit_tsc_get_version";
const MB_RESULT_SUCCESS = "$moonbit$2d$ts$2d$compiler$ffi_lib$moonbit_tsc_result_success";
const MB_RESULT_JAVASCRIPT = "$moonbit$2d$ts$2d$compiler$ffi_lib$moonbit_tsc_result_javascript";
const MB_RESULT_JAVASCRIPT_LEN = "$moonbit$2d$ts$2d$compiler$ffi_lib$moonbit_tsc_result_javascript_len";
const MB_RESULT_ERROR = "$moonbit$2d$ts$2d$compiler$ffi_lib$moonbit_tsc_result_error";
const MB_RESULT_ERROR_LEN = "$moonbit$2d$ts$2d$compiler$ffi_lib$moonbit_tsc_result_error_len";
const MB_RESULT_FREE = "$moonbit$2d$ts$2d$compiler$ffi_lib$moonbit_tsc_result_free";

// Direct FFI declarations using mangled names
extern fn @"$moonbit$2d$ts$2d$compiler$ffi_lib$moonbit_tsc_compile"(
    source_ptr: MBFixedArrayByte,
    source_len: i32,
    file_path_ptr: MBFixedArrayByte,
    file_path_len: i32,
    target: i32,
    source_map: i32,
    declaration: i32,
) i32;

extern fn @"$moonbit$2d$ts$2d$compiler$ffi_lib$moonbit_tsc_parse"(
    source_ptr: MBFixedArrayByte,
    source_len: i32,
    file_path_ptr: MBFixedArrayByte,
    file_path_len: i32,
) i32;

extern fn @"$moonbit$2d$ts$2d$compiler$ffi_lib$moonbit_tsc_scan"(
    source_ptr: MBFixedArrayByte,
    source_len: i32,
    file_path_ptr: MBFixedArrayByte,
    file_path_len: i32,
) i32;

extern fn @"$moonbit$2d$ts$2d$compiler$ffi_lib$moonbit_tsc_get_version"() MBFixedArrayByte;
extern fn @"$moonbit$2d$ts$2d$compiler$ffi_lib$moonbit_tsc_result_success"() i32;
extern fn @"$moonbit$2d$ts$2d$compiler$ffi_lib$moonbit_tsc_result_javascript"() MBFixedArrayByte;
extern fn @"$moonbit$2d$ts$2d$compiler$ffi_lib$moonbit_tsc_result_javascript_len"() i32;
extern fn @"$moonbit$2d$ts$2d$compiler$ffi_lib$moonbit_tsc_result_error"() MBFixedArrayByte;
extern fn @"$moonbit$2d$ts$2d$compiler$ffi_lib$moonbit_tsc_result_error_len"() i32;
extern fn @"$moonbit$2d$ts$2d$compiler$ffi_lib$moonbit_tsc_result_free"() void;

// Wrappers using clean names
fn mb_compile(
    source_ptr: MBFixedArrayByte,
    source_len: i32,
    file_path_ptr: MBFixedArrayByte,
    file_path_len: i32,
    target: i32,
    source_map: i32,
    declaration: i32,
) i32 {
    return @"$moonbit$2d$ts$2d$compiler$ffi_lib$moonbit_tsc_compile"(
        source_ptr,
        source_len,
        file_path_ptr,
        file_path_len,
        target,
        source_map,
        declaration,
    );
}

fn mb_parse(
    source_ptr: MBFixedArrayByte,
    source_len: i32,
    file_path_ptr: MBFixedArrayByte,
    file_path_len: i32,
) i32 {
    return @"$moonbit$2d$ts$2d$compiler$ffi_lib$moonbit_tsc_parse"(
        source_ptr,
        source_len,
        file_path_ptr,
        file_path_len,
    );
}

fn mb_scan(
    source_ptr: MBFixedArrayByte,
    source_len: i32,
    file_path_ptr: MBFixedArrayByte,
    file_path_len: i32,
) i32 {
    return @"$moonbit$2d$ts$2d$compiler$ffi_lib$moonbit_tsc_scan"(
        source_ptr,
        source_len,
        file_path_ptr,
        file_path_len,
    );
}

fn mb_get_version() MBFixedArrayByte {
    return @"$moonbit$2d$ts$2d$compiler$ffi_lib$moonbit_tsc_get_version"();
}

fn mb_result_success() i32 {
    return @"$moonbit$2d$ts$2d$compiler$ffi_lib$moonbit_tsc_result_success"();
}

fn mb_result_javascript() MBFixedArrayByte {
    return @"$moonbit$2d$ts$2d$compiler$ffi_lib$moonbit_tsc_result_javascript"();
}

fn mb_result_javascript_len() i32 {
    return @"$moonbit$2d$ts$2d$compiler$ffi_lib$moonbit_tsc_result_javascript_len"();
}

fn mb_result_error() MBFixedArrayByte {
    return @"$moonbit$2d$ts$2d$compiler$ffi_lib$moonbit_tsc_result_error"();
}

fn mb_result_error_len() i32 {
    return @"$moonbit$2d$ts$2d$compiler$ffi_lib$moonbit_tsc_result_error_len"();
}

fn mb_result_free() void {
    @"$moonbit$2d$ts$2d$compiler$ffi_lib$moonbit_tsc_result_free"();
}

// ============================================================================
// State Management
// ============================================================================

var initialized: bool = false;

/// Initialize MoonBit runtime (must be called once)
pub fn init() void {
    if (!initialized) {
        moonbit_runtime_init(0, null);
        initialized = true;
    }
}

/// Deinitialize (currently a no-op)
pub fn deinit() void {
    // MoonBit runtime doesn't have explicit shutdown
}

// ============================================================================
// Helper Functions
// ============================================================================

const MOONBIT_BLOCK_KIND_FIXED_ARRAY: c_int = 2;

/// Create MoonBit FixedArray[Byte] from Zig slice
fn makeBytes(data: []const u8) MBFixedArrayByte {
    const arr = moonbit_malloc_array(MOONBIT_BLOCK_KIND_FIXED_ARRAY, 0, @intCast(data.len));
    if (arr) |ptr| {
        const dest: [*]u8 = @ptrCast(ptr);
        @memcpy(dest[0..data.len], data);
    }
    return arr;
}

/// Extract Zig slice from MoonBit FixedArray[Byte]
fn getSlice(arr: MBFixedArrayByte, len: i32) ?[]const u8 {
    if (arr) |ptr| {
        if (len > 0) {
            const data: [*]const u8 = @ptrCast(ptr);
            return data[0..@intCast(len)];
        }
    }
    return null;
}

// ============================================================================
// Public API
// ============================================================================

/// Compile TypeScript source to JavaScript
pub fn compile(
    source: []const u8,
    file_path: []const u8,
    target: Target,
    source_map: bool,
    declaration: bool,
) CompileResult {
    init();

    // Create MoonBit byte arrays
    const src = makeBytes(source);
    const path = makeBytes(file_path);

    // Call MoonBit compiler
    const result = mb_compile(
        src,
        @intCast(source.len),
        path,
        @intCast(file_path.len),
        @intFromEnum(target),
        if (source_map) @as(i32, 1) else @as(i32, 0),
        if (declaration) @as(i32, 1) else @as(i32, 0),
    );

    // Build result
    const success = result != 0;
    const js_len = mb_result_javascript_len();
    const err_len = mb_result_error_len();

    return CompileResult{
        .success = success,
        .javascript = if (success) getSlice(mb_result_javascript(), js_len) else null,
        .error_message = if (!success) getSlice(mb_result_error(), err_len) else null,
    };
}

/// Parse TypeScript source (syntax check only)
pub fn parse(source: []const u8, file_path: []const u8) bool {
    init();

    const src = makeBytes(source);
    const path = makeBytes(file_path);

    const result = mb_parse(
        src,
        @intCast(source.len),
        path,
        @intCast(file_path.len),
    );

    return result != 0;
}

/// Scan TypeScript source (lexical analysis)
pub fn scan(source: []const u8, file_path: []const u8) u32 {
    init();

    const src = makeBytes(source);
    const path = makeBytes(file_path);

    const result = mb_scan(
        src,
        @intCast(source.len),
        path,
        @intCast(file_path.len),
    );

    return if (result >= 0) @intCast(result) else 0;
}

/// Get compiler version
pub fn getVersion() []const u8 {
    init();
    const arr = mb_get_version();
    // Version is a constant, we can return a static slice
    // Assuming version is "0.1.0" (5 bytes)
    if (arr) |ptr| {
        const data: [*]const u8 = @ptrCast(ptr);
        return data[0..5];
    }
    return "0.0.0";
}

// ============================================================================
// Tests
// ============================================================================

test "target parsing" {
    try std.testing.expect(Target.fromString("es5") == .es5);
    try std.testing.expect(Target.fromString("es2015") == .es2015);
    try std.testing.expect(Target.fromString("es6") == .es2015);
    try std.testing.expect(Target.fromString("esnext") == .esnext);
    try std.testing.expect(Target.fromString("invalid") == null);
}
