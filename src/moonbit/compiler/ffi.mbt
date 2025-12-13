// FFI Exports for MoonBit Compiler
// Provides C ABI compatible functions for Zig integration
//
// This module exposes the compilation pipeline through FFI-compatible
// wrapper functions that can be called from Zig's parallel execution engine.

///|
/// Module output format
pub(all) enum ModuleKind {
  ESModule // ES2015+ import/export (default)
  CommonJS // Node.js require/module.exports
  AMD // Asynchronous Module Definition (deprecated)
  UMD // Universal Module Definition (deprecated)
} derive(Show, Eq)

///|
/// Compilation options passed from Zig
pub(all) struct CompileOptions {
  target : Target
  module_kind : ModuleKind // Module output format (ESModule or CommonJS)
  source_map : Bool
  inline_source_map : Bool // Embed source map as base64 data URL in JS output
  inline_sources : Bool // Include original source in source map
  declaration : Bool
  strict : Bool
  always_strict : Bool // Emit "use strict" directive
  isolated_modules : Bool // Ensures each file can be transpiled independently
  exact_optional_property_types : Bool // Differentiates between undefined and missing properties
  no_unchecked_indexed_access : Bool // Adds undefined to indexed access types (arr[i] becomes T | undefined)
  verbatim_module_syntax : Bool // Requires type-only imports/exports to use explicit type syntax
  no_emit : Bool // Only run type checking, don't emit JavaScript or declaration files
  es_module_interop : Bool // Emit helpers for CommonJS/ES module interoperability
  import_helpers : Bool // @importHelpers - use imported helpers from tslib
  no_implicit_any : Bool // Error on expressions and declarations with an implied 'any' type
  strict_null_checks : Bool // Enable strict null checks
  no_implicit_this : Bool // Error on 'this' expressions with an implied 'any' type
  no_unused_locals : Bool // Report errors on unused local variables
  no_unused_parameters : Bool // Report errors on unused parameters
  no_implicit_returns : Bool // Report error when not all code paths return a value
  no_fallthrough_cases_in_switch : Bool // Report errors for fallthrough cases in switch statements
  strict_property_initialization : Bool // Ensure class properties are initialized in constructor
} derive(Show)

