// JSON Parsing Tests
// Tests for the JSON parsing functionality in the TypeScript compiler

///|
/// Helper function to create tokens from source
fn tokens_from_source(source : String) -> Array[@compiler.Token] {
  let scanner = @compiler.Scanner::new(source, "test.json")
  @compiler.scan_all(scanner)
}

///|
/// Helper to parse JSON and extract the expression
fn parse_json(source : String) -> @compiler.Node? {
  let tokens = tokens_from_source(source)
  match @compiler.parse_source_file(tokens, "test.json") {
    Ok(sf) => {
      if sf.statements.length() > 0 {
        Some(sf.statements[0])
      } else {
        None
      }
    }
    Err(_) => None
  }
}

///|
/// Helper to parse JSON wrapped in assignment (for objects)
fn parse_json_value(source : String) -> @compiler.Node? {
  // Wrap in const x = ... to parse objects as expressions
  let wrapped = "const x = " + source
  let scanner = @compiler.Scanner::new(wrapped, "test.ts")
  let tokens = @compiler.scan_all(scanner)
  match @compiler.parse_source_file(tokens, "test.ts") {
    Ok(sf) => {
      if sf.statements.length() > 0 {
        match sf.statements[0] {
          @compiler.Node::VariableStatement(vs) => {
            if vs.declarations.length() > 0 {
              vs.declarations[0].initializer
            } else {
              None
            }
          }
          _ => None
        }
      } else {
        None
      }
    }
    Err(_) => None
  }
}

// ============================================================================
// JSON String Tests
// ============================================================================

///|
test "parse JSON string literal" {
  let result = parse_json("\"hello world\"")
  match result {
    Some(@compiler.Node::ExpressionStatement(es)) => {
      match es.expression {
        @compiler.Node::StringLiteral(_) => ()
        _ => fail("Expected StringLiteral")
      }
    }
    _ => fail("Expected ExpressionStatement")
  }
}

///|
test "parse JSON empty string" {
  let result = parse_json("\"\"")
  match result {
    Some(@compiler.Node::ExpressionStatement(es)) => {
      match es.expression {
        @compiler.Node::StringLiteral(sl) => {
          assert_eq(sl.value, "")
        }
        _ => fail("Expected StringLiteral")
      }
    }
    _ => fail("Expected ExpressionStatement")
  }
}

///|
test "parse JSON string with escapes" {
  let result = parse_json("\"hello\\nworld\"")
  match result {
    Some(@compiler.Node::ExpressionStatement(es)) => {
      match es.expression {
        @compiler.Node::StringLiteral(_) => ()
        _ => fail("Expected StringLiteral")
      }
    }
    _ => fail("Expected ExpressionStatement")
  }
}

// ============================================================================
// JSON Number Tests
// ============================================================================

///|
test "parse JSON integer" {
  let result = parse_json("42")
  match result {
    Some(@compiler.Node::ExpressionStatement(es)) => {
      match es.expression {
        @compiler.Node::NumericLiteral(nl) => {
          assert_eq(nl.value, "42")
        }
        _ => fail("Expected NumericLiteral")
      }
    }
    _ => fail("Expected ExpressionStatement")
  }
}

///|
test "parse JSON decimal" {
  let result = parse_json("3.14159")
  match result {
    Some(@compiler.Node::ExpressionStatement(es)) => {
      match es.expression {
        @compiler.Node::NumericLiteral(nl) => {
          assert_eq(nl.value, "3.14159")
        }
        _ => fail("Expected NumericLiteral")
      }
    }
    _ => fail("Expected ExpressionStatement")
  }
}

///|
test "parse JSON negative integer" {
  let result = parse_json("-42")
  match result {
    Some(@compiler.Node::ExpressionStatement(es)) => {
      match es.expression {
        @compiler.Node::UnaryExpression(_) => ()
        _ => fail("Expected UnaryExpression for negative number")
      }
    }
    _ => fail("Expected ExpressionStatement")
  }
}

///|
test "parse JSON zero" {
  let result = parse_json("0")
  match result {
    Some(@compiler.Node::ExpressionStatement(es)) => {
      match es.expression {
        @compiler.Node::NumericLiteral(nl) => {
          assert_eq(nl.value, "0")
        }
        _ => fail("Expected NumericLiteral")
      }
    }
    _ => fail("Expected ExpressionStatement")
  }
}

