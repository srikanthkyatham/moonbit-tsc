// Diff Reporter for E2E Tests
// Simple line-by-line diff for debugging test failures

///|
/// Diff line type
pub(all) enum DiffLineType {
  Same
  Added
  Removed
} derive(Show, Eq)

///|
/// A single diff line
pub(all) struct DiffLine {
  line_type : DiffLineType
  line_number : Int
  content : String
} derive(Show)

///|
/// Generate a simple line-by-line diff
pub fn diff_lines(expected : String, actual : String) -> Array[DiffLine] {
  let exp_lines : Array[String] = expected
    .split("\n")
    .map(fn(s) { s.to_string() })
    .collect()
  let act_lines : Array[String] = actual
    .split("\n")
    .map(fn(s) { s.to_string() })
    .collect()
  let result : Array[DiffLine] = []
  let max_lines = if exp_lines.length() > act_lines.length() {
    exp_lines.length()
  } else {
    act_lines.length()
  }
  for i = 0; i < max_lines; i = i + 1 {
    let exp_line = if i < exp_lines.length() {
      Some(exp_lines[i])
    } else {
      None
    }
    let act_line = if i < act_lines.length() {
      Some(act_lines[i])
    } else {
      None
    }
    match (exp_line, act_line) {
      (Some(e), Some(a)) =>
        if e == a {
          result.push({ line_type: Same, line_number: i + 1, content: e })
        } else {
          result.push({ line_type: Removed, line_number: i + 1, content: e })
          result.push({ line_type: Added, line_number: i + 1, content: a })
        }
      (Some(e), None) =>
        result.push({ line_type: Removed, line_number: i + 1, content: e })
      (None, Some(a)) =>
        result.push({ line_type: Added, line_number: i + 1, content: a })
      (None, None) => ()
    }
  }
  result
}

///|
/// Format a baseline diff for display
pub fn format_baseline_diff(diff : BaselineDiff) -> String {
  let sb = StringBuilder::new()
  sb.write_string("=== ")
  sb.write_string(diff.baseline_type)
  sb.write_string(" baseline mismatch ===\n")
  let lines = diff_lines(diff.expected, diff.actual)

  // Only show lines with differences (and some context)
  let mut last_shown = -10
  for i = 0; i < lines.length(); i = i + 1 {
    let line = lines[i]
    match line.line_type {
      Same =>
        // Show context lines near differences
        if i > 0 && i < lines.length() - 1 {
          let prev_is_diff = lines[i - 1].line_type != Same
          let next_is_diff = lines[i + 1].line_type != Same
          if prev_is_diff || next_is_diff {
            if i - last_shown > 1 {
              sb.write_string("...\n")
            }
            sb.write_string("  ")
            sb.write_string(line.line_number.to_string())
            sb.write_string(": ")
            sb.write_string(line.content)
            sb.write_char('\n')
            last_shown = i
          }
        }
      Removed => {
        if i - last_shown > 1 && last_shown >= 0 {
          sb.write_string("...\n")
        }
        sb.write_string("- ")
        sb.write_string(line.line_number.to_string())
        sb.write_string(": ")
        sb.write_string(line.content)
        sb.write_char('\n')
        last_shown = i
      }
      Added => {
        if i - last_shown > 1 && last_shown >= 0 {
          sb.write_string("...\n")
        }
        sb.write_string("+ ")
        sb.write_string(line.line_number.to_string())
        sb.write_string(": ")
        sb.write_string(line.content)
        sb.write_char('\n')
        last_shown = i
      }
    }
  }
  sb.to_string()
}

///|
/// Format test result for display
pub fn format_test_result(result : TestResult) -> String {
  let sb = StringBuilder::new()
  if result.passed {
    sb.write_string("[PASS] ")
  } else {
    sb.write_string("[FAIL] ")
  }
  sb.write_string(result.name)
  match result.variant {
    Some(v) => {
      let params = v.to_param_string()
      if params.length() > 0 {
        sb.write_string(" ")
        sb.write_string(params)
      }
    }
    None => ()
  }
  sb.write_char('\n')

  // Show error message if any
  match result.error_message {
    Some(msg) => {
      sb.write_string("  Error: ")
      sb.write_string(msg)
      sb.write_char('\n')
    }
    None => ()
  }

  // Show diffs if any
  for diff in result.diffs {
    sb.write_string(format_baseline_diff(diff))
  }
  sb.to_string()
}

///|
/// Format test summary for display
pub fn format_test_summary(summary : TestSummary) -> String {
  let sb = StringBuilder::new()
  sb.write_string("\n")
  sb.write_string("========================================\n")
  sb.write_string("                TEST RESULTS            \n")
  sb.write_string("========================================\n")
  sb.write_string("Total:   ")
  sb.write_string(summary.total.to_string())
  sb.write_char('\n')
  sb.write_string("Passed:  ")
  sb.write_string(summary.passed.to_string())
  sb.write_char('\n')
  sb.write_string("Failed:  ")
  sb.write_string(summary.failed.to_string())
  sb.write_char('\n')
  sb.write_string("Skipped: ")
  sb.write_string(summary.skipped.to_string())
  sb.write_char('\n')
  sb.write_string("========================================\n")
  if summary.failed > 0 {
    sb.write_string("\nFailed Tests:\n")
    for result in summary.results {
      if not(result.passed) {
        sb.write_string("  - ")
        sb.write_string(result.name)
        match result.variant {
          Some(v) => {
            let params = v.to_param_string()
            if params.length() > 0 {
              sb.write_string(" ")
              sb.write_string(params)
            }
          }
          None => ()
        }
        sb.write_char('\n')
      }
    }
  }
  sb.to_string()
}

// Tests

///|
test "diff identical lines" {
  let lines = diff_lines("a\nb\nc", "a\nb\nc")
  assert_eq(lines.length(), 3)
  assert_eq(lines[0].line_type, Same)
  assert_eq(lines[1].line_type, Same)
  assert_eq(lines[2].line_type, Same)
}

///|
test "diff with changes" {
  let lines = diff_lines("a\nb\nc", "a\nB\nc")
  // a is same, b/B differ, c is same
  let mut found_removed = false
  let mut found_added = false
  for line in lines {
    if line.line_type == Removed && line.content == "b" {
      found_removed = true
    }
    if line.line_type == Added && line.content == "B" {
      found_added = true
    }
  }
  assert_true(found_removed)
  assert_true(found_added)
}

///|
test "format test result passed" {
  let result = TestResult::passed("mytest")
  let formatted = format_test_result(result)
  assert_true(formatted.contains("[PASS]"))
  assert_true(formatted.contains("mytest"))
}

///|
test "format test result failed" {
  let result = TestResult::failed("mytest", None, [
    { baseline_type: "js", expected: "a", actual: "b" },
  ])
  let formatted = format_test_result(result)
  assert_true(formatted.contains("[FAIL]"))
  assert_true(formatted.contains("mytest"))
}