///|
/// Create default compile options
pub fn CompileOptions::default() -> CompileOptions {
  {
    target: Target::ES2015,
    module_kind: ESModule,
    source_map: false,
    inline_source_map: false,
    inline_sources: false,
    declaration: false,
    strict: false,
    always_strict: false,
    isolated_modules: false,
    exact_optional_property_types: false,
    no_unchecked_indexed_access: false,
    verbatim_module_syntax: false,
    no_emit: false,
    es_module_interop: false,
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
}

///|
/// Parse target string to Target enum
pub fn parse_target(target_str : String) -> Target {
  match target_str.to_lower() {
    "es5" => Target::ES5
    "es2015" | "es6" => Target::ES2015
    "es2016" | "es7" => Target::ES2016
    "es2017" => Target::ES2017
    "es2018" => Target::ES2018
    "es2019" => Target::ES2019
    "es2020" => Target::ES2020
    "esnext" | "latest" => Target::ESNext
    _ => Target::ES2015 // Default
  }
}

///|
/// Parse module kind string to ModuleKind enum
pub fn parse_module_kind(module_str : String) -> ModuleKind {
  match module_str.to_lower() {
    "commonjs" => CommonJS
    "amd" => AMD
    "umd" => UMD
    "es2015" | "es6" | "es2020" | "es2022" | "esnext" => ESModule
    _ => ESModule // Default
  }
}

///|
/// Compilation result containing all outputs
pub struct CompileResult {
  success : Bool
  javascript : String
  source_map : String?
  declaration : String?
  diagnostics : Array[Diagnostic]
  module_types_json : String? // JSON string containing exported types for caching
} derive(Show)

///|
/// Create a failed result with diagnostics
fn CompileResult::failure(diagnostics : Array[Diagnostic]) -> CompileResult {
  {
    success: false,
    javascript: "",
    source_map: None,
    declaration: None,
    diagnostics,
    module_types_json: None,
  }
}

///|
/// Extract inline test options from source directives (e.g., // @noImplicitAny: true)
fn extract_inline_options(source : String) -> TestOptions {
  let mut no_implicit_any = false
  let lines = split_lines(source)
  for line in lines {
    let trimmed = ffi_trim_start(line)
    if trimmed.has_prefix("// @") || trimmed.has_prefix("//@") {
      // Handle both "// @" and "//@" formats (TypeScript conformance tests use "//@")
      let prefix_len = if trimmed.has_prefix("// @") { 4 } else { 3 }
      let directive = ffi_substring_from(trimmed, prefix_len)
      if directive.has_prefix("noImplicitAny:") {
        let val = ffi_trim(ffi_substring_from(directive, 14))
        no_implicit_any = val == "true"
      }
    } else if not(trimmed.has_prefix("//")) && trimmed.length() > 0 {
      // Stop at first non-comment line
      break
    }
  }
  { ..TestOptions::default(), no_implicit_any, }
}

///|
/// Main compilation function - compiles a single TypeScript file
/// This is the primary FFI entry point
pub fn compile_source(
  source : String,
  file_path : String,
  options : CompileOptions,
) -> CompileResult {
  // Extract inline test options from source directives
  let inline_opts = extract_inline_options(source)
  // Apply inline options to compile options
  let options = if inline_opts.no_implicit_any {
    { ..options, no_implicit_any: true }
  } else {
    options
  }

  // Phase 1: Scan source into tokens
  let tokens = scan_all_v2(source, file_path)

  // Phase 2: Parse tokens into AST
  // Note: Parser now always returns Ok with parse diagnostics attached to source_file
  match parse_source_file(tokens, file_path) {
    Err(diagnostics) => CompileResult::failure(diagnostics) // Should never happen
    Ok(source_file) => {
      // Extract parse diagnostics to combine with type diagnostics later
      let parse_diagnostics = source_file.parse_diagnostics

      // Phase 3: Bind the AST (symbol resolution)
      match bind_source_file(source_file) {
        Err(diagnostics) => {
          // Combine parse diagnostics with bind diagnostics
          let all_diagnostics = parse_diagnostics.copy()
          for d in diagnostics {
            all_diagnostics.push(d)
          }
          CompileResult::failure(all_diagnostics)
        }
        Ok(bound_source) => {
          // Phase 3.5: Validate isolatedModules constraints if enabled
          let isolated_modules_diagnostics = if options.isolated_modules {
            validate_isolated_modules(bound_source, file_path)
          } else {
            []
          }

          // If isolatedModules validation failed, return errors
          if isolated_modules_diagnostics.length() > 0 {
            return CompileResult::failure(isolated_modules_diagnostics)
          }

          // Phase 3.6: Validate verbatimModuleSyntax constraints if enabled
          let verbatim_module_diagnostics = if options.verbatim_module_syntax {
            validate_verbatim_module_syntax(bound_source, file_path)
          } else {
            []
          }

          // If verbatimModuleSyntax validation failed, return errors
          if verbatim_module_diagnostics.length() > 0 {
            return CompileResult::failure(verbatim_module_diagnostics)
          }

          // Phase 4: Type check with the target from options
          let check_result = check_source_file_with_options(
            bound_source,
            options.no_unchecked_indexed_access,
            options.target,
            no_implicit_any=options.no_implicit_any,
            module_kind=options.module_kind,
          )

          // Collect type errors but continue compilation
          // TypeScript behavior: emit JavaScript even with type errors
          let type_diagnostics = match check_result {
            Ok(typed_file) => typed_file.diagnostics
            Err(diags) => diags
          }

          // Extract module types for cross-file type checking cache
          let module_types = extract_module_types(bound_source, file_path)
          let module_types_json = Some(module_types.to_json_string())

          // If noEmit is enabled, skip all emit phases and return type check results only
          if options.no_emit {
            // Combine parse diagnostics with type diagnostics
            let all_diagnostics = parse_diagnostics.copy()
            for d in type_diagnostics {
              all_diagnostics.push(d)
            }
            return {
              success: true,
              javascript: "",
              source_map: None,
              declaration: None,
              diagnostics: all_diagnostics,
              module_types_json,
            }
          }

          // Phase 5: Transform AST (remove types, downlevel features)
          let transformer_ctx = TransformerContext::new(options.target)
          let transformed_node = transform(
            SourceFile(source_file),
            transformer_ctx,
          )

          // Extract the transformed source file
          let transformed_sf = match transformed_node {
            SourceFile(sf) => sf
            _ => source_file // Fallback, should not happen
          }

          // Phase 6: Emit JavaScript
          let emitter_ctx = EmitterContext::with_options(
            options.module_kind,
            options.always_strict,
          )
          // Generate source map if requested (either external or inline)
          let needs_source_map = options.source_map || options.inline_source_map
          let (javascript, source_map_json) = if needs_source_map {
            // Pass original source when inline_sources is enabled
            let original_source : String? = if options.inline_sources {
              Some(source)
            } else {
              None
            }
            emit_with_source_map_internal(
              transformed_sf,
              file_path,
              options.module_kind,
              options.always_strict,
              original_source~,
            )
          } else {
            (emit(SourceFile(transformed_sf), emitter_ctx), None)
          }

          // Phase 7: Emit declaration file if requested
          let declaration = if options.declaration {
            let decl_ctx = DeclarationEmitterContext::default()
            Some(emit_declaration_file(source_file, decl_ctx))
          } else {
            None
          }

          // Return result with parse diagnostics and type errors
          // Combine parse diagnostics with type diagnostics
          let all_diagnostics = parse_diagnostics.copy()
          for d in type_diagnostics {
            all_diagnostics.push(d)
          }
          {
            success: true,
            javascript,
            source_map: source_map_json,
            declaration,
            diagnostics: all_diagnostics,
            module_types_json,
          }
        }
      }
    }
  }
}

///|
/// Emit JavaScript with source map
fn emit_with_source_map_internal(
  source_file : SourceFile,
  file_path : String,
  module_kind : ModuleKind,
  always_strict : Bool,
  original_source? : String? = None,
) -> (String, String?) {
  let source_map_builder = SourceMapBuilder::new()
  let ctx = EmitterContext::with_options_and_source_map(
    module_kind, always_strict, source_map_builder, file_path,
  )
  let javascript = emit(SourceFile(source_file), ctx)

  // Build source map with optional sources content
  let sources_content : Array[String]? = match original_source {
    Some(src) => Some([src])
    None => None
  }
  let source_map = source_map_builder.build_with_sources(
    Some(file_path),
    sources_content,
  )
  let source_map_json = source_map.to_json()
  (javascript, Some(source_map_json))
}

///|
/// Parse only - returns AST without type checking
/// Useful for quick syntax validation
pub fn parse_only(
  source : String,
  file_path : String,
) -> Result[SourceFile, Array[Diagnostic]] {
  let tokens = scan_all_v2(source, file_path)
  parse_source_file(tokens, file_path)
}

///|
/// Scan only - returns tokens without parsing
/// Useful for syntax highlighting or quick validation
pub fn scan_only(source : String, file_path : String) -> Array[Token] {
  scan_all_v2(source, file_path)
}

///|
/// Emit declaration file only
pub fn emit_declaration_only(
  source : String,
  file_path : String,
) -> Result[String, Array[Diagnostic]] {
  match parse_only(source, file_path) {
    Err(diagnostics) => Err(diagnostics)
    Ok(source_file) => {
      let ctx = DeclarationEmitterContext::default()
      Ok(emit_declaration_file(source_file, ctx))
    }
  }
}

///|
/// Batch compile multiple files
/// Returns array of results in same order as input files
pub fn compile_batch(
  files : Array[(String, String)], // (source, file_path) pairs
  options : CompileOptions,
) -> Array[CompileResult] {
  let results : Array[CompileResult] = []
  for i = 0; i < files.length(); i = i + 1 {
    let (source, file_path) = files[i]
    let result = compile_source(source, file_path, options)
    results.push(result)
  }
  results
}

///|
/// Get diagnostic message as string (for FFI output)
pub fn format_diagnostic_for_output(diagnostic : Diagnostic) -> String {
  let category = match diagnostic.category {
    DiagnosticCategory::Error => "error"
    DiagnosticCategory::Warning => "warning"
    DiagnosticCategory::Suggestion => "suggestion"
    DiagnosticCategory::Message => "message"
  }
  let loc = diagnostic.location
  "\{loc.file_path}:\{loc.start.line}:\{loc.start.column} - \{category} TS\{diagnostic.code}: \{diagnostic.message}"
}

///|
/// Format all diagnostics from a compile result (for FFI output)
pub fn format_all_diagnostics(diagnostics : Array[Diagnostic]) -> String {
  let sb = StringBuilder::new()
  for i = 0; i < diagnostics.length(); i = i + 1 {
    if i > 0 {
      sb.write_char('\n')
    }
    sb.write_string(format_diagnostic_for_output(diagnostics[i]))
  }
  sb.to_string()
}

///|
/// Main compilation function with external types - compiles with cross-file type checking
/// Uses the external type registry for resolving imported types
pub fn compile_source_with_external_types(
  source : String,
  file_path : String,
  options : CompileOptions,
  external_registry : ExternalTypeRegistry,
) -> CompileResult {
  // Extract inline test options from source directives
  let inline_opts = extract_inline_options(source)
  // Apply inline options to compile options
  let options = if inline_opts.no_implicit_any {
    { ..options, no_implicit_any: true }
  } else {
    options
  }

  // Phase 1: Scan source into tokens
  let tokens = scan_all_v2(source, file_path)

  // Phase 2: Parse tokens into AST
  // Note: Parser now always returns Ok with parse diagnostics attached to source_file
  match parse_source_file(tokens, file_path) {
    Err(diagnostics) => CompileResult::failure(diagnostics) // Should never happen
    Ok(source_file) => {
      // Extract parse diagnostics to combine with type diagnostics later
      let parse_diagnostics = source_file.parse_diagnostics

      // Phase 3: Bind the AST (symbol resolution)
      match bind_source_file(source_file) {
        Err(diagnostics) => {
          // Combine parse diagnostics with bind diagnostics
          let all_diagnostics = parse_diagnostics.copy()
          for d in diagnostics {
            all_diagnostics.push(d)
          }
          CompileResult::failure(all_diagnostics)
        }
        Ok(bound_source) => {
          // Phase 3.5: Validate isolatedModules constraints if enabled
          let isolated_modules_diagnostics = if options.isolated_modules {
            validate_isolated_modules(bound_source, file_path)
          } else {
            []
          }

          // If isolatedModules validation failed, return errors
          if isolated_modules_diagnostics.length() > 0 {
            return CompileResult::failure(isolated_modules_diagnostics)
          }

          // Phase 3.6: Validate verbatimModuleSyntax constraints if enabled
          let verbatim_module_diagnostics = if options.verbatim_module_syntax {
            validate_verbatim_module_syntax(bound_source, file_path)
          } else {
            []
          }

          // If verbatimModuleSyntax validation failed, return errors
          if verbatim_module_diagnostics.length() > 0 {
            return CompileResult::failure(verbatim_module_diagnostics)
          }

          // Phase 4: Type check WITH external types
          let check_result = check_source_file_with_external_types(
            bound_source,
            external_registry,
            options.no_unchecked_indexed_access,
            options.target,
            no_implicit_any=options.no_implicit_any,
            module_kind=options.module_kind,
            import_helpers=options.import_helpers,
          )

          // Collect type errors but continue compilation
          // TypeScript behavior: emit JavaScript even with type errors
          let type_diagnostics = match check_result {
            Ok(typed_file) => typed_file.diagnostics
            Err(diags) => diags
          }

          // Extract module types for cross-file type checking cache
          // Use external registry to resolve require() chains for proper type inference
          let module_types = extract_module_types_with_registry(
            bound_source,
            file_path,
            Some(external_registry),
          )
          let module_types_json = Some(module_types.to_json_string())

          // If noEmit is enabled, skip all emit phases and return type check results only
          if options.no_emit {
            // Combine parse diagnostics with type diagnostics
            let all_diagnostics = parse_diagnostics.copy()
            for d in type_diagnostics {
              all_diagnostics.push(d)
            }
            return {
              success: true,
              javascript: "",
              source_map: None,
              declaration: None,
              diagnostics: all_diagnostics,
              module_types_json,
            }
          }

          // Phase 5: Transform AST (remove types, downlevel features)
          let transformer_ctx = TransformerContext::new(options.target)
          let transformed_node = transform(
            SourceFile(source_file),
            transformer_ctx,
          )

          // Extract the transformed source file
          let transformed_sf = match transformed_node {
            SourceFile(sf) => sf
            _ => source_file // Fallback, should not happen
          }

          // Phase 6: Emit JavaScript
          let emitter_ctx = EmitterContext::with_options(
            options.module_kind,
            options.always_strict,
          )
          // Generate source map if requested (either external or inline)
          let needs_source_map = options.source_map || options.inline_source_map
          let (javascript, source_map_json) = if needs_source_map {
            // Pass original source when inline_sources is enabled
            let original_source : String? = if options.inline_sources {
              Some(source)
            } else {
              None
            }
            emit_with_source_map_internal(
              transformed_sf,
              file_path,
              options.module_kind,
              options.always_strict,
              original_source~,
            )
          } else {
            (emit(SourceFile(transformed_sf), emitter_ctx), None)
          }

          // Phase 7: Emit declaration file if requested
          let declaration = if options.declaration {
            let decl_ctx = DeclarationEmitterContext::default()
            Some(emit_declaration_file(source_file, decl_ctx))
          } else {
            None
          }

          // Return result with parse diagnostics and type errors
          // Combine parse diagnostics with type diagnostics
          let all_diagnostics = parse_diagnostics.copy()
          for d in type_diagnostics {
            all_diagnostics.push(d)
          }
          {
            success: true,
            javascript,
            source_map: source_map_json,
            declaration,
            diagnostics: all_diagnostics,
            module_types_json,
          }
        }
      }
    }
  }
}

///|
/// Get compiler version string
pub fn get_compiler_version() -> String {
  "0.1.0"
}

///|
/// Compiler info for FFI
pub struct CompilerInfo {
  version : String
  name : String
  description : String
} derive(Show)

///|
/// Get compiler information
pub fn get_compiler_info() -> CompilerInfo {
  {
    version: "0.1.0",
    name: "MoonBit TypeScript Compiler",
    description: "High-performance TypeScript compiler with MoonBit + Zig architecture",
  }
}

///|
/// Parse and bind a source file to get full binding information
/// including triple-slash directives, module info, and symbols
pub fn parse_and_bind(
  source : String,
  file_path : String,
) -> Result[BoundSourceFile, Array[Diagnostic]] {
  let tokens = scan_all_v2(source, file_path)
  match parse_source_file(tokens, file_path) {
    Err(diagnostics) => Err(diagnostics)
    Ok(source_file) => bind_source_file(source_file)
  }
}

///|
/// Extract triple-slash reference paths from source
/// Returns an array of file paths referenced via /// <reference path="..." />
pub fn extract_reference_paths(
  source : String,
  file_path : String,
) -> Array[String] {
  let paths : Array[String] = []
  match parse_and_bind(source, file_path) {
    Ok(bound) =>
      for directive in bound.triple_slash_directives {
        match directive.kind {
          ReferencePath(path) => paths.push(path)
          _ => () // Ignore other directive types
        }
      }
    Err(_) => () // Return empty array on parse failure
  }
  paths
}

///|
/// Represents a virtual file extracted from a multi-file test
pub(all) struct VirtualFile {
  filename : String
  content : String
} derive(Show)

///|
/// Represents test options extracted from directives
pub(all) struct TestOptions {
  module_kind : String? // "commonjs", "esnext", etc.
  target : String? // "es5", "es2015", etc.
  strict : Bool
  no_emit : Bool
  no_implicit_any : Bool // @noImplicitAny: true
  import_helpers : Bool // @importHelpers: true
  lib : Array[String] // Library files to include
} derive(Show)

///|
/// Result of splitting a multi-file test
pub(all) struct MultiFileTest {
  files : Array[VirtualFile]
  options : TestOptions
} derive(Show)

///|
/// Default test options
pub fn TestOptions::default() -> TestOptions {
  {
    module_kind: None,
    target: None,
    strict: false,
    no_emit: false,
    no_implicit_any: false,
    import_helpers: false,
    lib: [],
  }
}

///|
/// Trim leading whitespace from string
fn ffi_trim_start(s : String) -> String {
  let chars = s.to_array()
  let len = chars.length()
  if len == 0 {
    return ""
  }
  let mut start = 0
  while start < len &&
        (
          chars[start] == ' ' ||
          chars[start] == '\t' ||
          chars[start] == '\r' ||
          chars[start] == '\n'
        ) {
    start = start + 1
  }
  if start == 0 {
    return s
  }
  let result = StringBuilder::new()
  for i = start; i < len; i = i + 1 {
    result.write_char(chars[i])
  }
  result.to_string()
}

///|
/// Trim trailing whitespace from string
fn ffi_trim_end(s : String) -> String {
  let chars = s.to_array()
  let len = chars.length()
  if len == 0 {
    return ""
  }
  let mut end = len
  while end > 0 &&
        (
          chars[end - 1] == ' ' ||
          chars[end - 1] == '\t' ||
          chars[end - 1] == '\r' ||
          chars[end - 1] == '\n'
        ) {
    end = end - 1
  }
  if end == len {
    return s
  }
  let result = StringBuilder::new()
  for i = 0; i < end; i = i + 1 {
    result.write_char(chars[i])
  }
  result.to_string()
}

///|
/// Trim whitespace from both ends
fn ffi_trim(s : String) -> String {
  ffi_trim_end(ffi_trim_start(s))
}

///|
/// Get substring from start index to end of string
fn ffi_substring_from(s : String, start : Int) -> String {
  let chars = s.to_array()
  let len = chars.length()
  if start >= len {
    return ""
  }
  let result = StringBuilder::new()
  for i = start; i < len; i = i + 1 {
    result.write_char(chars[i])
  }
  result.to_string()
}

///|
/// Split a multi-file test content into separate virtual files
/// Handles @filename: directives and extracts test options from @xxx: directives
pub fn split_multi_file_test(
  source : String,
  base_path : String,
) -> MultiFileTest {
  let files : Array[VirtualFile] = []
  let mut options = TestOptions::default()
  let lines = split_lines(source)
  let mut current_filename : String? = None
  let mut current_content = StringBuilder::new()
  for line in lines {
    let trimmed = ffi_trim_start(line)
    if trimmed.has_prefix("// @") {
      // This is a directive line
      let directive = ffi_substring_from(trimmed, 4)
      if directive.has_prefix("filename:") {
        // Save current file if any
        match current_filename {
          Some(fname) => {
            let content_str = current_content.to_string()
            files.push({ filename: fname, content: content_str })
            current_content = StringBuilder::new()
          }
          None => ()
        }
        // Start new file
        let filename = ffi_trim(ffi_substring_from(directive, 9))
        current_filename = Some(filename)
      } else if directive.has_prefix("module:") {
        let module_kind = ffi_trim(ffi_substring_from(directive, 7))
        options = { ..options, module_kind: Some(module_kind) }
      } else if directive.has_prefix("target:") {
        let target = ffi_trim(ffi_substring_from(directive, 7))
        options = { ..options, target: Some(target) }
      } else if directive.has_prefix("strict:") {
        let strict_val = ffi_trim(ffi_substring_from(directive, 7))
        options = { ..options, strict: strict_val == "true" }
      } else if directive.has_prefix("noEmit:") {
        let no_emit_val = ffi_trim(ffi_substring_from(directive, 7))
        options = { ..options, no_emit: no_emit_val == "true" }
      } else if directive.has_prefix("lib:") {
        let lib_val = ffi_trim(ffi_substring_from(directive, 4))
        let libs = ffi_split_by_comma(lib_val)
        options = { ..options, lib: libs }
      } else if directive.has_prefix("noImplicitAny:") {
        let no_implicit_any_val = ffi_trim(ffi_substring_from(directive, 14))
        options = { ..options, no_implicit_any: no_implicit_any_val == "true" }
      } else if directive.has_prefix("importHelpers:") {
        let import_helpers_val = ffi_trim(ffi_substring_from(directive, 14))
        options = { ..options, import_helpers: import_helpers_val == "true" }
      }
      // Skip other directives (don't add to content)
    } else {
      // Regular content line - add to current file
      current_content.write_string(line)
      current_content.write_char('\n')
    }
  }

  // Save the last file
  match current_filename {
    Some(fname) => {
      let content_str = current_content.to_string()
      files.push({ filename: fname, content: content_str })
    }
    None => {
      // No @filename: directive found, treat entire content as single file
      let content_str = current_content.to_string()
      if content_str.length() > 0 {
        files.push({ filename: base_path, content: content_str })
      }
    }
  }
  { files, options }
}

///|
/// Split source string by newlines
fn split_lines(source : String) -> Array[String] {
  let lines : Array[String] = []
  let current = StringBuilder::new()
  for c in source {
    if c == '\n' {
      lines.push(current.to_string())
      current.reset()
    } else if c != '\r' {
      current.write_char(c)
    }
  }
  // Don't forget the last line
  let last = current.to_string()
  if last.length() > 0 {
    lines.push(last)
  }
  lines
}

///|
/// Split a string by comma (for multi-file test parsing)
fn ffi_split_by_comma(s : String) -> Array[String] {
  let parts : Array[String] = []
  let current = StringBuilder::new()
  for c in s {
    if c == ',' {
      let part = ffi_trim(current.to_string())
      if part.length() > 0 {
        parts.push(part)
      }
      current.reset()
    } else {
      current.write_char(c)
    }
  }
  let last = ffi_trim(current.to_string())
  if last.length() > 0 {
    parts.push(last)
  }
  parts
}

///|
/// Check if content contains multi-file test directives
pub fn is_multi_file_test(source : String) -> Bool {
  source.contains("// @filename:")
}

///|
/// Compile a multi-file test
/// Returns diagnostics for all files combined
pub fn compile_multi_file_test(
  source : String,
  base_path : String,
  options : CompileOptions,
) -> CompileResult {
  // Check if this is actually a multi-file test
  if not(is_multi_file_test(source)) {
    // Single file test - compile directly
    return compile_source(source, base_path, options)
  }

  // Split into virtual files
  let multi_test = split_multi_file_test(source, base_path)

  // Apply test options
  let effective_options = apply_test_options(options, multi_test.options)

  // If no files were extracted, just compile the original
  if multi_test.files.length() == 0 {
    return compile_source(source, base_path, effective_options)
  }

  // First pass: parse all files
  let parsed_result_files : Array[ParsedVirtualFile] = []
  let parse_errors : Array[(String, Array[Diagnostic])] = []

  for file in multi_test.files {
    let tokens = scan_all_v2(file.content, file.filename)
    match parse_source_file(tokens, file.filename) {
      Ok(source_file) => {
        parsed_result_files.push(ParsedVirtualFile::{
          filename: file.filename,
          source_file,
        })
      }
      Err(diagnostics) => {
        parse_errors.push((file.filename, diagnostics))
      }
    }
  }

  // Build multi-file parse result
  let parse_result = MultiFileParseResult::{
    files: parsed_result_files,
    parse_errors,
  }

  // Build external type registry from parsed files
  // This properly handles ambient module declarations (declare module "foo")
  let registry = build_registry_from_virtual_files(parse_result)
  let all_diagnostics : Array[Diagnostic] = []

  // Build maps for later use
  let parsed_files : Map[String, SourceFile] = Map::new()
  let bound_files : Map[String, BoundSourceFile] = Map::new()

  for parsed_file in parse_result.files {
    parsed_files.set(parsed_file.filename, parsed_file.source_file)
    // Also bind the file
    match bind_source_file(parsed_file.source_file) {
      Ok(bound) => bound_files.set(parsed_file.filename, bound)
      Err(_) => ()
    }
  }

  // Second pass: compile each file with the registry
  for file in multi_test.files {

    // Compile with type checking
    let result = compile_source_with_external_types(
      file.content,
      file.filename,
      effective_options,
      registry,
    )
    for diag in result.diagnostics {
      all_diagnostics.push(diag)
    }
  }

  // Third pass: validate imports across files (TS2724, TS2305, TS1192, etc.)
  let module_registry : Map[String, ResolvedModuleExports] = Map::new()
  for entry in bound_files.iter() {
    let (file_path, bound_file) = entry
    let resolved = ResolvedModuleExports::from_bound_file(bound_file, file_path)
    // Register with the full file path
    module_registry.set(file_path, resolved)

    // Also register with common variations:
    // "./filename.ts" -> filename.ts
    // "./filename" -> filename.ts (without extension)
    if file_path.has_suffix(".ts") {
      // Add "./filename.ts" version
      module_registry.set("./" + file_path, resolved)
      // Add "./filename" version (without .ts)
      let name_without_ext = file_path.substring(end=file_path.length() - 3)
      module_registry.set("./" + name_without_ext, resolved)
    } else {
      module_registry.set("./" + file_path, resolved)
    }
  }

  for entry in parsed_files.iter() {
    let (_, source_file) = entry
    for stmt in source_file.statements {
      match stmt {
        Node::ImportDeclaration(import_decl) => {
          let import_diags = validate_import_resolution(import_decl, module_registry)
          for d in import_diags {
            all_diagnostics.push(d)
          }
        }
        _ => ()
      }
    }
  }

  // Fourth pass: detect export star conflicts (TS2308)
  let export_star_diags = detect_export_star_conflicts(parsed_files, module_registry)
  for d in export_star_diags {
    all_diagnostics.push(d)
  }

  // Return combined result
  {
    success: true,
    javascript: "",
    source_map: None,
    declaration: None,
    diagnostics: all_diagnostics,
    module_types_json: None,
  }
}

///|
/// Apply test options to compile options
fn apply_test_options(
  base_options : CompileOptions,
  test_options : TestOptions,
) -> CompileOptions {
  let mut opts = base_options
  match test_options.module_kind {
    Some(mk) => {
      opts = { ..opts, module_kind: parse_module_kind(mk) }
    }
    None => ()
  }
  match test_options.target {
    Some(t) => {
      let target = parse_target(t)
      opts = { ..opts, target, }
    }
    None => ()
  }
  if test_options.strict {
    opts = { ..opts, strict: true }
  }
  if test_options.no_emit {
    opts = { ..opts, no_emit: true }
  }
  if test_options.no_implicit_any {
    opts = { ..opts, no_implicit_any: true }
  }
  if test_options.import_helpers {
    opts = { ..opts, import_helpers: true }
  }
  opts
}
