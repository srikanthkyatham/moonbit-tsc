// CommonJS Tests
// Tests for CommonJS module parsing and type extraction

// ============================================================================
// Parser Tests - CommonJS Patterns
// ============================================================================

///|
/// Helper to parse source and return the AST
fn parse_commonjs(source : String) -> Result[SourceFile, Array[Diagnostic]] {
  let tokens = scan_all_v2(source, "test.js")
  parse_source_file(tokens, "test.js")
}

///|
/// Helper to parse and bind source
fn parse_bind_commonjs(source : String) -> Result[BoundSourceFile, Array[Diagnostic]] {
  match parse_commonjs(source) {
    Ok(source_file) => bind_source_file(source_file)
    Err(diagnostics) => Err(diagnostics)
  }
}

///|
/// Helper to extract module types from source
fn extract_types_commonjs(source : String) -> ModuleTypes {
  match parse_bind_commonjs(source) {
    Ok(bound) => extract_module_types(bound, "test.js")
    Err(_) => ModuleTypes::empty("test.js")
  }
}

// ============================================================================
// Parser: module.exports Pattern
// ============================================================================

///|
test "parse module.exports = number" {
  let result = parse_commonjs("module.exports = 42;")
  match result {
    Ok(source_file) => {
      assert_eq(source_file.statements.length(), 1)
      match source_file.statements[0] {
        ExpressionStatement(_) => ()
        _ => assert_true(false)
      }
    }
    Err(diagnostics) => {
      println("Parse failed with \{diagnostics.length()} errors")
      assert_true(false)
    }
  }
}

///|
test "parse module.exports = object literal" {
  let result = parse_commonjs("module.exports = { a: 1, b: 2 };")
  match result {
    Ok(source_file) => {
      assert_eq(source_file.statements.length(), 1)
      match source_file.statements[0] {
        ExpressionStatement(es) => {
          match es.expression {
            BinaryExpression(be) => {
              // Check operator is Assign using pattern match
              match be.operator {
                Assign => ()
                _ => assert_true(false)
              }
              match be.left {
                PropertyAccessExpression(pae) => {
                  assert_eq(pae.name, "exports")
                  match pae.expression {
                    Identifier(id) => assert_eq(id.name, "module")
                    _ => assert_true(false)
                  }
                }
                _ => assert_true(false)
              }
            }
            _ => assert_true(false)
          }
        }
        _ => assert_true(false)
      }
    }
    Err(_) => assert_true(false)
  }
}

///|
test "parse module.exports = function" {
  let result = parse_commonjs("module.exports = function(x) { return x; };")
  match result {
    Ok(source_file) => {
      assert_eq(source_file.statements.length(), 1)
      match source_file.statements[0] {
        ExpressionStatement(_) => ()
        _ => assert_true(false)
      }
    }
    Err(_) => assert_true(false)
  }
}

// ============================================================================
// Parser: exports.xxx Pattern
// ============================================================================

///|
test "parse exports.property = value" {
  let result = parse_commonjs("exports.foo = 42;")
  match result {
    Ok(source_file) => {
      assert_eq(source_file.statements.length(), 1)
      match source_file.statements[0] {
        ExpressionStatement(es) => {
          match es.expression {
            BinaryExpression(be) => {
              // Check operator is Assign using pattern match
              match be.operator {
                Assign => ()
                _ => assert_true(false)
              }
              match be.left {
                PropertyAccessExpression(pae) => {
                  assert_eq(pae.name, "foo")
                  match pae.expression {
                    Identifier(id) => assert_eq(id.name, "exports")
                    _ => assert_true(false)
                  }
                }
                _ => assert_true(false)
              }
            }
            _ => assert_true(false)
          }
        }
        _ => assert_true(false)
      }
    }
    Err(_) => assert_true(false)
  }
}

///|
test "parse exports.function = function expression" {
  let result = parse_commonjs("exports.greet = function(name) { return 'Hello ' + name; };")
  match result {
    Ok(source_file) => {
      assert_eq(source_file.statements.length(), 1)
      match source_file.statements[0] {
        ExpressionStatement(_) => ()
        _ => assert_true(false)
      }
    }
    Err(_) => assert_true(false)
  }
}

///|
test "parse multiple exports" {
  let source =
    #|exports.a = 1;
    #|exports.b = "hello";
    #|exports.c = true;
  let result = parse_commonjs(source)
  match result {
    Ok(source_file) => {
      assert_eq(source_file.statements.length(), 3)
    }
    Err(_) => assert_true(false)
  }
}

// ============================================================================
// Parser: var module Pattern (module as identifier)
// ============================================================================

///|
test "parse var module = require" {
  let result = parse_commonjs("var module = require('foo');")
  match result {
    Ok(source_file) => {
      assert_eq(source_file.statements.length(), 1)
      match source_file.statements[0] {
        VariableStatement(_) => ()
        _ => assert_true(false)
      }
    }
    Err(_) => assert_true(false)
  }
}

