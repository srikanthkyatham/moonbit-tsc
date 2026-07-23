// MoonBit TypeScript Compiler CLI
// Pure MoonBit implementation with process-based parallelism
// Uses moonbitlang/async for file I/O, process spawning, and task coordination

///|
/// Main entry point
fn main {
  @async.run_async_main(async_main)
}

///|
/// Async main function
async fn async_main() -> Unit {
  // Restore default signal dispositions so SIGTERM/SIGINT terminate the
  // process immediately (with the standard signal exit status).
  // By default the moonbitlang/async runtime blocks these signals and turns
  // them into *cooperative* cancellation via the event loop; a long
  // synchronous compilation never reaches a suspension point, which made the
  // CLI un-killable except by SIGKILL (e.g. `timeout 30 cli.exe ...` had no
  // effect). Passing an empty list unblocks the signals process-wide.
  @signal.set_global_cancellation_signals([])
  let args = @env.args()
  match parse_args(args) {
    Err(msg) => {
      println("Error: " + msg)
      print_usage()
      exit(EXIT_FAILURE)
    }
    Ok(Command::Help) =>
      // Check for tsconfig.json auto-detection before showing help
      if try_auto_detect_tsconfig() {
        run_project_compile("tsconfig.json", CLIOptions::default())
      } else {
        print_help()
      }
    Ok(Command::Version) => print_version()
    Ok(Command::Worker) => run_worker_mode()
    Ok(Command::Init) => print_init_message()
    Ok(Command::ListImports(file_path, json_output)) =>
      run_list_imports(file_path, json_output)
    Ok(Command::Compile(files, options)) => run_compile(files, options)
    Ok(Command::JsonCompile(files, options)) => run_json_compile(files, options)
    Ok(Command::CompileProject(tsconfig_path, options)) =>
      run_project_compile(tsconfig_path, options)
    Ok(Command::BuildReferences(tsconfig_path, options)) =>
      run_build_references(tsconfig_path, options)
  }
}

///|
/// Exit with the given code (calls C exit function)
#cfg(target="native")
extern "C" fn exit(code : Int) = "exit"

///|
/// Exit function for JS target (no-op)
#cfg(target="js")
fn exit(_code : Int) -> Unit {
  // JS target doesn't support exit codes
  ()
}

///|
/// Run in worker mode (called by coordinator)
async fn run_worker_mode() -> Unit raise Error {
  @worker.run_worker()
}

///|
/// Run compilation (with optional watch mode)
async fn run_compile(
  file_patterns : Array[String],
  options : CLIOptions,
) -> Unit raise Error {
  if options.watch {
    run_watch_mode(file_patterns, options)
  } else {
    run_single_compile(file_patterns, options)
  }
}

///|
/// Run a single compilation pass
async fn run_single_compile(
  file_patterns : Array[String],
  options : CLIOptions,
) -> Unit raise Error {
  let target = get_effective_cli_target(options)
  if options.verbose {
    println("MoonBit TypeScript Compiler v" + @compiler.get_compiler_version())
    println("Target: " + target)
    println("")
  }

  // Discover files
  let file_paths = @coordinator.discover_files(file_patterns)
  if file_paths.length() == 0 {
    println("No TypeScript files found")
    exit(EXIT_FAILURE)
    return
  }
  if options.verbose {
    println("Found " + file_paths.length().to_string() + " file(s)")
  }

  // Read all files (now uses parallel reading with semaphore)
  let files = @coordinator.read_files(file_paths)

  // Collect triple-slash reference paths and load any additional .d.ts files
  let reference_paths = @coordinator.collect_reference_paths(files)
  let new_refs = @coordinator.filter_new_references(reference_paths, file_paths)

  // Load referenced .d.ts files
  let all_files = if new_refs.length() > 0 {
    if options.verbose {
      println(
        "Loading " +
        new_refs.length().to_string() +
        " referenced declaration file(s)",
      )
    }
    let ref_files = @coordinator.read_files(new_refs)
    // Combine original files with referenced files
    let combined : Array[(String, String)] = []
    for f in ref_files {
      combined.push(f)
    }
    for f in files {
      combined.push(f)
    }
    combined
  } else {
    files
  }

  // Get executable path (self)
  let executable = @env.args()[0]

  // Build coordinator options from CLI options
  let coord_options = build_coordinator_options(options)

  // Compile files
  let summary = @coordinator.compile_parallel(
    executable, all_files, coord_options,
  )

  // Validate relative imports across the compiled file set (multi-file only)
  let summary = if all_files.length() > 1 {
    apply_cross_file_import_diagnostics(summary, all_files)
  } else {
    summary
  }

  // Write output files
  write_all_outputs(summary.results, options)

  // Print summary
  print_summary(summary, options)
}

