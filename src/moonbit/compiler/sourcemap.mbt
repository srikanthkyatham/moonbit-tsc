// Source Map Generator for TypeScript to JavaScript compilation
// Implements Source Map v3 specification: https://sourcemaps.info/spec.html

///|
/// Position in source code (line and column) for sourcemap generation
struct SourceMapPosition {
  line : Int // 0-based line number
  column : Int // 0-based column number
}

///|
/// Creates a new SourceMapPosition
fn SourceMapPosition::new(line : Int, column : Int) -> SourceMapPosition {
  { line, column }
}

///|
/// Single mapping from generated position to original position
pub struct SourceMapping {
  generated_line : Int // 0-based generated line
  generated_column : Int // 0-based generated column
  original_line : Int // 0-based original line
  original_column : Int // 0-based original column
  source_index : Int // Index into sources array
  name_index : Int? // Optional index into names array
}

///|
/// Creates a new SourceMapping
pub fn SourceMapping::new(
  generated_line : Int,
  generated_column : Int,
  original_line : Int,
  original_column : Int,
  source_index : Int,
  name_index : Int?,
) -> SourceMapping {
  {
    generated_line,
    generated_column,
    original_line,
    original_column,
    source_index,
    name_index,
  }
}

///|
/// Source Map (v3 format)
pub struct SourceMap {
  version : Int // Always 3
  file : String? // Generated file name
  source_root : String? // Optional source root
  sources : Array[String] // Original source file names
  sources_content : Array[String]? // Optional original source content
  names : Array[String] // Symbol/identifier names
  mappings : String // Base64 VLQ encoded mappings
}

///|
/// Creates an empty source map
pub fn SourceMap::new() -> SourceMap {
  {
    version: 3,
    file: None,
    source_root: None,
    sources: [],
    sources_content: None,
    names: [],
    mappings: "",
  }
}

///|
/// Converts source map to JSON string
pub fn SourceMap::to_json(self : SourceMap) -> String {
  let mut json = "{\n"
  json = json + "  \"version\": " + self.version.to_string() + ",\n"

  // Add file if present
  match self.file {
    Some(f) => json = json + "  \"file\": \"" + f + "\",\n"
    None => ()
  }

  // Add sourceRoot if present
  match self.source_root {
    Some(root) => json = json + "  \"sourceRoot\": \"" + root + "\",\n"
    None => ()
  }

  // Add sources array
  json = json + "  \"sources\": ["
  for i = 0; i < self.sources.length(); i = i + 1 {
    if i > 0 {
      json = json + ", "
    }
    json = json + "\"" + self.sources[i] + "\""
  }
  json = json + "],\n"

  // Add sourcesContent if present
  match self.sources_content {
    Some(content) => {
      json = json + "  \"sourcesContent\": ["
      for i = 0; i < content.length(); i = i + 1 {
        if i > 0 {
          json = json + ", "
        }
        // Escape quotes and newlines in source content
        let escaped = escape_json_string(content[i])
        json = json + "\"" + escaped + "\""
      }
      json = json + "],\n"
    }
    None => ()
  }

  // Add names array
  json = json + "  \"names\": ["
  for i = 0; i < self.names.length(); i = i + 1 {
    if i > 0 {
      json = json + ", "
    }
    json = json + "\"" + self.names[i] + "\""
  }
  json = json + "],\n"

  // Add mappings
  json = json + "  \"mappings\": \"" + self.mappings + "\"\n"
  json = json + "}"
  json
}

///|
/// Escapes special characters in JSON strings
pub fn escape_json_string(s : String) -> String {
  let mut result = ""
  let len = s.length()
  for i = 0; i < len; i = i + 1 {
    match s.get(i) {
      Some(ch_code) =>
        match ch_code.to_char() {
          Some(ch) =>
            if ch == '"' {
              result = result + "\\\""
            } else if ch == '\\' {
              result = result + "\\\\"
            } else if ch == '\n' {
              result = result + "\\n"
            } else if ch == '\r' {
              result = result + "\\r"
            } else if ch == '\t' {
              result = result + "\\t"
            } else {
              result = result + Char::to_string(ch)
            }
          None => ()
        }
      None => ()
    }
  }
  result
}