///|
test "parse module as variable name" {
  let result = parse_commonjs("var module = {};")
  match result {
    Ok(source_file) => {
      assert_eq(source_file.statements.length(), 1)
      match source_file.statements[0] {
        VariableStatement(_) => ()
        _ => assert_true(false)
      }
    }
    Err(_) => assert_true(false)
  }
}

// ============================================================================
// Parser: require() Pattern
// ============================================================================

///|
test "parse require call" {
  let result = parse_commonjs("var x = require('lodash');")
  match result {
    Ok(source_file) => {
      assert_eq(source_file.statements.length(), 1)
    }
    Err(_) => assert_true(false)
  }
}

///|
test "parse require with property access" {
  let result = parse_commonjs("var pick = require('lodash').pick;")
  match result {
    Ok(source_file) => {
      assert_eq(source_file.statements.length(), 1)
    }
    Err(_) => assert_true(false)
  }
}

// ============================================================================
// Type Extraction: exports.xxx Pattern
// ============================================================================

///|
test "extract type from exports.number" {
  let module_types = extract_types_commonjs("exports.count = 42;")
  match module_types.named_exports.get("count") {
    Some(info) => {
      match info.ty {
        TNumber => ()
        _ => {
          println("Expected TNumber, got \{info.ty}")
          assert_true(false)
        }
      }
    }
    None => {
      println("Export 'count' not found")
      assert_true(false)
    }
  }
}

///|
test "extract type from exports.string" {
  let module_types = extract_types_commonjs("exports.name = 'hello';")
  match module_types.named_exports.get("name") {
    Some(info) => {
      match info.ty {
        TString => ()
        _ => {
          println("Expected TString, got \{info.ty}")
          assert_true(false)
        }
      }
    }
    None => {
      println("Export 'name' not found")
      assert_true(false)
    }
  }
}

///|
test "extract type from exports.function" {
  let module_types = extract_types_commonjs("exports.greet = function(name) { return name; };")
  match module_types.named_exports.get("greet") {
    Some(info) => {
      match info.ty {
        TFunction(_) => ()
        _ => {
          println("Expected TFunction, got \{info.ty}")
          assert_true(false)
        }
      }
    }
    None => {
      println("Export 'greet' not found")
      assert_true(false)
    }
  }
}

///|
test "extract multiple exports" {
  let source =
    #|exports.a = 1;
    #|exports.b = "hello";
    #|exports.c = true;
  let module_types = extract_types_commonjs(source)

  // Check a is number
  match module_types.named_exports.get("a") {
    Some(info) => {
      match info.ty {
        TNumber => ()
        _ => assert_true(false)
      }
    }
    None => assert_true(false)
  }

  // Check b is string
  match module_types.named_exports.get("b") {
    Some(info) => {
      match info.ty {
        TString => ()
        _ => assert_true(false)
      }
    }
    None => assert_true(false)
  }

  // Check c is boolean
  match module_types.named_exports.get("c") {
    Some(info) => {
      match info.ty {
        TLiteralBool(true) => ()
        _ => assert_true(false)
      }
    }
    None => assert_true(false)
  }
}

// ============================================================================
// Type Extraction: module.exports Pattern
// ============================================================================

///|
test "extract type from module.exports object" {
  let module_types = extract_types_commonjs("module.exports = { x: 1, y: 'hello' };")

  // Check x is number
  match module_types.named_exports.get("x") {
    Some(info) => {
      match info.ty {
        TNumber => ()
        _ => {
          println("Expected TNumber for x, got \{info.ty}")
          assert_true(false)
        }
      }
    }
    None => {
      println("Export 'x' not found")
      assert_true(false)
    }
  }

  // Check y is string
  match module_types.named_exports.get("y") {
    Some(info) => {
      match info.ty {
        TString => ()
        _ => {
          println("Expected TString for y, got \{info.ty}")
          assert_true(false)
        }
      }
    }
    None => {
      println("Export 'y' not found")
      assert_true(false)
    }
  }
}

///|
test "extract type from module.exports function" {
  let module_types = extract_types_commonjs("module.exports = function(a, b) { return a + b; };")
  match module_types.named_exports.get("default") {
    Some(info) => {
      match info.ty {
        TFunction(ft) => {
          assert_eq(ft.params.length(), 2)
        }
        _ => {
          println("Expected TFunction, got \{info.ty}")
          assert_true(false)
        }
      }
    }
    None => {
      println("Export 'default' not found")
      assert_true(false)
    }
  }
}

// ============================================================================
// Type Extraction: Function with Parameters
// ============================================================================

///|
test "extract function parameter names" {
  let module_types = extract_types_commonjs("exports.add = function(x, y) { return x + y; };")
  match module_types.named_exports.get("add") {
    Some(info) => {
      match info.ty {
        TFunction(ft) => {
          assert_eq(ft.params.length(), 2)
          assert_eq(ft.params[0].name, "x")
          assert_eq(ft.params[1].name, "y")
        }
        _ => assert_true(false)
      }
    }
    None => assert_true(false)
  }
}