///|
/// Run JSON compilation mode (used by Phoenix API)
/// Reads files, discovers referenced .d.ts files, compiles, and outputs JSON
async fn run_json_compile(
  file_paths : Array[String],
  options : CLIOptions,
) -> Unit raise Error {
  // Read all files
  let files = @coordinator.read_files(file_paths)

  // Collect triple-slash reference paths and load any additional .d.ts files
  let reference_paths = @coordinator.collect_reference_paths(files)
  let new_refs = @coordinator.filter_new_references(reference_paths, file_paths)

  // Load referenced .d.ts files
  let all_files = if new_refs.length() > 0 {
    let ref_files = @coordinator.read_files(new_refs)
    // Combine original files with referenced files (refs first for proper ordering)
    let combined : Array[(String, String)] = []
    for f in ref_files {
      combined.push(f)
    }
    for f in files {
      combined.push(f)
    }
    combined
  } else {
    files
  }

  // Build coordinator options
  let coord_options = build_coordinator_options(options)

  // Get executable path (self)
  let executable = @env.args()[0]

  // Compile files
  let summary = @coordinator.compile_parallel(
    executable, all_files, coord_options,
  )

  // Output JSON response
  print_json_summary(summary)

  // Exit with error code if there were errors
  exit_if_errors(summary)
}

///|
/// Run watch mode - continuously monitor files and recompile on changes
/// Uses a dependency graph for smart incremental compilation
async fn run_watch_mode(
  file_patterns : Array[String],
  options : CLIOptions,
) -> Unit raise Error {
  println("MoonBit TypeScript Compiler v" + @compiler.get_compiler_version())
  println("Starting watch mode with incremental compilation...")
  println("")

  // Initial compilation
  let file_paths = @coordinator.discover_files(file_patterns)
  if file_paths.length() == 0 {
    println("No TypeScript files found")
    exit(EXIT_FAILURE)
    return
  }
  @coordinator.print_watch_message(
    "Watching " + file_paths.length().to_string() + " file(s)...",
  )

  // Read all files and build initial dependency graph
  let files = @coordinator.read_files(file_paths)
  let dag = @coordinator.build_dependency_graph(files)
  if options.verbose {
    @coordinator.print_watch_message(
      "Built dependency graph for incremental compilation",
    )
  }

  // Initialize watch state
  let watch_state = @coordinator.init_watch_state(file_paths)

  // Do initial compilation of all files
  compile_files_with_dag(file_paths, files, options)
  @coordinator.print_watch_message("Waiting for file changes...")

  // Watch loop
  while true {
    // Sleep for the watch interval
    @coordinator.sleep_ms(options.watch_interval)

    // Re-discover files (in case new files were added)
    let current_paths = @coordinator.discover_files(file_patterns)

    // Add any new files to watch state
    @coordinator.add_files_to_watch(watch_state, current_paths)

    // Check for changes
    let changed = @coordinator.check_for_changes(watch_state)
    if changed.length() > 0 {
      @coordinator.print_watch_message(
        "File change detected: " + changed.length().to_string() + " file(s)",
      )

      // Update watch state with new timestamps
      @coordinator.update_watch_state(watch_state, changed)

      // Read the changed files
      let changed_files = @coordinator.read_files(changed)

      // Update dependency graph for changed files
      for file in changed_files {
        let (path, source) = file // read_files returns (path, content)
        let result = @coordinator.extract_imports(source, path)
        let content_hash = @coordinator.hash_source(source)
        let resolved_imports : Array[String] = []
        for module_spec in result.imports {
          match @coordinator.resolve_import_path(module_spec, path) {
            Some(resolved) => resolved_imports.push(resolved)
            None => ()
          }
        }
        @coordinator.add_node(dag, path, resolved_imports, content_hash)
      }

      // Get all files that need recompilation (changed + dependents) in order
      let to_recompile = @coordinator.get_recompilation_order(dag, changed)
      if options.verbose {
        @coordinator.print_watch_message(
          "Recompiling " +
          to_recompile.length().to_string() +
          " file(s) including dependents",
        )
      }

      // Read all files that need recompilation
      let files_to_compile = @coordinator.read_files(to_recompile)

      // Recompile files in topological order
      compile_files_with_dag(to_recompile, files_to_compile, options)
      @coordinator.print_watch_message("Waiting for file changes...")
    }
  }
}