// Base64 VLQ Encoding Implementation
// VLQ (Variable-Length Quantity) is used to encode integers in a compact format

///|
/// Gets base64 character for given index
pub fn get_base64_char(index : Int) -> Char {
  let base64_chars = "ABCDEFGHIJKLMNOPQRSTUVWXYZabcdefghijklmnopqrstuvwxyz0123456789+/"
  match base64_chars.get(index) {
    Some(ch_code) =>
      match ch_code.to_char() {
        Some(ch) => ch
        None => 'A' // Default fallback
      }
    None => 'A' // Default fallback
  }
}

///|
/// Encodes an integer using Base64 VLQ encoding
pub fn encode_vlq(value : Int) -> String {
  let mut vlq = if value < 0 { -value * 2 + 1 } else { value * 2 }
  let mut encoded = ""
  while true {
    let mut digit = vlq % 32 // VLQ uses 5 bits per digit
    vlq = vlq / 32
    if vlq > 0 {
      digit = digit | 32 // Set continuation bit
    }
    encoded = encoded + Char::to_string(get_base64_char(digit))
    if vlq == 0 {
      break
    }
  } else {
    ()
  }
  encoded
}

///|
/// Source Map Builder - accumulates mappings during code generation
pub struct SourceMapBuilder {
  sources : Array[String] // Source file names
  sources_map : Map[String, Int] // Map source name to index
  names : Array[String] // Symbol names
  names_map : Map[String, Int] // Map name to index
  mappings : Array[SourceMapping] // All mappings
  mut generated_line : Int // Current generated line (0-based)
  mut generated_column : Int // Current generated column (0-based)
}

///|
/// Creates a new SourceMapBuilder
pub fn SourceMapBuilder::new() -> SourceMapBuilder {
  {
    sources: [],
    sources_map: Map::new(),
    names: [],
    names_map: Map::new(),
    mappings: [],
    generated_line: 0,
    generated_column: 0,
  }
}

///|
/// Adds a source file and returns its index
pub fn SourceMapBuilder::add_source(
  self : SourceMapBuilder,
  source : String,
) -> Int {
  match self.sources_map.get(source) {
    Some(index) => index
    None => {
      let index = self.sources.length()
      self.sources.push(source)
      self.sources_map.set(source, index)
      index
    }
  }
}

///|
/// Adds a name and returns its index
pub fn SourceMapBuilder::add_name(
  self : SourceMapBuilder,
  name : String,
) -> Int {
  match self.names_map.get(name) {
    Some(index) => index
    None => {
      let index = self.names.length()
      self.names.push(name)
      self.names_map.set(name, index)
      index
    }
  }
}

///|
/// Adds a mapping from generated position to original position
pub fn SourceMapBuilder::add_mapping(
  self : SourceMapBuilder,
  generated_line : Int,
  generated_column : Int,
  source : String,
  original_line : Int,
  original_column : Int,
  name : String?,
) -> Unit {
  let source_index = self.add_source(source)
  let name_index = match name {
    Some(n) => Some(self.add_name(n))
    None => None
  }
  let mapping = {
    generated_line,
    generated_column,
    original_line,
    original_column,
    source_index,
    name_index,
  }
  self.mappings.push(mapping)
}

///|
/// Updates current generated position (called after emitting code)
pub fn SourceMapBuilder::update_position(
  self : SourceMapBuilder,
  line : Int,
  column : Int,
) -> Unit {
  self.generated_line = line
  self.generated_column = column
}

///|
/// Advances generated line (called after emitting newline)
pub fn SourceMapBuilder::new_line(self : SourceMapBuilder) -> Unit {
  self.generated_line = self.generated_line + 1
  self.generated_column = 0
}

///|
/// Advances generated column by specified amount
pub fn SourceMapBuilder::advance_column(
  self : SourceMapBuilder,
  amount : Int,
) -> Unit {
  self.generated_column = self.generated_column + amount
}