///|
test "extract arrow function type" {
  let module_types = extract_types_commonjs("exports.double = (n) => n * 2;")
  match module_types.named_exports.get("double") {
    Some(info) => {
      match info.ty {
        TFunction(ft) => {
          assert_eq(ft.params.length(), 1)
          assert_eq(ft.params[0].name, "n")
        }
        _ => {
          println("Expected TFunction, got \{info.ty}")
          assert_true(false)
        }
      }
    }
    None => {
      println("Export 'double' not found")
      assert_true(false)
    }
  }
}

// ============================================================================
// Checker: CommonJS Globals
// ============================================================================

///|
test "check exports global is recognized" {
  let source = "exports.foo = 42;"
  let tokens = scan_all_v2(source, "test.js")
  match parse_source_file(tokens, "test.js") {
    Ok(source_file) => {
      match bind_source_file(source_file) {
        Ok(bound) => {
          match check_source_file(bound) {
            Ok(_) => ()
            Err(diagnostics) => {
              // Should not have "Cannot find name 'exports'" error
              for diag in diagnostics {
                if diag.message.contains("Cannot find name 'exports'") {
                  println("Unexpected error: exports not recognized as global")
                  assert_true(false)
                }
              }
            }
          }
        }
        Err(_) => assert_true(false)
      }
    }
    Err(_) => assert_true(false)
  }
}

///|
test "check module global is recognized" {
  let source = "module.exports = {};"
  let tokens = scan_all_v2(source, "test.js")
  match parse_source_file(tokens, "test.js") {
    Ok(source_file) => {
      match bind_source_file(source_file) {
        Ok(bound) => {
          match check_source_file(bound) {
            Ok(_) => ()
            Err(diagnostics) => {
              // Should not have "Cannot find name 'module'" error
              for diag in diagnostics {
                if diag.message.contains("Cannot find name 'module'") {
                  println("Unexpected error: module not recognized as global")
                  assert_true(false)
                }
              }
            }
          }
        }
        Err(_) => assert_true(false)
      }
    }
    Err(_) => assert_true(false)
  }
}

///|
test "check require global is recognized" {
  let source = "var x = require('foo');"
  let tokens = scan_all_v2(source, "test.js")
  match parse_source_file(tokens, "test.js") {
    Ok(source_file) => {
      match bind_source_file(source_file) {
        Ok(bound) => {
          match check_source_file(bound) {
            Ok(_) => ()
            Err(diagnostics) => {
              // Should not have "Cannot find name 'require'" error
              for diag in diagnostics {
                if diag.message.contains("Cannot find name 'require'") {
                  println("Unexpected error: require not recognized as global")
                  assert_true(false)
                }
              }
            }
          }
        }
        Err(_) => assert_true(false)
      }
    }
    Err(_) => assert_true(false)
  }
}

// ============================================================================
// Type Extraction: Object Literal Properties
// ============================================================================

///|
test "extract nested object types" {
  let module_types = extract_types_commonjs("module.exports = { person: { name: 'John', age: 30 } };")
  match module_types.named_exports.get("person") {
    Some(info) => {
      match info.ty {
        TObject(_) => ()
        _ => {
          println("Expected TObject for person, got \{info.ty}")
          assert_true(false)
        }
      }
    }
    None => {
      println("Export 'person' not found")
      assert_true(false)
    }
  }
}

///|
test "extract array type" {
  let module_types = extract_types_commonjs("exports.items = [1, 2, 3];")
  match module_types.named_exports.get("items") {
    Some(info) => {
      match info.ty {
        TArray(_) => ()
        _ => {
          println("Expected TArray, got \{info.ty}")
          assert_true(false)
        }
      }
    }
    None => {
      println("Export 'items' not found")
      assert_true(false)
    }
  }
}

// ============================================================================
// Complex CommonJS Patterns
// ============================================================================

///|
test "parse mixed commonjs file" {
  let source =
    #|var helper = require('./helper');
    #|
    #|exports.VERSION = '1.0.0';
    #|
    #|exports.greet = function(name) {
    #|  return 'Hello, ' + name;
    #|};
    #|
    #|module.exports.config = { debug: true };
  let result = parse_commonjs(source)
  match result {
    Ok(source_file) => {
      assert_true(source_file.statements.length() >= 3)
    }
    Err(diagnostics) => {
      println("Parse failed with \{diagnostics.length()} errors:")
      for diag in diagnostics {
        println("  \{diag.message}")
      }
      assert_true(false)
    }
  }
}

///|
test "extract types from mixed commonjs file" {
  let source =
    #|exports.VERSION = '1.0.0';
    #|exports.count = 42;
    #|module.exports.enabled = true;
  let module_types = extract_types_commonjs(source)

  // Check VERSION
  match module_types.named_exports.get("VERSION") {
    Some(info) => {
      match info.ty {
        TString => ()
        _ => assert_true(false)
      }
    }
    None => assert_true(false)
  }

  // Check count
  match module_types.named_exports.get("count") {
    Some(info) => {
      match info.ty {
        TNumber => ()
        _ => assert_true(false)
      }
    }
    None => assert_true(false)
  }
}
