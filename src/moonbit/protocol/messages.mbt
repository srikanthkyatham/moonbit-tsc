// Protocol message types for worker communication
// Uses newline-delimited JSON over stdin/stdout

///|
/// Request sent from coordinator to worker
pub(all) struct CompileRequest {
  file_path : String
  source : String
  target : String
  module_kind : String // "esmodule" or "commonjs"
  source_map : Bool
  inline_source_map : Bool // Embed source map as base64 data URL in JS output
  inline_sources : Bool // Include original source in source map
  declaration : Bool
  always_strict : Bool
  es_module_interop : Bool // Emit helpers for CommonJS/ES module interoperability
  external_types_json : String? // JSON string containing external types for cross-file checking
  no_emit : Bool // Only run type checking, don't emit JavaScript
} derive(Show, ToJson, FromJson)

///|
/// Create a compile request
pub fn CompileRequest::new(
  file_path : String,
  source : String,
  target? : String = "es2015",
  module_kind? : String = "esmodule",
  source_map? : Bool = false,
  inline_source_map? : Bool = false,
  inline_sources? : Bool = false,
  declaration? : Bool = false,
  always_strict? : Bool = false,
  es_module_interop? : Bool = false,
  external_types_json? : String? = None,
  no_emit? : Bool = false,
) -> CompileRequest {
  {
    file_path,
    source,
    target,
    module_kind,
    source_map,
    inline_source_map,
    inline_sources,
    declaration,
    always_strict,
    es_module_interop,
    external_types_json,
    no_emit,
  }
}

///|
/// Response sent from worker to coordinator
pub(all) struct CompileResponse {
  file_path : String
  success : Bool
  javascript : String
  source_map : String?
  declaration : String?
  diagnostics : Array[String]
  compile_time_ms : Int64
  module_types_json : String? // JSON string containing exported types for caching
} derive(Show, ToJson, FromJson)

///|
/// Create a successful response from CompileResult
pub fn CompileResponse::from_result(
  file_path : String,
  result : @compiler.CompileResult,
  compile_time_ms : Int64,
) -> CompileResponse {
  let diagnostics = result.diagnostics.map(
    @compiler.format_diagnostic_for_output,
  )
  {
    file_path,
    success: result.success,
    javascript: result.javascript,
    source_map: result.source_map,
    declaration: result.declaration,
    diagnostics,
    compile_time_ms,
    module_types_json: result.module_types_json,
  }
}

///|
/// Create an error response
pub fn CompileResponse::error(
  file_path : String,
  message : String,
) -> CompileResponse {
  {
    file_path,
    success: false,
    javascript: "",
    source_map: None,
    declaration: None,
    diagnostics: [message],
    compile_time_ms: 0,
    module_types_json: None,
  }
}

///|
/// Serialize request to newline-delimited JSON
pub fn CompileRequest::to_ndjson(self : CompileRequest) -> String {
  self.to_json().stringify() + "\n"
}

///|
/// Serialize response to newline-delimited JSON
pub fn CompileResponse::to_ndjson(self : CompileResponse) -> String {
  self.to_json().stringify() + "\n"
}

///|
/// Parse request from JSON string
pub fn parse_request(json_str : String) -> CompileRequest raise Error {
  let json = @json.parse(json_str)
  @json.from_json(json)
}

///|
/// Parse response from JSON string
pub fn parse_response(json_str : String) -> CompileResponse raise Error {
  let json = @json.parse(json_str)
  @json.from_json(json)
}