///|
/// Compile files with a pre-read file list
async fn compile_files_with_dag(
  _file_paths : Array[String],
  files : Array[(String, String)],
  options : CLIOptions,
) -> Unit raise Error {
  // Get executable path (self)
  let executable = @env.args()[0]

  // Build coordinator options from CLI options
  let coord_options = build_coordinator_options(options)

  // Compile files
  let summary = @coordinator.compile_parallel(executable, files, coord_options)

  // Write output files
  write_all_outputs(summary.results, options)

  // Print results
  for result in summary.results {
    if !(result.success) {
      for diag in result.diagnostics {
        println(diag)
      }
    } else if options.verbose {
      println("  Compiled: " + result.file_path)
    }
  }
  if summary.failed == 0 {
    @coordinator.print_watch_message(
      "Compiled " +
      summary.successful.to_string() +
      " file(s) in " +
      summary.total_time_ms.to_string() +
      "ms",
    )
  } else {
    @coordinator.print_watch_message(
      "Compiled " +
      summary.successful.to_string() +
      ", failed " +
      summary.failed.to_string() +
      " in " +
      summary.total_time_ms.to_string() +
      "ms",
    )
  }
}

///|
/// Compile a list of files and output results
async fn compile_files(
  file_paths : Array[String],
  options : CLIOptions,
) -> Unit raise Error {
  // Read files
  let files = @coordinator.read_files(file_paths)

  // Get executable path (self)
  let executable = @env.args()[0]

  // Build coordinator options from CLI options
  let coord_options = build_coordinator_options(options)

  // Compile files
  let summary = @coordinator.compile_parallel(executable, files, coord_options)

  // Write output files
  write_all_outputs(summary.results, options)

  // Print results
  for result in summary.results {
    if !(result.success) {
      for diag in result.diagnostics {
        println(diag)
      }
    } else if options.verbose {
      println("  Compiled: " + result.file_path)
    }
  }
  if summary.failed == 0 {
    @coordinator.print_watch_message(
      "Compiled " +
      summary.successful.to_string() +
      " file(s) in " +
      summary.total_time_ms.to_string() +
      "ms",
    )
  } else {
    @coordinator.print_watch_message(
      "Compiled " +
      summary.successful.to_string() +
      ", failed " +
      summary.failed.to_string() +
      " in " +
      summary.total_time_ms.to_string() +
      "ms",
    )
  }
}

///|
/// Print compilation summary
fn print_summary(
  summary : @coordinator.CompilationSummary,
  options : CLIOptions,
) -> Unit {
  // If JSON output mode, use JSON format
  if options.json_output {
    print_json_summary(summary)
    // Exit with error code if there were errors (even in JSON mode)
    exit_if_errors(summary)
    return
  }

  // Track total diagnostics for summary
  let mut total_errors = 0
  let mut total_warnings = 0

  // Print any errors
  for result in summary.results {
    // Count diagnostics
    for diag in result.diagnostics {
      if is_error_diagnostic(diag) {
        total_errors = total_errors + 1
      } else if is_warning_diagnostic(diag) {
        total_warnings = total_warnings + 1
      }
    }

    // Print diagnostics if failed OR if --reportDiagnostics is set
    if !(result.success) || options.report_diagnostics {
      for diag in result.diagnostics {
        println(diag)
      }
    }

    // Print compile info if verbose
    if options.verbose && result.success {
      println(
        "  Compiled: " +
        result.file_path +
        " (" +
        result.compile_time_ms.to_string() +
        "ms)",
      )
    }
  }

  // Print final summary
  println("")
  if summary.failed == 0 && total_errors == 0 {
    println(
      "Successfully compiled " +
      summary.successful.to_string() +
      " file(s) in " +
      summary.total_time_ms.to_string() +
      "ms",
    )
  } else if summary.failed == 0 && total_errors > 0 {
    // Type errors but compilation succeeded (TypeScript behavior)
    println(
      "Compiled " +
      summary.successful.to_string() +
      " file(s) with " +
      total_errors.to_string() +
      " error(s) in " +
      summary.total_time_ms.to_string() +
      "ms",
    )
  } else {
    println(
      "Compiled " +
      summary.successful.to_string() +
      " file(s), " +
      summary.failed.to_string() +
      " failed in " +
      summary.total_time_ms.to_string() +
      "ms",
    )
  }

  // Print diagnostic counts if any
  if options.report_diagnostics && (total_errors > 0 || total_warnings > 0) {
    let mut msg = "Found "
    if total_errors > 0 {
      msg = msg + total_errors.to_string() + " error(s)"
    }
    if total_warnings > 0 {
      if total_errors > 0 {
        msg = msg + ", "
      }
      msg = msg + total_warnings.to_string() + " warning(s)"
    }
    println(msg)
  }

  // Exit with error code if there were errors
  exit_if_errors(summary)
}

///|
/// Print version
fn print_version() -> Unit {
  println("moonbit-tsc " + @compiler.get_compiler_version())
}