///|
/// Builds the final source map with encoded mappings
pub fn SourceMapBuilder::build(
  self : SourceMapBuilder,
  file : String?,
) -> SourceMap {
  self.build_with_sources(file, None)
}

///|
/// Builds the final source map with encoded mappings and optional sources content
pub fn SourceMapBuilder::build_with_sources(
  self : SourceMapBuilder,
  file : String?,
  sources_content : Array[String]?,
) -> SourceMap {
  // Sort mappings by generated position
  let sorted = sort_mappings(self.mappings)

  // Encode mappings using Base64 VLQ
  let mappings_str = encode_mappings(sorted)
  {
    version: 3,
    file,
    source_root: None,
    sources: self.sources,
    sources_content,
    names: self.names,
    mappings: mappings_str,
  }
}

///|
/// Sorts mappings by generated line and column
pub fn sort_mappings(mappings : Array[SourceMapping]) -> Array[SourceMapping] {
  // Simple bubble sort (for now - can optimize later)
  let sorted = Array::new()
  for i = 0; i < mappings.length(); i = i + 1 {
    sorted.push(mappings[i])
  }
  let len = sorted.length()
  for i = 0; i < len - 1; i = i + 1 {
    for j = 0; j < len - i - 1; j = j + 1 {
      let a = sorted[j]
      let b = sorted[j + 1]

      // Compare by line first, then by column
      if a.generated_line > b.generated_line ||
        (
          a.generated_line == b.generated_line &&
          a.generated_column > b.generated_column
        ) {
        // Swap
        sorted[j] = b
        sorted[j + 1] = a
      }
    }
  }
  sorted
}

///|
/// Encodes mappings array into Base64 VLQ format
pub fn encode_mappings(mappings : Array[SourceMapping]) -> String {
  if mappings.length() == 0 {
    return ""
  }
  let mut result = ""
  let mut prev_line = 0
  let mut prev_generated_column = 0
  let mut prev_source_index = 0
  let mut prev_original_line = 0
  let mut prev_original_column = 0
  let mut prev_name_index = 0
  for i = 0; i < mappings.length(); i = i + 1 {
    let mapping = mappings[i]

    // Add semicolons for line breaks
    while prev_line < mapping.generated_line {
      result = result + ";"
      prev_line = prev_line + 1
      prev_generated_column = 0 // Reset column at new line
    }

    // Add comma separator between mappings on same line (except first)
    if i > 0 && mapping.generated_line == mappings[i - 1].generated_line {
      result = result + ","
    }

    // Encode 5 values: generated_column, source_index, original_line, original_column, name_index
    // All values except generated_column are relative (deltas)

    // 1. Generated column (delta from previous)
    result = result +
      encode_vlq(mapping.generated_column - prev_generated_column)
    prev_generated_column = mapping.generated_column

    // 2. Source file index (delta)
    result = result + encode_vlq(mapping.source_index - prev_source_index)
    prev_source_index = mapping.source_index

    // 3. Original line (delta)
    result = result + encode_vlq(mapping.original_line - prev_original_line)
    prev_original_line = mapping.original_line

    // 4. Original column (delta)
    result = result + encode_vlq(mapping.original_column - prev_original_column)
    prev_original_column = mapping.original_column

    // 5. Name index (delta) - optional
    match mapping.name_index {
      Some(name_idx) => {
        result = result + encode_vlq(name_idx - prev_name_index)
        prev_name_index = name_idx
      }
      None => ()
    }
  }
  result
}

///|
/// Generates inline source map comment for JavaScript file
pub fn generate_inline_sourcemap_comment(sourcemap : SourceMap) -> String {
  let json = sourcemap.to_json()
  // Base64 encode the JSON (simplified - real implementation needs proper base64)
  "//# sourceMappingURL=data:application/json;charset=utf-8;base64," +
  base64_encode_simple(json)
}

///|
/// Generates external source map reference comment
pub fn generate_sourcemap_reference(map_file : String) -> String {
  "//# sourceMappingURL=" + map_file
}

