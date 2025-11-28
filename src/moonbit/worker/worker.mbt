// Worker process for parallel TypeScript compilation
// Reads CompileRequest JSON from stdin, writes CompileResponse JSON to stdout
// Uses moonbitlang/async for I/O operations

///|
/// Run the worker loop - reads requests from stdin, writes responses to stdout
pub async fn run_worker() -> Unit raise Error {
  let reader = @io.BufferedReader::new(@stdio.stdin)

  // Process requests until stdin is closed
  while true {
    let line = reader.read_line()
    match line {
      None => break // EOF - coordinator closed stdin
      Some(json_str) => {
        let response = process_request(json_str)
        let output = response.to_ndjson()
        @stdio.stdout.write(output)
      }
    }
  }
}

///|
/// Process a single compile request
fn process_request(json_str : String) -> @protocol.CompileResponse {
  // Parse the request
  let request = try {
    @protocol.parse_request(json_str)
  } catch {
    err => {
      return @protocol.CompileResponse::error("", "Failed to parse request: \{err}")
    }
  }

  // Build compile options
  let module_kind : @compiler.ModuleKind = if request.module_kind == "commonjs" {
    @compiler.CommonJS
  } else {
    @compiler.ESModule
  }
  let options = @compiler.CompileOptions::{
    target: @compiler.parse_target(request.target),
    module_kind,
    source_map: request.source_map,
    inline_source_map: request.inline_source_map,
    inline_sources: request.inline_sources,
    declaration: request.declaration,
    strict: false,
    always_strict: request.always_strict,
    isolated_modules: false,
    exact_optional_property_types: false,
    no_unchecked_indexed_access: false,
    verbatim_module_syntax: false,
    no_emit: false,
    es_module_interop: request.es_module_interop,
    no_implicit_any: false,
    strict_null_checks: false,
    no_implicit_this: false,
    no_unused_locals: false,
    no_unused_parameters: false,
    no_implicit_returns: false,
    no_fallthrough_cases_in_switch: false,
    strict_property_initialization: false,
  }

  // Measure compilation time
  let start_time = @async.now()

  // Compile the source
  let result = @compiler.compile_source(request.source, request.file_path, options)

  let end_time = @async.now()
  let compile_time_ms = end_time - start_time

  // Return response
  @protocol.CompileResponse::from_result(request.file_path, result, compile_time_ms)
}