///|
/// Print help
fn print_help() -> Unit {
  println("MoonBit TypeScript Compiler")
  println("")
  println("Usage: moonbit-tsc [options] <file...>")
  println("       moonbit-tsc --project <tsconfig.json>")
  println("       moonbit-tsc --build <tsconfig.json>")
  println("")
  println("Options:")
  println("  --help, -h              Show this help message")
  println("  --version, -v           Show version")
  println("  --project, -p <path>    Compile project from tsconfig.json")
  println("  --build, -b <path>      Build project with all references")
  println("  --list-imports <file>   List all imports from a TypeScript file")
  println(
    "  --target <target>       ECMAScript target (es5, es2015, esnext, etc.)",
  )
  println(
    "  --module <module>       Module system (commonjs, es2015, esnext, etc.)",
  )
  println("  --outDir <dir>          Output directory")
  println("  --sourceMap             Generate external source map files")
  println("  --inlineSourceMap       Embed source maps in JavaScript files")
  println("  --declaration           Generate .d.ts declaration files")
  println("  --parallel <n>          Number of parallel workers (default: 4)")
  println("  --watch, -w             Watch mode: recompile on file changes")
  println(
    "  --watchInterval <ms>    Watch polling interval in ms (default: 500)",
  )
  println("  --verbose               Verbose output")
  println("  --reportDiagnostics     Report all diagnostics (errors/warnings)")
  println(
    "  --json                  Output results as JSON for tooling integration",
  )
  println(
    "  --external-types <json> JSON string with external types for cross-file checking",
  )
  println("  --init                  Generate tsconfig.json (future)")
  println("")
  println("Examples:")
  println("  moonbit-tsc src/index.ts")
  println("  moonbit-tsc --target es5 --sourceMap src/*.ts")
  println("  moonbit-tsc --outDir dist --parallel 8 src/")
  println("  moonbit-tsc --watch --outDir dist src/")
  println("  moonbit-tsc --project tsconfig.json")
  println("  moonbit-tsc -p ./tsconfig.build.json --verbose")
  println("  moonbit-tsc --build tsconfig.json        # Build with references")
  println(
    "  moonbit-tsc --json src/index.ts          # JSON output for tooling",
  )
}

///|
/// Print usage
fn print_usage() -> Unit {
  println("Usage: moonbit-tsc [options] <file...>")
  println("Try 'moonbit-tsc --help' for more information.")
}

///|
/// Print init message (future feature)
fn print_init_message() -> Unit {
  println("The --init feature is not yet implemented.")
  println("Please create a tsconfig.json file manually.")
}

///|
/// List imports from a TypeScript file
async fn run_list_imports(
  file_path : String,
  json_output : Bool,
) -> Unit raise Error {
  // Read the file
  let data = @fs.read_file(file_path)
  let source = data.text()

  // Scan and parse the file
  let tokens = @compiler.scan_all_v2(source, file_path)
  match @compiler.parse_source_file(tokens, file_path) {
    Ok(source_file) => {
      // Get imports using the new API
      let imports = @compiler.get_imports(source_file)
      if json_output {
        // JSON output format
        print_list_imports_json(file_path, imports)
        // Text output format
      } else if imports.length() == 0 {
        println("No imports found in " + file_path)
      } else {
        println("Imports in " + file_path + ":")
        for import_decl in imports {
          let type_prefix = if import_decl.is_type_only {
            "(type) "
          } else {
            ""
          }
          println("  " + type_prefix + import_decl.module_specifier)
        }
      }
    }
    Err(_) => {
      if json_output {
        println(
          "{\"file\": \"" +
          escape_json_string(file_path) +
          "\", \"error\": \"Failed to parse file\", \"imports\": []}",
        )
      } else {
        println("Error: Failed to parse " + file_path)
      }
      exit(EXIT_FAILURE)
    }
  }
}

///|
/// Print imports in JSON format
fn print_list_imports_json(
  file_path : String,
  imports : Array[@compiler.ImportDeclaration],
) -> Unit {
  let mut json = "{\n"
  json = json + "  \"file\": \"" + escape_json_string(file_path) + "\",\n"
  json = json + "  \"imports\": ["
  if imports.length() > 0 {
    json = json + "\n"
    for i, import_decl in imports {
      json = json + "    {\n"
      json = json +
        "      \"moduleSpecifier\": \"" +
        escape_json_string(import_decl.module_specifier) +
        "\",\n"
      json = json +
        "      \"isTypeOnly\": " +
        import_decl.is_type_only.to_string()

      // Add import clause details if present
      match import_decl.import_clause {
        Some(clause) => {
          json = json + ",\n"
          // Default import name
          match clause.name {
            Some(name) =>
              json = json +
                "      \"defaultImport\": \"" +
                escape_json_string(name) +
                "\""
            None => json = json + "      \"defaultImport\": null"
          }

          // Named bindings
          match clause.named_bindings {
            Some(@compiler.NamedImports::NamedImports(specifiers, _)) => {
              json = json + ",\n      \"namedImports\": ["
              for j, spec in specifiers {
                json = json + "\"" + escape_json_string(spec.name) + "\""
                if j < specifiers.length() - 1 {
                  json = json + ", "
                }
              }
              json = json + "]"
            }
            Some(@compiler.NamespaceImport(ns_name, _)) =>
              json = json +
                ",\n      \"namespaceImport\": \"" +
                escape_json_string(ns_name) +
                "\""
            None => ()
          }
        }
        None => ()
      }
      json = json + "\n    }"
      if i < imports.length() - 1 {
        json = json + ","
      }
      json = json + "\n"
    }
    json = json + "  "
  }
  json = json + "]\n}"
  println(json)
}

