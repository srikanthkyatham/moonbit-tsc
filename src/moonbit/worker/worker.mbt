// Worker process for parallel TypeScript compilation
// Reads CompileRequest JSON from stdin, writes CompileResponse JSON to stdout
// Uses moonbitlang/async for I/O operations

///|
/// Run the worker loop - reads requests from stdin, writes responses to stdout
pub async fn run_worker() -> Unit raise Error {
  // Process requests until stdin is closed
  while true {
    let line = @stdio.stdin.read_until("\n")
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
  let request = @protocol.parse_request(json_str) catch {
    err =>
      return @protocol.CompileResponse::error(
        "",
        "Failed to parse request: \{err}",
      )
  }

  // Build compile options
  let module_kind : @compiler.ModuleKind = @compiler.parse_module_kind(
    request.module_kind,
  )
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
    no_emit: request.no_emit,
    es_module_interop: request.es_module_interop,
    import_helpers: false,
    no_implicit_any: false,
    strict_null_checks: false,
    no_implicit_this: false,
    no_unused_locals: false,
    no_unused_parameters: false,
    no_implicit_returns: false,
    no_fallthrough_cases_in_switch: false,
    strict_property_initialization: false,
  }

  // Tri-state strict-flag overrides from the CLI/tsconfig (None = unset,
  // resolved against file directives by the checker)
  let strict_overrides = Some(@compiler.StrictFlagOverrides::{
    strict: request.strict,
    no_implicit_any: request.no_implicit_any,
    strict_null_checks: request.strict_null_checks,
    strict_function_types: request.strict_function_types,
    strict_property_initialization: request.strict_property_initialization,
  })

  // Measure compilation time
  let start_time = @async.now()

  // Compile the source - use external types if provided
  let result = match request.external_types_json {
    Some(json_str) =>
      // Parse external types JSON and use with cross-file type checking
      match @compiler.ExternalTypeRegistry::from_json(json_str) {
        Some(registry) =>
          @compiler.compile_source_with_external_types(
            request.source,
            request.file_path,
            options,
            registry,
            strict_overrides~,
          )
        None =>
          // Failed to parse external types, fall back to regular compilation
          @compiler.compile_source(
            request.source,
            request.file_path,
            options,
            strict_overrides~,
          )
      }
    None =>
      // No external types, use regular compilation
      @compiler.compile_source(
        request.source,
        request.file_path,
        options,
        strict_overrides~,
      )
  }
  let end_time = @async.now()
  let compile_time_ms = end_time - start_time

  // Return response
  @protocol.CompileResponse::from_result(
    request.file_path,
    result,
    compile_time_ms,
  )
}
