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
/// Run compilation
async fn run_compile(
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
  println("  --help, -h           Show this help message")
  println("  --version, -v        Show version")
  println("  --target <target>    ECMAScript target (es5, es2015, esnext, etc.)")
  println("  --outDir <dir>       Output directory")
  println("  --sourceMap          Generate external source map files")
  println("  --inlineSourceMap    Embed source maps in JavaScript files")
  println("  --declaration        Generate .d.ts declaration files")
  println("  --parallel <n>       Number of parallel workers (default: 4)")
  println("  --verbose            Verbose output")
  println("")
  println("Examples:")
  println("  moonbit-tsc src/index.ts")
  println("  moonbit-tsc --target es5 --sourceMap src/*.ts")
  println("  moonbit-tsc --outDir dist --parallel 8 src/")
}

///|
/// Print usage
fn print_usage() -> Unit {
  println("Usage: moonbit-tsc [options] <file...>")
  println("Try 'moonbit-tsc --help' for more information.")
}
