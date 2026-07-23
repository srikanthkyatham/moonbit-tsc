// CLI argument parsing

///|
/// Source map output mode
pub(all) enum SourceMapMode {
  None
  External
  Inline
} derive(Debug, Eq)

///|
/// CLI command
pub(all) enum Command {
  Compile(Array[String], CLIOptions)
  CompileProject(String, CLIOptions) // tsconfig.json path
  BuildReferences(String, CLIOptions) // Build project with all references
  ListImports(String, Bool) // List imports from a file (path, json_output)
  JsonCompile(Array[String], CLIOptions) // JSON output mode for Phoenix API
  Worker
  Version
  Help
  Init // Generate tsconfig.json (future)
} derive(Debug)

///|
/// CLI options for compilation
pub(all) struct CLIOptions {
  target : String?
  module_system : String? // Module system: commonjs, es2015, esnext, etc.
  out_dir : String?
  source_map_mode : SourceMapMode?
  declaration : Bool?
  verbose : Bool
  parallel : Int?
  watch : Bool
  watch_interval : Int // Polling interval in milliseconds
  report_diagnostics : Bool // Always report diagnostics, even when successful
  json_output : Bool // Output results as JSON for tooling integration
  external_types_json : String? // JSON string containing external types for cross-file checking
  external_types_file : String? // Path to a file containing the external types JSON (avoids argv size limits)
  no_emit : Bool // Only run type checking, don't emit JavaScript
  strict : Bool // Enable all strict type-checking options
  no_implicit_any : Bool // Raise error on expressions with an implied 'any' type
  strict_null_checks : Bool // Enable strict null checks
  strict_function_types : Bool // Enable strict checking of function types
  import_helpers : Bool // Import emit helpers from tslib (e.g., __spreadArray)
} derive(Debug)

///|
/// Default CLI options
pub fn CLIOptions::default() -> CLIOptions {
  {
    target: None,
    module_system: None,
    out_dir: None,
    source_map_mode: None,
    declaration: None,
    verbose: false,
    parallel: None,
    watch: false,
    watch_interval: 500, // Default 500ms polling interval
    report_diagnostics: false,
    json_output: false,
    external_types_json: None,
    external_types_file: None,
    no_emit: false,
    strict: false,
    no_implicit_any: false,
    strict_null_checks: false,
    strict_function_types: false,
    import_helpers: false,
  }
}

