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
/// Compilation result containing all outputs
pub struct CompileResult {
  success : Bool
  javascript : String
  source_map : String?
  declaration : String?
  diagnostics : Array[Diagnostic]
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
  }
}

///|
/// Main compilation function - compiles a single TypeScript file
/// This is the primary FFI entry point
pub fn compile_source(
  source : String,
  file_path : String,
  options : CompileOptions,
) -> CompileResult {
  // Phase 1: Scan source into tokens
  let tokens = scan_all_v2(source, file_path)

  // Phase 2: Parse tokens into AST
  match parse_source_file(tokens, file_path) {
    Err(diagnostics) => CompileResult::failure(diagnostics)
    Ok(source_file) => {
      // Phase 3: Bind the AST (symbol resolution)
      match bind_source_file(source_file) {
        Err(diagnostics) => CompileResult::failure(diagnostics)
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

          // Phase 4: Type check
          let check_result = check_source_file(bound_source)

          // Collect type errors but continue compilation
          // TypeScript behavior: emit JavaScript even with type errors
          let type_diagnostics = match check_result {
            Ok(typed_file) => typed_file.diagnostics
            Err(diags) => diags
          }

          // If noEmit is enabled, skip all emit phases and return type check results only
          if options.no_emit {
            return {
              success: true,
              javascript: "",
              source_map: None,
              declaration: None,
              diagnostics: type_diagnostics,
            }
          }

          // Phase 5: Transform AST (remove types, downlevel features)
          let transformer_ctx = TransformerContext::new(options.target)
          let transformed_node = transform(SourceFile(source_file), transformer_ctx)

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

          // Return result with any type errors as warnings
          {
            success: true,
            javascript,
            source_map: source_map_json,
            declaration,
            diagnostics: type_diagnostics,
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
  original_source~ : String? = None,
) -> (String, String?) {
  let source_map_builder = SourceMapBuilder::new()
  let ctx = EmitterContext::with_options_and_source_map(
    module_kind,
    always_strict,
    source_map_builder,
    file_path,
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