///|
/// Base64 encoding table
let base64_table = "ABCDEFGHIJKLMNOPQRSTUVWXYZabcdefghijklmnopqrstuvwxyz0123456789+/"

///|
/// Proper base64 encoding implementation
pub fn base64_encode_simple(s : String) -> String {
  let mut result = ""
  let len = s.length()
  let mut i = 0

  // Process 3 bytes at a time
  while i + 2 < len {
    match (s.get(i), s.get(i + 1), s.get(i + 2)) {
      (Some(b1), Some(b2), Some(b3)) => {
        // Convert 3 bytes (24 bits) to 4 base64 characters (6 bits each)
        let val = b1 * 65536 + b2 * 256 + b3
        let c1 = get_base64_char(val / 262144 % 64) // val >> 18
        let c2 = get_base64_char(val / 4096 % 64) // val >> 12
        let c3 = get_base64_char(val / 64 % 64) // val >> 6
        let c4 = get_base64_char(val % 64)
        result = result +
          Char::to_string(c1) +
          Char::to_string(c2) +
          Char::to_string(c3) +
          Char::to_string(c4)
      }
      _ => ()
    }
    i = i + 3
  }

  // Handle remaining 1 or 2 bytes with padding
  if i < len {
    match s.get(i) {
      Some(b1) =>
        if i + 1 < len {
          // 2 bytes remaining
          match s.get(i + 1) {
            Some(b2) => {
              let val = b1 * 256 + b2
              let c1 = get_base64_char(val / 1024 % 64) // val >> 10
              let c2 = get_base64_char(val / 16 % 64) // val >> 4
              let c3 = get_base64_char(val * 4 % 64) // (val & 0x0F) << 2
              result = result +
                Char::to_string(c1) +
                Char::to_string(c2) +
                Char::to_string(c3) +
                "="
            }
            None => ()
          }
        } else {
          // 1 byte remaining
          let val = b1
          let c1 = get_base64_char(val / 4 % 64) // val >> 2
          let c2 = get_base64_char(val * 16 % 64) // (val & 0x03) << 4
          result = result + Char::to_string(c1) + Char::to_string(c2) + "=="
        }
      None => ()
    }
  }
  result
}

///|
/// Source map output mode
pub enum SourceMapMode {
  NoMap // No source map
  InlineMap // Inline base64-encoded source map in JS file
  ExternalMap // Separate .map file with reference comment
} derive(Eq)

///|
/// Create a SourceMapMode with no source map
pub fn SourceMapMode::no_map() -> SourceMapMode {
  NoMap
}

///|
/// Create a SourceMapMode with inline source map
pub fn SourceMapMode::inline_map() -> SourceMapMode {
  InlineMap
}

///|
/// Create a SourceMapMode with external source map
pub fn SourceMapMode::external_map() -> SourceMapMode {
  ExternalMap
}

///|
/// Source map output configuration
pub struct SourceMapOutput {
  mode : SourceMapMode
  js_code : String
  source_map : SourceMap?
  map_file_name : String? // For external mode
}

///|
/// Generate complete output with source map based on mode
pub fn generate_output_with_sourcemap(
  js_code : String,
  sourcemap : SourceMap,
  mode : SourceMapMode,
  output_file : String,
) -> SourceMapOutput {
  match mode {
    NoMap =>
      // No source map
      { mode, js_code, source_map: None, map_file_name: None }
    InlineMap => {
      // Inline source map
      let comment = generate_inline_sourcemap_comment(sourcemap)
      let final_js = js_code + "\n" + comment
      {
        mode,
        js_code: final_js,
        source_map: Some(sourcemap),
        map_file_name: None,
      }
    }
    ExternalMap => {
      // External source map
      let map_file = output_file + ".map"
      let comment = generate_sourcemap_reference(map_file)
      let final_js = js_code + "\n" + comment
      {
        mode,
        js_code: final_js,
        source_map: Some(sourcemap),
        map_file_name: Some(map_file),
      }
    }
  }
}