///|
test "parse JSON exponential" {
  let result = parse_json("1.5e10")
  match result {
    Some(@compiler.Node::ExpressionStatement(es)) => {
      match es.expression {
        @compiler.Node::NumericLiteral(_) => ()
        _ => fail("Expected NumericLiteral")
      }
    }
    _ => fail("Expected ExpressionStatement")
  }
}

// ============================================================================
// JSON Boolean Tests
// ============================================================================

///|
test "parse JSON true" {
  let result = parse_json("true")
  match result {
    Some(@compiler.Node::ExpressionStatement(es)) => {
      match es.expression {
        @compiler.Node::BooleanLiteral(bl) => {
          assert_eq(bl.value, true)
        }
        _ => fail("Expected BooleanLiteral")
      }
    }
    _ => fail("Expected ExpressionStatement")
  }
}

///|
test "parse JSON false" {
  let result = parse_json("false")
  match result {
    Some(@compiler.Node::ExpressionStatement(es)) => {
      match es.expression {
        @compiler.Node::BooleanLiteral(bl) => {
          assert_eq(bl.value, false)
        }
        _ => fail("Expected BooleanLiteral")
      }
    }
    _ => fail("Expected ExpressionStatement")
  }
}

// ============================================================================
// JSON Null Tests
// ============================================================================

///|
test "parse JSON null" {
  let result = parse_json("null")
  match result {
    Some(@compiler.Node::ExpressionStatement(es)) => {
      match es.expression {
        @compiler.Node::NullLiteral(_) => ()
        _ => fail("Expected NullLiteral")
      }
    }
    _ => fail("Expected ExpressionStatement")
  }
}

// ============================================================================
// JSON Array Tests
// ============================================================================

///|
test "parse JSON empty array" {
  let result = parse_json("[]")
  match result {
    Some(@compiler.Node::ExpressionStatement(es)) => {
      match es.expression {
        @compiler.Node::ArrayLiteralExpression(arr) => {
          assert_eq(arr.elements.length(), 0)
        }
        _ => fail("Expected ArrayLiteralExpression")
      }
    }
    _ => fail("Expected ExpressionStatement")
  }
}

///|
test "parse JSON array with single element" {
  let result = parse_json("[1]")
  match result {
    Some(@compiler.Node::ExpressionStatement(es)) => {
      match es.expression {
        @compiler.Node::ArrayLiteralExpression(arr) => {
          assert_eq(arr.elements.length(), 1)
        }
        _ => fail("Expected ArrayLiteralExpression")
      }
    }
    _ => fail("Expected ExpressionStatement")
  }
}

///|
test "parse JSON array with multiple elements" {
  let result = parse_json("[1, 2, 3]")
  match result {
    Some(@compiler.Node::ExpressionStatement(es)) => {
      match es.expression {
        @compiler.Node::ArrayLiteralExpression(arr) => {
          assert_eq(arr.elements.length(), 3)
        }
        _ => fail("Expected ArrayLiteralExpression")
      }
    }
    _ => fail("Expected ExpressionStatement")
  }
}

///|
test "parse JSON array with mixed types" {
  let result = parse_json("[1, \"hello\", true, null]")
  match result {
    Some(@compiler.Node::ExpressionStatement(es)) => {
      match es.expression {
        @compiler.Node::ArrayLiteralExpression(arr) => {
          assert_eq(arr.elements.length(), 4)
        }
        _ => fail("Expected ArrayLiteralExpression")
      }
    }
    _ => fail("Expected ExpressionStatement")
  }
}

///|
test "parse JSON nested arrays" {
  let result = parse_json("[[1, 2], [3, 4]]")
  match result {
    Some(@compiler.Node::ExpressionStatement(es)) => {
      match es.expression {
        @compiler.Node::ArrayLiteralExpression(arr) => {
          assert_eq(arr.elements.length(), 2)
        }
        _ => fail("Expected ArrayLiteralExpression")
      }
    }
    _ => fail("Expected ExpressionStatement")
  }
}

// ============================================================================
// JSON Object Tests (using wrapped parsing)
// ============================================================================

///|
test "parse JSON empty object" {
  let result = parse_json_value("{}")
  match result {
    Some(@compiler.Node::ObjectLiteralExpression(obj)) => {
      assert_eq(obj.properties.length(), 0)
    }
    _ => fail("Expected ObjectLiteralExpression")
  }
}

