// CLI argument parsing

///|
/// Source map output mode
pub(all) enum SourceMapMode {
  None
  External
  Inline
} derive(Show, Eq)

///|
/// CLI command
pub(all) enum Command {
  Compile(Array[String], CLIOptions)
  CompileProject(String, CLIOptions) // tsconfig.json path
  Worker
  Version
  Help
  Init // Generate tsconfig.json (future)
} derive(Show)

///|
/// CLI options for compilation
pub(all) struct CLIOptions {
  target : String?
  out_dir : String?
  source_map_mode : SourceMapMode?
  declaration : Bool?
  verbose : Bool
  parallel : Int?
  watch : Bool
  watch_interval : Int // Polling interval in milliseconds
} derive(Show)

///|
/// Default CLI options
pub fn CLIOptions::default() -> CLIOptions {
  {
    target: None,
    out_dir: None,
    source_map_mode: None,
    declaration: None,
    verbose: false,
    parallel: None,
    watch: false,
    watch_interval: 500, // Default 500ms polling interval
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
  let mut out_dir : String? = None
  let mut source_map_mode : SourceMapMode? = None
  let mut declaration : Bool? = None
  let mut verbose = false
  let mut parallel : Int? = None
  let mut watch = false
  let mut watch_interval = 500
  let mut project : String? = None

  let mut i = 1 // Skip program name

  while i < args.length() {
    let arg = args[i]

    if arg == "--version" || arg == "-v" {
      return Ok(Command::Version)
    } else if arg == "--help" || arg == "-h" {
      return Ok(Command::Help)
    } else if arg == "--worker" {
      return Ok(Command::Worker)
    } else if arg == "--init" {
      return Ok(Command::Init)
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
    } else if arg == "--watch" || arg == "-w" {
      watch = true
    } else if arg == "--watchInterval" {
      i = i + 1
      if i >= args.length() {
        return Err("--watchInterval requires a number (milliseconds)")
      }
      match (try? @strconv.parse_int(args[i])) {
        Ok(n) => watch_interval = n
        Err(_) => return Err("--watchInterval requires a valid number")
      }
    } else if arg == "--parallel" {
      i = i + 1
      if i >= args.length() {
        return Err("--parallel requires a number")
      }
      match (try? @strconv.parse_int(args[i])) {
        Ok(n) => parallel = Some(n)
        Err(_) => return Err("--parallel requires a valid number")
      }
    } else if arg.starts_with("-") {
      return Err("Unknown option: " + arg)
    } else {
      files.push(arg)
    }

    i = i + 1
  }

  let options : CLIOptions = {
    target,
    out_dir,
    source_map_mode,
    declaration,
    verbose,
    parallel,
    watch,
    watch_interval,
  }

  // If --project was specified, use project mode
  match project {
    Some(path) => Ok(Command::CompileProject(path, options))
    None => {
      if files.length() == 0 {
        // No files and no project - show help
        Ok(Command::Help)
      } else {
        Ok(Command::Compile(files, options))
      }
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