///|
/// Escape a string for JSON output
fn escape_json_string(s : String) -> String {
  @compiler.escape_json_string(s)
}

///|
/// Build CoordinatorOptions from CLIOptions
fn build_coordinator_options(
  options : CLIOptions,
) -> @coordinator.CoordinatorOptions {
  let source_map_mode = get_effective_source_map(options)
  let module_kind = get_effective_module_kind(options)
  @coordinator.CoordinatorOptions::{
    target: get_effective_cli_target(options),
    module_kind,
    source_map: source_map_mode != SourceMapMode::None,
    inline_source_map: source_map_mode == SourceMapMode::Inline,
    inline_sources: false, // Default to false for CLI
    declaration: get_effective_declaration(options),
    always_strict: false, // Default to false for CLI
    es_module_interop: false, // Default to false for CLI
    worker_count: options.parallel.unwrap_or(default_worker_count()),
    verbose: options.verbose,
    external_types_json: options.external_types_json,
    no_emit: options.no_emit,
    no_implicit_any: options.no_implicit_any,
    import_helpers: options.import_helpers,
  }
}

///|
/// Build CoordinatorOptions from TSConfig with CLI overrides
fn build_coordinator_options_from_tsconfig(
  tsconfig : @config.TSConfig,
  cli_options : CLIOptions,
) -> @coordinator.CoordinatorOptions {
  // Get effective target: CLI overrides tsconfig
  let target = match cli_options.target {
    Some(t) => t
    None =>
      match tsconfig.compiler_options {
        Some(opts) => @config.get_target_string(opts)
        None => "es2015"
      }
  }

  // Get effective source map: CLI overrides tsconfig
  let source_map = match cli_options.source_map_mode {
    Some(mode) => mode != SourceMapMode::None
    None =>
      match tsconfig.compiler_options {
        Some(opts) => @config.is_source_map_enabled(opts)
        None => false
      }
  }

  // Get effective declaration: CLI overrides tsconfig
  let declaration = match cli_options.declaration {
    Some(d) => d
    None =>
      match tsconfig.compiler_options {
        Some(opts) => @config.is_declaration_enabled(opts)
        None => false
      }
  }

  // Get module kind from tsconfig
  let module_kind : @compiler.ModuleKind = match tsconfig.compiler_options {
    Some(opts) =>
      match opts.module_kind {
        Some(@config.CommonJS) => @compiler.CommonJS
        _ => @compiler.ESModule
      } // Default to ESModule
    None => @compiler.ESModule
  }

  // Get always_strict from tsconfig (from strict or alwaysStrict flags)
  let always_strict = match tsconfig.compiler_options {
    Some(opts) =>
      opts.always_strict.unwrap_or(false) || opts.strict.unwrap_or(false)
    None => false
  }

  // Get inline source map from tsconfig or CLI
  let inline_source_map = match cli_options.source_map_mode {
    Some(SourceMapMode::Inline) => true
    Some(_) => false
    None =>
      match tsconfig.compiler_options {
        Some(opts) => opts.inline_source_map.unwrap_or(false)
        None => false
      }
  }

  // Get inline sources from tsconfig
  let inline_sources = match tsconfig.compiler_options {
    Some(opts) => opts.inline_sources.unwrap_or(false)
    None => false
  }

  // Get esModuleInterop from tsconfig
  let es_module_interop = match tsconfig.compiler_options {
    Some(opts) => opts.es_module_interop.unwrap_or(false)
    None => false
  }
  // Get noEmit from tsconfig if not specified in CLI
  let no_emit = if cli_options.no_emit {
    true
  } else {
    match tsconfig.compiler_options {
      Some(opts) => opts.no_emit.unwrap_or(false)
      None => false
    }
  }
  // Get noImplicitAny from tsconfig or CLI
  let no_implicit_any = if cli_options.no_implicit_any {
    true
  } else {
    match tsconfig.compiler_options {
      Some(opts) => opts.no_implicit_any.unwrap_or(false)
      None => false
    }
  }
  // Get importHelpers from tsconfig or CLI
  let import_helpers = if cli_options.import_helpers {
    true
  } else {
    match tsconfig.compiler_options {
      Some(opts) => opts.import_helpers.unwrap_or(false)
      None => false
    }
  }
  @coordinator.CoordinatorOptions::{
    target,
    module_kind,
    source_map: source_map || inline_source_map, // Enable source map generation for inline too
    inline_source_map,
    inline_sources,
    declaration,
    always_strict,
    es_module_interop,
    worker_count: cli_options.parallel.unwrap_or(default_worker_count()),
    verbose: cli_options.verbose,
    external_types_json: cli_options.external_types_json,
    no_emit,
    no_implicit_any,
    import_helpers,
  }
}