///|
test "parse JSON object with single property" {
  // Using JSON-style string keys
  let result = parse_json_value("{ \"name\": \"test\" }")
  match result {
    Some(@compiler.Node::ObjectLiteralExpression(obj)) => {
      assert_eq(obj.properties.length(), 1)
    }
    _ => fail("Expected ObjectLiteralExpression")
  }
}

///|
test "parse JSON object with identifier key" {
  // Using identifier-style keys (TypeScript syntax)
  let result = parse_json_value("{ name: \"test\" }")
  match result {
    Some(@compiler.Node::ObjectLiteralExpression(obj)) => {
      assert_eq(obj.properties.length(), 1)
    }
    _ => fail("Expected ObjectLiteralExpression")
  }
}

///|
test "parse JSON object with multiple properties" {
  let result = parse_json_value("{ \"name\": \"test\", \"value\": 42 }")
  match result {
    Some(@compiler.Node::ObjectLiteralExpression(obj)) => {
      assert_eq(obj.properties.length(), 2)
    }
    _ => fail("Expected ObjectLiteralExpression")
  }
}

///|
test "parse JSON nested objects" {
  let result = parse_json_value("{ \"outer\": { \"inner\": 1 } }")
  match result {
    Some(@compiler.Node::ObjectLiteralExpression(obj)) => {
      assert_eq(obj.properties.length(), 1)
    }
    _ => fail("Expected ObjectLiteralExpression")
  }
}

///|
test "parse JSON object with array value" {
  let result = parse_json_value("{ \"items\": [1, 2, 3] }")
  match result {
    Some(@compiler.Node::ObjectLiteralExpression(obj)) => {
      assert_eq(obj.properties.length(), 1)
    }
    _ => fail("Expected ObjectLiteralExpression")
  }
}

// ============================================================================
// Complex JSON Tests
// ============================================================================

///|
test "parse complex JSON structure" {
  let json = "{ \"users\": [{ \"name\": \"Alice\", \"age\": 30 }, { \"name\": \"Bob\", \"age\": 25 }], \"count\": 2 }"
  let result = parse_json_value(json)
  match result {
    Some(@compiler.Node::ObjectLiteralExpression(obj)) => {
      assert_eq(obj.properties.length(), 2)
    }
    _ => fail("Expected ObjectLiteralExpression")
  }
}

///|
test "parse JSON with deeply nested structure" {
  let json = "{ \"a\": { \"b\": { \"c\": { \"d\": 1 } } } }"
  let result = parse_json_value(json)
  match result {
    Some(@compiler.Node::ObjectLiteralExpression(_)) => ()
    _ => fail("Expected ObjectLiteralExpression")
  }
}

///|
test "parse JSON array of objects" {
  let json = "[{ \"id\": 1 }, { \"id\": 2 }, { \"id\": 3 }]"
  let result = parse_json_value(json)
  match result {
    Some(@compiler.Node::ArrayLiteralExpression(arr)) => {
      assert_eq(arr.elements.length(), 3)
    }
    _ => fail("Expected ArrayLiteralExpression")
  }
}

// ============================================================================
// Edge Cases
// ============================================================================

///|
test "parse JSON with whitespace" {
  let result = parse_json_value("  {  \"key\"  :  \"value\"  }  ")
  match result {
    Some(@compiler.Node::ObjectLiteralExpression(obj)) => {
      assert_eq(obj.properties.length(), 1)
    }
    _ => fail("Expected ObjectLiteralExpression")
  }
}

///|
test "parse object with numeric keys" {
  let result = parse_json_value("{ 0: \"first\", 1: \"second\" }")
  match result {
    Some(@compiler.Node::ObjectLiteralExpression(obj)) => {
      assert_eq(obj.properties.length(), 2)
    }
    _ => fail("Expected ObjectLiteralExpression")
  }
}

///|
test "parse JSON large number" {
  let result = parse_json("999999999999999")
  match result {
    Some(@compiler.Node::ExpressionStatement(es)) => {
      match es.expression {
        @compiler.Node::NumericLiteral(_) => ()
        _ => fail("Expected NumericLiteral")
      }
    }
    _ => fail("Expected ExpressionStatement")
  }
}

///|
test "parse JSON very small decimal" {
  let result = parse_json("0.00001")
  match result {
    Some(@compiler.Node::ExpressionStatement(es)) => {
      match es.expression {
        @compiler.Node::NumericLiteral(_) => ()
        _ => fail("Expected NumericLiteral")
      }
    }
    _ => fail("Expected ExpressionStatement")
  }
}
