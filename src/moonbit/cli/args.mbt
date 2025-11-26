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
  Worker
  Version
  Help
} derive(Show)

///|
/// CLI options for compilation
pub(all) struct CLIOptions {
  target : String
  out_dir : String?
  source_map_mode : SourceMapMode
  declaration : Bool
  verbose : Bool
  parallel : Int?
} derive(Show)

///|
/// Default CLI options
pub fn CLIOptions::default() -> CLIOptions {
  {
    target: "es2015",
    out_dir: None,
    source_map_mode: SourceMapMode::None,
    declaration: false,
    verbose: false,
    parallel: None,
  }
}

///|
/// Parse command line arguments
pub fn parse_args(args : Array[String]) -> Result[Command, String] {
  if args.length() < 2 {
    return Ok(Command::Help)
  }

  let files : Array[String] = []
  let mut target = "es2015"
  let mut out_dir : String? = None
  let mut source_map_mode = SourceMapMode::None
  let mut declaration = false
  let mut verbose = false
  let mut parallel : Int? = None

  let mut i = 1 // Skip program name

  while i < args.length() {
    let arg = args[i]

    if arg == "--version" || arg == "-v" {
      return Ok(Command::Version)
    } else if arg == "--help" || arg == "-h" {
      return Ok(Command::Help)
    } else if arg == "--worker" {
      return Ok(Command::Worker)
    } else if arg == "--target" {
      i = i + 1
      if i >= args.length() {
        return Err("--target requires a value")
      }
      target = args[i]
    } else if arg == "--outDir" {
      i = i + 1
      if i >= args.length() {
        return Err("--outDir requires a value")
      }
      out_dir = Some(args[i])
    } else if arg == "--sourceMap" {
      source_map_mode = SourceMapMode::External
    } else if arg == "--inlineSourceMap" {
      source_map_mode = SourceMapMode::Inline
    } else if arg == "--declaration" {
      declaration = true
    } else if arg == "--verbose" {
      verbose = true
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

  if files.length() == 0 {
    return Ok(Command::Help)
  }

  let options : CLIOptions = {
    target,
    out_dir,
    source_map_mode,
    declaration,
    verbose,
    parallel,
  }

  Ok(Command::Compile(files, options))
}

///|
/// Get default worker count (4 for now, could use OS CPU count later)
pub fn default_worker_count() -> Int {
  4
}