///|
/// Build CLIOptions from TSConfig with CLI overrides (for output writing)
/// If project_dir is provided, relative out_dir paths are resolved against it
fn build_cli_options_from_tsconfig(
  tsconfig : @config.TSConfig,
  cli_options : CLIOptions,
  project_dir? : String? = None,
) -> CLIOptions {
  // Get outDir from tsconfig if not specified in CLI
  let out_dir = match cli_options.out_dir {
    Some(_) => cli_options.out_dir
    None =>
      match tsconfig.compiler_options {
        Some(opts) =>
          match opts.out_dir {
            Some(dir) =>
              // Resolve relative paths against project directory
              match project_dir {
                Some(proj_dir) =>
                  if dir.length() > 0 && !(dir.has_prefix("/")) {
                    // Relative path - resolve against project dir
                    Some(proj_dir + "/" + dir)
                  } else {
                    Some(dir)
                  }
                None => Some(dir)
              }
            None => None
          }
        None => None
      }
  }

  // Get source map mode
  let source_map_mode = match cli_options.source_map_mode {
    Some(_) => cli_options.source_map_mode
    None =>
      match tsconfig.compiler_options {
        Some(opts) =>
          if opts.inline_source_map.unwrap_or(false) {
            Some(SourceMapMode::Inline)
          } else if opts.source_map.unwrap_or(false) {
            Some(SourceMapMode::External)
          } else {
            Some(SourceMapMode::None)
          }
        None => Some(SourceMapMode::None)
      }
  }
  { ..cli_options, out_dir, source_map_mode }
}

///|
/// Run project compilation from tsconfig.json
async fn run_project_compile(
  tsconfig_path : String,
  cli_options : CLIOptions,
) -> Unit raise Error {
  if cli_options.verbose {
    println("MoonBit TypeScript Compiler v" + @compiler.get_compiler_version())
    println("Loading project: " + tsconfig_path)
    println("")
  }

  // Parse tsconfig.json with extends resolution
  let tsconfig = @config.load_tsconfig_with_extends(tsconfig_path)

  // Get project directory (for resolving relative paths)
  let project_dir = get_tsconfig_directory(tsconfig_path)

  // Build effective options
  let coord_options = build_coordinator_options_from_tsconfig(
    tsconfig, cli_options,
  )
  let effective_cli = build_cli_options_from_tsconfig(
    tsconfig,
    cli_options,
    project_dir=Some(project_dir),
  )
  if cli_options.verbose {
    println("Target: " + coord_options.target)
    println("Source maps: " + coord_options.source_map.to_string())
    println("Declarations: " + coord_options.declaration.to_string())
    println("")
  }

  // Discover files based on tsconfig
  let file_paths = discover_project_files(tsconfig, project_dir)
  if file_paths.length() == 0 {
    println("No TypeScript files found in project")
    exit(EXIT_FAILURE)
    return
  }
  if cli_options.verbose {
    println("Found " + file_paths.length().to_string() + " file(s)")
  }

  // Check if watch mode
  if cli_options.watch {
    run_project_watch_mode(file_paths, effective_cli, coord_options)
  } else {
    run_project_single_compile(file_paths, effective_cli, coord_options)
  }
}

///|
/// Run single project compilation
async fn run_project_single_compile(
  file_paths : Array[String],
  options : CLIOptions,
  coord_options : @coordinator.CoordinatorOptions,
) -> Unit raise Error {
  // Read all files
  let files = @coordinator.read_files(file_paths)

  // Collect triple-slash reference paths and load any additional .d.ts files
  let reference_paths = @coordinator.collect_reference_paths(files)
  let new_refs = @coordinator.filter_new_references(reference_paths, file_paths)

  // Load referenced .d.ts files
  let all_files = if new_refs.length() > 0 {
    if options.verbose {
      println(
        "Loading " +
        new_refs.length().to_string() +
        " referenced declaration file(s)",
      )
    }
    let ref_files = @coordinator.read_files(new_refs)
    // Combine original files with referenced files (refs first for proper ordering)
    let combined : Array[(String, String)] = []
    for f in ref_files {
      combined.push(f)
    }
    for f in files {
      combined.push(f)
    }
    combined
  } else {
    files
  }

  // Get executable path (self)
  let executable = @env.args()[0]

  // Compile files
  let summary = @coordinator.compile_parallel(
    executable, all_files, coord_options,
  )

  // Write output files
  write_all_outputs(summary.results, options)

  // Print summary
  print_summary(summary, options)
}

