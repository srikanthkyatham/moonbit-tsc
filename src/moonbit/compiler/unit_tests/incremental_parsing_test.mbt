// Incremental Parsing Tests
// Tests for the incremental parsing functionality

// ============================================================================
// TextSpan Tests
// ============================================================================

///|
test "create TextSpan" {
  let span = @compiler.TextSpan::new(10, 5)
  assert_eq(span.start, 10)
  assert_eq(span.length, 5)
}

///|
test "TextSpan end calculation" {
  let span = @compiler.TextSpan::new(10, 5)
  assert_eq(span.end(), 15)
}

///|
test "TextSpan contains position inside" {
  let span = @compiler.TextSpan::new(10, 5)
  assert_eq(span.contains(12), true)
}

///|
test "TextSpan contains position at start" {
  let span = @compiler.TextSpan::new(10, 5)
  assert_eq(span.contains(10), true)
}

///|
test "TextSpan does not contain position at end" {
  let span = @compiler.TextSpan::new(10, 5)
  assert_eq(span.contains(15), false)
}

///|
test "TextSpan does not contain position before" {
  let span = @compiler.TextSpan::new(10, 5)
  assert_eq(span.contains(5), false)
}

///|
test "TextSpan does not contain position after" {
  let span = @compiler.TextSpan::new(10, 5)
  assert_eq(span.contains(20), false)
}

///|
test "TextSpan overlaps with overlapping span" {
  let span1 = @compiler.TextSpan::new(10, 10) // 10-20
  let span2 = @compiler.TextSpan::new(15, 10) // 15-25
  assert_eq(span1.overlaps(span2), true)
}

///|
test "TextSpan does not overlap with non-overlapping span" {
  let span1 = @compiler.TextSpan::new(10, 5) // 10-15
  let span2 = @compiler.TextSpan::new(20, 5) // 20-25
  assert_eq(span1.overlaps(span2), false)
}

///|
test "TextSpan overlaps with contained span" {
  let span1 = @compiler.TextSpan::new(10, 20) // 10-30
  let span2 = @compiler.TextSpan::new(15, 5)  // 15-20
  assert_eq(span1.overlaps(span2), true)
}

///|
test "TextSpan does not overlap when adjacent" {
  let span1 = @compiler.TextSpan::new(10, 5) // 10-15
  let span2 = @compiler.TextSpan::new(15, 5) // 15-20
  assert_eq(span1.overlaps(span2), false)
}

// ============================================================================
// TextChangeRange Tests
// ============================================================================

///|
test "create TextChangeRange" {
  let span = @compiler.TextSpan::new(10, 5)
  let change = @compiler.TextChangeRange::new(span, 8)
  assert_eq(change.span.start, 10)
  assert_eq(change.span.length, 5)
  assert_eq(change.new_length, 8)
}

///|
test "TextChangeRange delta positive" {
  let span = @compiler.TextSpan::new(10, 5)
  let change = @compiler.TextChangeRange::new(span, 10)
  assert_eq(change.delta(), 5) // 10 - 5 = 5
}

///|
test "TextChangeRange delta negative" {
  let span = @compiler.TextSpan::new(10, 10)
  let change = @compiler.TextChangeRange::new(span, 5)
  assert_eq(change.delta(), -5) // 5 - 10 = -5
}

///|
test "TextChangeRange delta zero" {
  let span = @compiler.TextSpan::new(10, 5)
  let change = @compiler.TextChangeRange::new(span, 5)
  assert_eq(change.delta(), 0) // 5 - 5 = 0
}

// ============================================================================
// Incremental Parse Tests - Full Reparse Cases
// ============================================================================

///|
test "incremental parse with no change range does full parse" {
  let source = "const x = 1;"
  let result = @compiler.parse_incremental(source, "test.ts", None, None)
  match result.source_file {
    @compiler.Node::SourceFile(sf) => {
      assert_eq(sf.statements.length(), 1)
    }
    _ => fail("Expected SourceFile")
  }
  // No change range means full reparse, affected_range should be None
  match result.affected_range {
    None => ()
    Some(_) => fail("Expected None for affected_range on full parse")
  }
}

