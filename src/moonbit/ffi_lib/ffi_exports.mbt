// FFI Exports for MoonBit TypeScript Compiler
// C ABI compatible functions for Zig integration
//
// These functions are exported via link configuration in moon.pkg.json
// and can be called from Zig code through C FFI.

///|
/// Opaque result handle for FFI
pub struct CompileResultHandle {
  success : Bool
  javascript : Bytes
  source_map : Bytes
  error_msg : Bytes
}

///|
/// Global result storage for FFI (avoids complex return types)
let ffi_result : Ref[CompileResultHandle?] = Ref::new(None)

///|
/// Compile TypeScript source code to JavaScript
/// Returns: 1 on success, 0 on failure
/// Results can be retrieved using moonbit_tsc_result_* functions
pub fn moonbit_tsc_compile(
  source_ptr : FixedArray[Byte],
  source_len : Int,
  file_path_ptr : FixedArray[Byte],
  file_path_len : Int,
  target : Int,
  source_map : Int,
  declaration : Int,
) -> Int {
  // Convert byte arrays to strings
  let source = bytes_to_string(source_ptr, source_len)
  let file_path = bytes_to_string(file_path_ptr, file_path_len)

  // Build options
  let options : @compiler.CompileOptions = {
    target: int_to_target(target),
    source_map: source_map != 0,
    declaration: declaration != 0,
    strict: false,
  }

  // Compile
  let result = @compiler.compile_source(source, file_path, options)

  // Store result for retrieval
  let handle : CompileResultHandle = {
    success: result.success,
    javascript: string_to_bytes(result.javascript),
    source_map: match result.source_map {
      Some(sm) => string_to_bytes(sm)
      None => Bytes::new(0)
    },
    error_msg: if result.diagnostics.length() > 0 {
      string_to_bytes(@compiler.format_all_diagnostics(result.diagnostics))
    } else {
      Bytes::new(0)
    },
  }
  ffi_result.val = Some(handle)

  if result.success { 1 } else { 0 }
}

///|
/// Parse TypeScript source code (syntax only, no type checking)
/// Returns: 1 on success, 0 on failure
pub fn moonbit_tsc_parse(
  source_ptr : FixedArray[Byte],
  source_len : Int,
  file_path_ptr : FixedArray[Byte],
  file_path_len : Int,
) -> Int {
  let source = bytes_to_string(source_ptr, source_len)
  let file_path = bytes_to_string(file_path_ptr, file_path_len)

  match @compiler.parse_only(source, file_path) {
    Ok(_) => {
      ffi_result.val = Some({
        success: true,
        javascript: Bytes::new(0),
        source_map: Bytes::new(0),
        error_msg: Bytes::new(0),
      })
      1
    }
    Err(diagnostics) => {
      ffi_result.val = Some({
        success: false,
        javascript: Bytes::new(0),
        source_map: Bytes::new(0),
        error_msg: string_to_bytes(@compiler.format_all_diagnostics(diagnostics)),
      })
      0
    }
  }
}

///|
/// Scan TypeScript source code (lexical analysis only)
/// Returns: number of tokens
pub fn moonbit_tsc_scan(
  source_ptr : FixedArray[Byte],
  source_len : Int,
  file_path_ptr : FixedArray[Byte],
  file_path_len : Int,
) -> Int {
  let source = bytes_to_string(source_ptr, source_len)
  let file_path = bytes_to_string(file_path_ptr, file_path_len)
  let tokens = @compiler.scan_only(source, file_path)
  tokens.length()
}

///|
/// Get compiler version (returns pointer to static string)
pub fn moonbit_tsc_get_version() -> FixedArray[Byte] {
  let version = "0.1.0"
  string_to_fixed_array(version)
}

///|
/// Check if last compilation was successful
/// Returns: 1 if successful, 0 otherwise
pub fn moonbit_tsc_result_success() -> Int {
  match ffi_result.val {
    Some(handle) => if handle.success { 1 } else { 0 }
    None => 0
  }
}

///|
/// Get JavaScript output from last compilation
/// Returns: pointer to output bytes
pub fn moonbit_tsc_result_javascript() -> FixedArray[Byte] {
  match ffi_result.val {
    Some(handle) => bytes_to_fixed_array(handle.javascript)
    None => FixedArray::make(0, b'\x00')
  }
}

///|
/// Get length of JavaScript output
pub fn moonbit_tsc_result_javascript_len() -> Int {
  match ffi_result.val {
    Some(handle) => handle.javascript.length()
    None => 0
  }
}

///|
/// Get error message from last compilation
/// Returns: pointer to error bytes
pub fn moonbit_tsc_result_error() -> FixedArray[Byte] {
  match ffi_result.val {
    Some(handle) => bytes_to_fixed_array(handle.error_msg)
    None => FixedArray::make(0, b'\x00')
  }
}

///|
/// Get length of error message
pub fn moonbit_tsc_result_error_len() -> Int {
  match ffi_result.val {
    Some(handle) => handle.error_msg.length()
    None => 0
  }
}

///|
/// Free the result handle (cleanup)
pub fn moonbit_tsc_result_free() -> Unit {
  ffi_result.val = None
}

// ============================================================================
// Helper Functions
// ============================================================================

///|
fn bytes_to_string(ptr : FixedArray[Byte], len : Int) -> String {
  let buf = StringBuilder::new()
  for i = 0; i < len; i = i + 1 {
    buf.write_char(ptr[i].to_int().unsafe_to_char())
  }
  buf.to_string()
}

///|
fn string_to_bytes(s : String) -> Bytes {
  @encoding/utf8.encode(s)
}

///|
fn string_to_fixed_array(s : String) -> FixedArray[Byte] {
  let bytes = @encoding/utf8.encode(s)
  let arr = FixedArray::make(bytes.length(), b'\x00')
  for i = 0; i < bytes.length(); i = i + 1 {
    arr[i] = bytes[i]
  }
  arr
}

///|
fn bytes_to_fixed_array(bytes : Bytes) -> FixedArray[Byte] {
  let arr = FixedArray::make(bytes.length(), b'\x00')
  for i = 0; i < bytes.length(); i = i + 1 {
    arr[i] = bytes[i]
  }
  arr
}

///|
fn int_to_target(t : Int) -> @compiler.Target {
  match t {
    0 => @compiler.Target::ES5
    1 => @compiler.Target::ES2015
    2 => @compiler.Target::ES2016
    3 => @compiler.Target::ES2017
    4 => @compiler.Target::ES2018
    5 => @compiler.Target::ES2019
    6 => @compiler.Target::ES2020
    7 => @compiler.Target::ESNext
    _ => @compiler.Target::ES2015
  }
}