///|
/// Run project watch mode
async fn run_project_watch_mode(
  file_paths : Array[String],
  options : CLIOptions,
  coord_options : @coordinator.CoordinatorOptions,
) -> Unit raise Error {
  println("Starting watch mode with incremental compilation...")
  println("")
  @coordinator.print_watch_message(
    "Watching " + file_paths.length().to_string() + " file(s)...",
  )

  // Read all files and build initial dependency graph
  let files = @coordinator.read_files(file_paths)
  let dag = @coordinator.build_dependency_graph(files)
  if options.verbose {
    @coordinator.print_watch_message(
      "Built dependency graph for incremental compilation",
    )
  }

  // Initialize watch state
  let watch_state = @coordinator.init_watch_state(file_paths)

  // Do initial compilation
  compile_project_files(file_paths, files, options, coord_options)
  @coordinator.print_watch_message("Waiting for file changes...")

  // Watch loop
  while true {
    @coordinator.sleep_ms(options.watch_interval)

    // Check for changes
    let changed = @coordinator.check_for_changes(watch_state)
    if changed.length() > 0 {
      @coordinator.print_watch_message(
        "File change detected: " + changed.length().to_string() + " file(s)",
      )

      // Update watch state
      @coordinator.update_watch_state(watch_state, changed)

      // Read changed files and update DAG
      let changed_files = @coordinator.read_files(changed)
      for file in changed_files {
        let (path, source) = file
        let result = @coordinator.extract_imports(source, path)
        let content_hash = @coordinator.hash_source(source)
        let resolved_imports : Array[String] = []
        for module_spec in result.imports {
          match @coordinator.resolve_import_path(module_spec, path) {
            Some(resolved) => resolved_imports.push(resolved)
            None => ()
          }
        }
        @coordinator.add_node(dag, path, resolved_imports, content_hash)
      }

      // Get files to recompile
      let to_recompile = @coordinator.get_recompilation_order(dag, changed)
      if options.verbose {
        @coordinator.print_watch_message(
          "Recompiling " +
          to_recompile.length().to_string() +
          " file(s) including dependents",
        )
      }

      // Read and compile
      let files_to_compile = @coordinator.read_files(to_recompile)
      compile_project_files(
        to_recompile, files_to_compile, options, coord_options,
      )
      @coordinator.print_watch_message("Waiting for file changes...")
    }
  }
}

///|
/// Compile project files with given options
async fn compile_project_files(
  _file_paths : Array[String],
  files : Array[(String, String)],
  options : CLIOptions,
  coord_options : @coordinator.CoordinatorOptions,
) -> Unit raise Error {
  let executable = @env.args()[0]
  let summary = @coordinator.compile_parallel(executable, files, coord_options)

  // Write output files
  write_all_outputs(summary.results, options)

  // Print results
  for result in summary.results {
    if !(result.success) {
      for diag in result.diagnostics {
        println(diag)
      }
    } else if options.verbose {
      println("  Compiled: " + result.file_path)
    }
  }
  if summary.failed == 0 {
    @coordinator.print_watch_message(
      "Compiled " +
      summary.successful.to_string() +
      " file(s) in " +
      summary.total_time_ms.to_string() +
      "ms",
    )
  } else {
    @coordinator.print_watch_message(
      "Compiled " +
      summary.successful.to_string() +
      ", failed " +
      summary.failed.to_string() +
      " in " +
      summary.total_time_ms.to_string() +
      "ms",
    )
  }
}

///|
/// Discover files for a project based on tsconfig
async fn discover_project_files(
  tsconfig : @config.TSConfig,
  project_dir : String,
) -> Array[String] raise Error {
  // If explicit files list is provided, use it
  match tsconfig.files {
    Some(files) if files.length() > 0 => {
      let result : Array[String] = []
      for file in files {
        let full_path = resolve_path(project_dir, file)
        if @coordinator.is_typescript_file(full_path) {
          result.push(full_path)
        }
      }
      return result
    }
    _ => ()
  }

  // Get include and exclude patterns
  let include_patterns = @config.get_effective_include(tsconfig)
  let exclude_patterns = @config.get_effective_exclude(tsconfig)

  // Walk the project directory and collect all TypeScript files
  let all_files = @coordinator.discover_files([project_dir])

  // Filter based on include and exclude patterns
  let filtered : Array[String] = []
  for file in all_files {
    // Get relative path for pattern matching
    let rel_path = @config.get_relative_path(project_dir, file)

    // Check if file matches any include pattern
    let matches_include = if include_patterns.length() == 0 {
      true // No include patterns means include all
    } else {
      @config.matches_any_pattern(include_patterns, rel_path)
    }

    // Check if file should be excluded
    let matches_exclude = @config.should_exclude(exclude_patterns, rel_path)

    // Include file if it matches include patterns and doesn't match exclude
    if matches_include && !(matches_exclude) {
      filtered.push(file)
    }
  }
  filtered
}