///|
/// Parse command line arguments
pub fn parse_args(args : Array[String]) -> Result[Command, String] {
  if args.length() < 2 {
    return Ok(Command::Help)
  }
  let files : Array[String] = []
  let mut target : String? = None
  let mut module_system : String? = None
  let mut out_dir : String? = None
  let mut source_map_mode : SourceMapMode? = None
  let mut declaration : Bool? = None
  let mut verbose = false
  let mut parallel : Int? = None
  let mut watch = false
  let mut watch_interval = 500
  let mut project : String? = None
  let mut report_diagnostics = false
  let mut json_output = false
  let mut external_types_json : String? = None
  let mut external_types_file : String? = None
  let mut json_mode = false
  let mut no_emit = false
  let mut strict = false
  let mut no_implicit_any = false
  let mut strict_null_checks = false
  let mut strict_function_types = false
  let mut import_helpers = false
  let mut i = 1 // Skip program name
  while i < args.length() {
    let arg = args[i]
    if arg == "--version" || arg == "-v" {
      return Ok(Command::Version)
    } else if arg == "--help" || arg == "-h" {
      return Ok(Command::Help)
    } else if arg == "--worker" {
      return Ok(Command::Worker)
    } else if arg == "--json" {
      json_mode = true
      json_output = true // Also set json_output for --list-imports
    } else if arg == "--init" {
      return Ok(Command::Init)
    } else if arg == "--build" || arg == "-b" {
      i = i + 1
      if i >= args.length() {
        return Err("--build requires a path to tsconfig.json")
      }
      let build_path = args[i]
      // Skip remaining args and return build command
      let options : CLIOptions = {
        target: None,
        module_system: None,
        out_dir: None,
        source_map_mode: None,
        declaration: None,
        verbose: false,
        parallel: None,
        watch: false,
        watch_interval: 500,
        report_diagnostics: false,
        json_output: false,
        external_types_json: None,
        external_types_file: None,
        no_emit: false,
        strict: false,
        no_implicit_any: false,
        strict_null_checks: false,
        strict_function_types: false,
        import_helpers: false,
      }
      return Ok(Command::BuildReferences(build_path, options))
    } else if arg == "--list-imports" {
      i = i + 1
      if i >= args.length() {
        return Err("--list-imports requires a file path")
      }
      let file_path = args[i]
      // Check if --json was already parsed or comes after
      let mut list_json = json_output
      // Look ahead for --json flag
      for j = i + 1; j < args.length(); j = j + 1 {
        if args[j] == "--json" {
          list_json = true
          break
        }
      }
      return Ok(Command::ListImports(file_path, list_json))
    } else if arg == "--project" || arg == "-p" {
      i = i + 1
      if i >= args.length() {
        return Err("--project requires a path to tsconfig.json")
      }
      project = Some(args[i])
    } else if arg == "--target" {
      i = i + 1
      if i >= args.length() {
        return Err("--target requires a value")
      }
      target = Some(args[i])
    } else if arg == "--module" {
      i = i + 1
      if i >= args.length() {
        return Err("--module requires a value")
      }
      module_system = Some(args[i])
    } else if arg == "--outDir" {
      i = i + 1
      if i >= args.length() {
        return Err("--outDir requires a value")
      }
      out_dir = Some(args[i])
    } else if arg == "--sourceMap" {
      source_map_mode = Some(SourceMapMode::External)
    } else if arg == "--inlineSourceMap" {
      source_map_mode = Some(SourceMapMode::Inline)
    } else if arg == "--declaration" {
      declaration = Some(true)
    } else if arg == "--verbose" {
      verbose = true
    } else if arg == "--reportDiagnostics" {
      report_diagnostics = true
    } else if arg == "--json" {
      json_output = true
    } else if arg == "--watch" || arg == "-w" {
      watch = true
    } else if arg == "--watchInterval" {
      i = i + 1
      if i >= args.length() {
        return Err("--watchInterval requires a number (milliseconds)")
      }
      try {
        watch_interval = @string.parse_int(args[i])
      } catch {
        _ => return Err("--watchInterval requires a valid number")
      }
    } else if arg == "--parallel" {
      i = i + 1
      if i >= args.length() {
        return Err("--parallel requires a number")
      }
      try {
        parallel = Some(@string.parse_int(args[i]))
      } catch {
        _ => return Err("--parallel requires a valid number")
      }
    } else if arg == "--external-types" {
      i = i + 1
      if i >= args.length() {
        return Err("--external-types requires a JSON string")
      }
      external_types_json = Some(args[i])
    } else if arg == "--external-types-file" {
      i = i + 1
      if i >= args.length() {
        return Err("--external-types-file requires a file path")
      }
      external_types_file = Some(args[i])
    } else if arg == "--noEmit" {
      no_emit = true
    } else if arg == "--strict" {
      strict = true
      // --strict enables all strict type-checking options
      no_implicit_any = true
      strict_null_checks = true
      strict_function_types = true
    } else if arg == "--noImplicitAny" {
      no_implicit_any = true
    } else if arg == "--strictNullChecks" {
      strict_null_checks = true
    } else if arg == "--strictFunctionTypes" {
      strict_function_types = true
    } else if arg == "--importHelpers" {
      import_helpers = true
    } else if arg.has_prefix("-") {
      return Err("Unknown option: " + arg)
    } else {
      files.push(arg)
    }
    i = i + 1
  }
  let options : CLIOptions = {
    target,
    module_system,
    out_dir,
    source_map_mode,
    declaration,
    verbose,
    parallel,
    watch,
    watch_interval,
    report_diagnostics,
    json_output,
    external_types_json,
    external_types_file,
    no_emit,
    strict,
    no_implicit_any,
    strict_null_checks,
    strict_function_types,
    import_helpers,
  }

  // If --project was specified, use project mode
  match project {
    Some(path) => Ok(Command::CompileProject(path, options))
    None =>
      if files.length() == 0 {
        // No files and no project - show help
        Ok(Command::Help)
      } else if json_mode {
        // JSON output mode (used by Phoenix API)
        Ok(Command::JsonCompile(files, options))
      } else {
        Ok(Command::Compile(files, options))
      }
  }
}

///|
/// Get default worker count (4 for now, could use OS CPU count later)
pub fn default_worker_count() -> Int {
  4
}

///|
/// Get effective target from CLI options (with default)
pub fn get_effective_cli_target(options : CLIOptions) -> String {
  options.target.unwrap_or("es2015")
}

///|
/// Get effective source map mode from CLI options
pub fn get_effective_source_map(options : CLIOptions) -> SourceMapMode {
  options.source_map_mode.unwrap_or(SourceMapMode::None)
}

///|
/// Get effective declaration setting from CLI options
pub fn get_effective_declaration(options : CLIOptions) -> Bool {
  options.declaration.unwrap_or(false)
}

///|
/// Get effective module kind from CLI options (with default)
pub fn get_effective_module_kind(options : CLIOptions) -> @compiler.ModuleKind {
  match options.module_system {
    Some(module_str) => @compiler.parse_module_kind(module_str)
    None => @compiler.ESModule // Default to ESModule
  }
}
