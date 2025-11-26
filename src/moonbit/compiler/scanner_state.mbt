// Scanner State and Types
// Internal types used by the scanner

///|
/// JSX scanner mode
priv enum JsxModeV2 {
  Standard // Normal TypeScript/JavaScript
  JsxTag // Inside JSX tag (scanning attributes)
  JsxText // JSX text content (between tags)
  JsxExpression // Inside JSX expression {expr}
}

///|
/// Internal state for tracking position in the scanner
priv struct ScanState {
  mut line : Int
  mut col : Int
  mut offset : Int
}

///|
/// Template literal scanning result
priv enum TemplateScanResultV2 {
  Complete(StringView) // Full template literal or template tail
  Head(StringView) // Template head (has interpolation after)
  Middle(StringView) // Template middle (has interpolation after)
}