///|
/// Get directory from a tsconfig path
fn get_tsconfig_directory(path : String) -> String {
  let mut last_slash = -1
  for i = 0; i < path.length(); i = i + 1 {
    if path[i] == '/' || path[i] == '\\' {
      last_slash = i
    }
  }
  if last_slash == -1 {
    "."
  } else {
    @utils.substr(path, end=last_slash)
  }
}

///|
/// Resolve a relative path against a base directory
fn resolve_path(base_dir : String, relative_path : String) -> String {
  if relative_path.has_prefix("/") || relative_path.has_prefix("\\") {
    relative_path
  } else if relative_path.has_prefix("./") {
    base_dir + "/" + @utils.substr(relative_path, start=2)
  } else if relative_path.has_prefix(".\\") {
    base_dir + "/" + @utils.substr(relative_path, start=2)
  } else {
    base_dir + "/" + relative_path
  }
}

///|
/// Try to auto-detect tsconfig.json in current directory
async fn try_auto_detect_tsconfig() -> Bool {
  // Check if tsconfig.json exists in current directory
  @fs.exists("tsconfig.json")
}

///|
/// Run build with project references
/// Builds all referenced projects in topological order
async fn run_build_references(
  tsconfig_path : String,
  cli_options : CLIOptions,
) -> Unit raise Error {
  println("MoonBit TypeScript Compiler v" + @compiler.get_compiler_version())
  println("Building project with references: " + tsconfig_path)
  println("")

  // Load project graph with all references
  let graph = @config.load_project_graph(tsconfig_path)
  if graph.projects.length() == 0 {
    println("No projects found")
    exit(EXIT_FAILURE)
    return
  }
  println(
    "Found " + graph.projects.length().to_string() + " project(s) to build",
  )
  println("")

  // Build projects in topological order
  let mut total_files = 0
  let mut total_success = 0
  let mut total_failed = 0
  let mut has_errors = false
  let start_time = @async.now()
  for project_path in graph.build_order {
    // Find the project config
    let mut project_config : @config.TSConfig? = None
    for project in graph.projects {
      if project.path == project_path {
        project_config = Some(project.config)
        break
      }
    }
    guard project_config is Some(config) else { continue }

    // Get project directory
    let project_dir = get_tsconfig_directory(project_path)
    println("Building: " + project_path)

    // Build coordinator options from config
    let coord_options = build_coordinator_options_from_tsconfig(
      config, cli_options,
    )
    let effective_cli = build_cli_options_from_tsconfig(
      config,
      cli_options,
      project_dir=Some(project_dir),
    )

    // Discover files for this project
    let file_paths = discover_project_files(config, project_dir)
    if file_paths.length() == 0 {
      println("  No files to compile")
      continue
    }
    println("  Found " + file_paths.length().to_string() + " file(s)")

    // Read and compile files
    let files = @coordinator.read_files(file_paths)
    let executable = @env.args()[0]
    let summary = @coordinator.compile_parallel(
      executable, files, coord_options,
    )

    // Write output files
    write_all_outputs(summary.results, effective_cli)

    // Update totals
    total_files = total_files + summary.total_files
    total_success = total_success + summary.successful
    total_failed = total_failed + summary.failed
    if compute_exit_code(summary) != EXIT_SUCCESS {
      has_errors = true
    }

    // Print project result
    if summary.failed == 0 {
      println(
        "  Compiled " +
        summary.successful.to_string() +
        " file(s) in " +
        summary.total_time_ms.to_string() +
        "ms",
      )
    } else {
      // Print errors
      for result in summary.results {
        if !(result.success) {
          for diag in result.diagnostics {
            println("  " + diag)
          }
        }
      }
      println(
        "  Compiled " +
        summary.successful.to_string() +
        ", failed " +
        summary.failed.to_string(),
      )
    }
    println("")
  }
  let end_time = @async.now()
  let total_time = end_time - start_time

  // Print final summary
  println("Build complete:")
  println("  Projects: " + graph.projects.length().to_string())
  println("  Total files: " + total_files.to_string())
  println("  Successful: " + total_success.to_string())
  if total_failed > 0 {
    println("  Failed: " + total_failed.to_string())
  }
  println("  Total time: " + total_time.to_string() + "ms")

  // Exit with error code if any project had failures or error diagnostics
  if has_errors {
    exit(EXIT_FAILURE)
  }
}