///|
test "incremental parse with no old source file does full parse" {
  let source = "const x = 1;\nconst y = 2;"
  let span = @compiler.TextSpan::new(0, 5)
  let change = @compiler.TextChangeRange::new(span, 5)
  let result = @compiler.parse_incremental(source, "test.ts", Some(change), None)
  match result.source_file {
    @compiler.Node::SourceFile(sf) => {
      assert_eq(sf.statements.length(), 2)
    }
    _ => fail("Expected SourceFile")
  }
}

// ============================================================================
// Incremental Parse Tests - With Previous AST
// ============================================================================

///|
test "incremental parse with old source file" {
  // First parse
  let old_source = "const x = 1;"
  let old_result = @compiler.parse_incremental(old_source, "test.ts", None, None)

  let new_source = "const x = 2;"
  let span = @compiler.TextSpan::new(10, 1) // position of '1'
  let change = @compiler.TextChangeRange::new(span, 1) // replace '1' with '2'

  let result = @compiler.parse_incremental(new_source, "test.ts", Some(change), Some(old_result.source_file))
  match result.source_file {
    @compiler.Node::SourceFile(sf) => {
      assert_eq(sf.statements.length(), 1)
    }
    _ => fail("Expected SourceFile")
  }
}

///|
test "incremental parse adding new statement" {
  let old_source = "const x = 1;"
  let old_result = @compiler.parse_incremental(old_source, "test.ts", None, None)

  let new_source = "const x = 1;\nconst y = 2;"
  let span = @compiler.TextSpan::new(12, 0) // end of first statement
  let change = @compiler.TextChangeRange::new(span, 14) // add new statement

  let result = @compiler.parse_incremental(new_source, "test.ts", Some(change), Some(old_result.source_file))
  match result.source_file {
    @compiler.Node::SourceFile(sf) => {
      assert_eq(sf.statements.length(), 2)
    }
    _ => fail("Expected SourceFile")
  }
}

///|
test "incremental parse modifying function body" {
  let old_source = "function foo() { return 1; }"
  let old_result = @compiler.parse_incremental(old_source, "test.ts", None, None)

  let new_source = "function foo() { return 2; }"
  let span = @compiler.TextSpan::new(24, 1) // position of '1'
  let change = @compiler.TextChangeRange::new(span, 1) // replace '1' with '2'

  let result = @compiler.parse_incremental(new_source, "test.ts", Some(change), Some(old_result.source_file))
  match result.source_file {
    @compiler.Node::SourceFile(sf) => {
      assert_eq(sf.statements.length(), 1)
    }
    _ => fail("Expected SourceFile")
  }
}

// ============================================================================
// Incremental Parse Edge Cases
// ============================================================================

///|
test "incremental parse empty source" {
  let result = @compiler.parse_incremental("", "test.ts", None, None)
  match result.source_file {
    @compiler.Node::SourceFile(sf) => {
      assert_eq(sf.statements.length(), 0)
    }
    _ => fail("Expected SourceFile")
  }
}

///|
test "incremental parse single token change" {
  let old_source = "let x = 1;"
  let old_result = @compiler.parse_incremental(old_source, "test.ts", None, None)

  let new_source = "const x = 1;"
  let span = @compiler.TextSpan::new(0, 3) // "let"
  let change = @compiler.TextChangeRange::new(span, 5) // "const"

  let result = @compiler.parse_incremental(new_source, "test.ts", Some(change), Some(old_result.source_file))
  match result.source_file {
    @compiler.Node::SourceFile(sf) => {
      assert_eq(sf.statements.length(), 1)
    }
    _ => fail("Expected SourceFile")
  }
}

