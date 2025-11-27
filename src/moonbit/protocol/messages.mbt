// Protocol message types for worker communication
// Uses newline-delimited JSON over stdin/stdout

///|
/// Request sent from coordinator to worker
pub(all) struct CompileRequest {
  file_path : String
  source : String
  target : String
  source_map : Bool
  declaration : Bool
} derive(Show, ToJson, FromJson)

///|
/// Create a compile request
pub fn CompileRequest::new(
  file_path : String,
  source : String,
  target~ : String = "es2015",
  source_map~ : Bool = false,
  declaration~ : Bool = false,
) -> CompileRequest {
  { file_path, source, target, source_map, declaration }
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
} derive(Show, ToJson, FromJson)

///|
/// Create a successful response from CompileResult
pub fn CompileResponse::from_result(
  file_path : String,
  result : @compiler.CompileResult,
  compile_time_ms : Int64,
) -> CompileResponse {
  let diagnostics = result.diagnostics.map(@compiler.format_diagnostic_for_output)
  {
    file_path,
    success: result.success,
    javascript: result.javascript,
    source_map: result.source_map,
    declaration: result.declaration,
    diagnostics,
    compile_time_ms,
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
