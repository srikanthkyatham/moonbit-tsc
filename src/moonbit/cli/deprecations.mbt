// Deprecated compiler-option diagnostics (TS5107), matching tsc 6.x.
//
// tsc emits a global "error TS5107: Option '<name>=<value>' is deprecated..."
// when an explicitly supplied option value is deprecated (target=ES3/ES5,
// module=AMD/UMD/System/None, ...). Only options actually passed on the
// command line trigger the error — internal defaults never do. The error is
// suppressed by --ignoreDeprecations.

///|
const DEPRECATION_SUFFIX : String = "' is deprecated and will stop functioning in TypeScript 7.0. Specify compilerOption '\"ignoreDeprecations\": \"6.0\"' to silence this error."

///|
/// Canonical tsc spelling of a deprecated target value, if deprecated
fn deprecated_target_name(value : String) -> String? {
  match value.to_lower() {
    "es3" => Some("ES3")
    "es5" => Some("ES5")
    _ => None
  }
}

///|
/// Canonical tsc spelling of a deprecated module value, if deprecated
fn deprecated_module_name(value : String) -> String? {
  match value.to_lower() {
    "amd" => Some("AMD")
    "umd" => Some("UMD")
    "system" => Some("System")
    "none" => Some("None")
    _ => None
  }
}

///|
/// Diagnostics for deprecated option values explicitly passed on the CLI.
/// Empty when nothing deprecated was passed or --ignoreDeprecations is set.
pub fn option_deprecation_diags(options : CLIOptions) -> Array[String] {
  let diags : Array[String] = []
  if options.ignore_deprecations {
    return diags
  }
  match options.target {
    Some(t) =>
      match deprecated_target_name(t) {
        Some(name) =>
          diags.push(
            "error TS5107: Option 'target=" + name + DEPRECATION_SUFFIX,
          )
        None => ()
      }
    None => ()
  }
  match options.module_system {
    Some(m) =>
      match deprecated_module_name(m) {
        Some(name) =>
          diags.push(
            "error TS5107: Option 'module=" + name + DEPRECATION_SUFFIX,
          )
        None => ()
      }
    None => ()
  }
  diags
}