///|
test "incremental parse deleting statement" {
  let old_source = "const x = 1;\nconst y = 2;"
  let old_result = @compiler.parse_incremental(old_source, "test.ts", None, None)

  let new_source = "const x = 1;"
  let span = @compiler.TextSpan::new(12, 14) // second statement
  let change = @compiler.TextChangeRange::new(span, 0) // delete

  let result = @compiler.parse_incremental(new_source, "test.ts", Some(change), Some(old_result.source_file))
  match result.source_file {
    @compiler.Node::SourceFile(sf) => {
      assert_eq(sf.statements.length(), 1)
    }
    _ => fail("Expected SourceFile")
  }
}

// ============================================================================
// IncrementalParseResult Tests
// ============================================================================

///|
test "IncrementalParseResult structure" {
  let source = "const x = 1;"
  let result = @compiler.parse_incremental(source, "test.ts", None, None)

  // Verify we can access the source_file
  match result.source_file {
    @compiler.Node::SourceFile(_) => ()
    _ => fail("Expected SourceFile in result")
  }
}

///|
test "incremental parse complex file" {
  let source = "function add(a: number, b: number): number { return a + b; }\nconst result = add(1, 2);\nconsole.log(result);"
  let result = @compiler.parse_incremental(source, "test.ts", None, None)
  match result.source_file {
    @compiler.Node::SourceFile(sf) => {
      assert_eq(sf.statements.length() >= 3, true)
    }
    _ => fail("Expected SourceFile")
  }
}

///|
test "incremental parse with multiple changes in sequence" {
  // First parse
  let source1 = "const x = 1;"
  let result1 = @compiler.parse_incremental(source1, "test.ts", None, None)

  // Second parse with change
  let source2 = "const x = 2;"
  let span = @compiler.TextSpan::new(10, 1)
  let change = @compiler.TextChangeRange::new(span, 1)
  let result2 = @compiler.parse_incremental(source2, "test.ts", Some(change), Some(result1.source_file))

  match result2.source_file {
    @compiler.Node::SourceFile(sf) => {
      assert_eq(sf.statements.length(), 1)
    }
    _ => fail("Expected SourceFile")
  }
}

///|
test "incremental parse class modification" {
  let old_source = "class Foo { x: number = 1; }"
  let old_result = @compiler.parse_incremental(old_source, "test.ts", None, None)

  let new_source = "class Foo { x: number = 2; }"
  let span = @compiler.TextSpan::new(24, 1)
  let change = @compiler.TextChangeRange::new(span, 1)

  let result = @compiler.parse_incremental(new_source, "test.ts", Some(change), Some(old_result.source_file))
  match result.source_file {
    @compiler.Node::SourceFile(sf) => {
      assert_eq(sf.statements.length(), 1)
    }
    _ => fail("Expected SourceFile")
  }
}

///|
test "incremental parse interface modification" {
  let old_source = "interface Foo { x: number; }"
  let old_result = @compiler.parse_incremental(old_source, "test.ts", None, None)

  let new_source = "interface Foo { x: string; }"
  let span = @compiler.TextSpan::new(19, 6) // "number"
  let change = @compiler.TextChangeRange::new(span, 6) // "string"

  let result = @compiler.parse_incremental(new_source, "test.ts", Some(change), Some(old_result.source_file))
  match result.source_file {
    @compiler.Node::SourceFile(sf) => {
      assert_eq(sf.statements.length(), 1)
    }
    _ => fail("Expected SourceFile")
  }
}

///|
test "incremental parse type alias modification" {
  let old_source = "type MyType = number;"
  let old_result = @compiler.parse_incremental(old_source, "test.ts", None, None)

  let new_source = "type MyType = string;"
  let span = @compiler.TextSpan::new(14, 6) // "number"
  let change = @compiler.TextChangeRange::new(span, 6) // "string"

  let result = @compiler.parse_incremental(new_source, "test.ts", Some(change), Some(old_result.source_file))
  match result.source_file {
    @compiler.Node::SourceFile(sf) => {
      assert_eq(sf.statements.length(), 1)
    }
    _ => fail("Expected SourceFile")
  }
}
