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
  let args = @env.args()

  match parse_args(args) {
    Err(msg) => {
      println("Error: " + msg)
      print_usage()
    }
    Ok(Command::Help) => print_help()
    Ok(Command::Version) => print_version()
    Ok(Command::Worker) => run_worker_mode()
    Ok(Command::Compile(files, options)) => run_compile(files, options)
  }
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
  if options.verbose {
    println("MoonBit TypeScript Compiler v" + @compiler.get_compiler_version())
    println("Target: " + options.target)
    println("")
  }

  // Discover files
  let file_paths = @coordinator.discover_files(file_patterns)

  if file_paths.length() == 0 {
    println("No TypeScript files found")
    return
  }

  if options.verbose {
    println("Found " + file_paths.length().to_string() + " file(s)")
  }

  // Read all files (now uses parallel reading with semaphore)
  let files = @coordinator.read_files(file_paths)

  // Get executable path (self)
  let executable = @env.args()[0]

  // Build coordinator options
  let coord_options = @coordinator.CoordinatorOptions::{
    target: options.target,
    source_map: options.source_map_mode != SourceMapMode::None,
    declaration: options.declaration,
    worker_count: options.parallel.unwrap_or(default_worker_count()),
    verbose: options.verbose,
  }

  // Compile files
  let summary = @coordinator.compile_parallel(executable, files, coord_options)

  // Write output files
  write_all_outputs(summary.results, options)

  // Print summary
  print_summary(summary, options)
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
    return
  }

  @coordinator.print_watch_message(
    "Watching " + file_paths.length().to_string() + " file(s)...",
  )

  // Read all files and build initial dependency graph
  let files = @coordinator.read_files(file_paths)
  let dag = @coordinator.build_dependency_graph(files)

  if options.verbose {
    @coordinator.print_watch_message("Built dependency graph for incremental compilation")
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
  file_paths : Array[String],
  files : Array[(String, String)],
  options : CLIOptions,
) -> Unit raise Error {
  // Get executable path (self)
  let executable = @env.args()[0]

  // Build coordinator options
  let coord_options = @coordinator.CoordinatorOptions::{
    target: options.target,
    source_map: options.source_map_mode != SourceMapMode::None,
    declaration: options.declaration,
    worker_count: options.parallel.unwrap_or(default_worker_count()),
    verbose: options.verbose,
  }

  // Compile files
  let summary = @coordinator.compile_parallel(executable, files, coord_options)

  // Write output files
  write_all_outputs(summary.results, options)

  // Print results
  for result in summary.results {
    if not(result.success) {
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

  // Build coordinator options
  let coord_options = @coordinator.CoordinatorOptions::{
    target: options.target,
    source_map: options.source_map_mode != SourceMapMode::None,
    declaration: options.declaration,
    worker_count: options.parallel.unwrap_or(default_worker_count()),
    verbose: options.verbose,
  }

  // Compile files
  let summary = @coordinator.compile_parallel(executable, files, coord_options)

  // Write output files
  write_all_outputs(summary.results, options)

  // Print results
  for result in summary.results {
    if not(result.success) {
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
  // Print any errors
  for result in summary.results {
    if not(result.success) {
      for diag in result.diagnostics {
        println(diag)
      }
    } else if options.verbose {
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
  if summary.failed == 0 {
    println(
      "Successfully compiled " +
      summary.successful.to_string() +
      " file(s) in " +
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
  println("")
  println("Options:")
  println("  --help, -h              Show this help message")
  println("  --version, -v           Show version")
  println("  --target <target>       ECMAScript target (es5, es2015, esnext, etc.)")
  println("  --outDir <dir>          Output directory")
  println("  --sourceMap             Generate external source map files")
  println("  --inlineSourceMap       Embed source maps in JavaScript files")
  println("  --declaration           Generate .d.ts declaration files")
  println("  --parallel <n>          Number of parallel workers (default: 4)")
  println("  --watch, -w             Watch mode: recompile on file changes")
  println("  --watchInterval <ms>    Watch polling interval in ms (default: 500)")
  println("  --verbose               Verbose output")
  println("")
  println("Examples:")
  println("  moonbit-tsc src/index.ts")
  println("  moonbit-tsc --target es5 --sourceMap src/*.ts")
  println("  moonbit-tsc --outDir dist --parallel 8 src/")
  println("  moonbit-tsc --watch --outDir dist src/")
}

///|
/// Print usage
fn print_usage() -> Unit {
  println("Usage: moonbit-tsc [options] <file...>")
  println("Try 'moonbit-tsc --help' for more information.")
}
