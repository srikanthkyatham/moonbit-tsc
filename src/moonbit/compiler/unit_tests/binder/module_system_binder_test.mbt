// Module System Binder Tests
// Tests for module system binding including:
// - Import/export binding
// - Module format detection after binding
// - Type-only import tracking

///|
/// Helper function to parse and bind source code
fn parse_and_bind_module(
  source : String,
) -> Result[@compiler.BoundSourceFile, Array[@compiler.Diagnostic]] {
  let tokens = @compiler.scan_all_v2(source, "test.ts")
  match @compiler.parse_source_file(tokens, "test.ts") {
    Ok(source_file) => @compiler.bind_source_file(source_file)
    Err(_) => Err([])
  }
}

// ============================================================================
// Module Detection Tests
// ============================================================================

///|
test "binder/module_system - detects ES module with import" {
  let source = "import { foo } from './bar';"
  match parse_and_bind_module(source) {
    Ok(bound_file) => assert_eq(bound_file.module_info.is_external_module, true)
    Err(_) => fail("Parse/bind failed")
  }
}

///|
test "binder/module_system - detects ES module with export" {
  let source = "export const x = 1;"
  match parse_and_bind_module(source) {
    Ok(bound_file) => assert_eq(bound_file.module_info.is_external_module, true)
    Err(_) => fail("Parse/bind failed")
  }
}

///|
test "binder/module_system - detects script file (no imports/exports)" {
  let source = "const x = 1;"
  match parse_and_bind_module(source) {
    Ok(bound_file) =>
      // Files without import/export are scripts
      assert_eq(bound_file.module_info.is_external_module, false)
    Err(_) => fail("Parse/bind failed")
  }
}

///|
test "binder/module_system - detects export default" {
  let source = "export default function foo() {}"
  match parse_and_bind_module(source) {
    Ok(bound_file) => assert_eq(bound_file.module_info.is_external_module, true)
    Err(_) => fail("Parse/bind failed")
  }
}

// ============================================================================
// Import Binding Tests
// ============================================================================

///|
test "binder/module_system - binds default import" {
  let source = "import foo from './bar';"
  match parse_and_bind_module(source) {
    Ok(bound_file) => {
      // foo should be in scope
      let symbol = bound_file.global_scope.symbols.get("foo")
      assert_true(symbol is Some(_))
    }
    Err(_) => fail("Parse/bind failed")
  }
}

///|
test "binder/module_system - binds named import" {
  let source = "import { bar, baz } from './module';"
  match parse_and_bind_module(source) {
    Ok(bound_file) => {
      // bar and baz should be in scope
      assert_true(bound_file.global_scope.symbols.get("bar") is Some(_))
      assert_true(bound_file.global_scope.symbols.get("baz") is Some(_))
    }
    Err(_) => fail("Parse/bind failed")
  }
}

///|
test "binder/module_system - binds renamed import" {
  let source = "import { foo as myFoo } from './module';"
  match parse_and_bind_module(source) {
    Ok(bound_file) => {
      // myFoo should be in scope, not foo
      assert_true(bound_file.global_scope.symbols.get("myFoo") is Some(_))
      assert_true(bound_file.global_scope.symbols.get("foo") is None)
    }
    Err(_) => fail("Parse/bind failed")
  }
}

///|
test "binder/module_system - binds namespace import" {
  let source = "import * as mod from './module';"
  match parse_and_bind_module(source) {
    Ok(bound_file) =>
      // mod should be in scope
      assert_true(bound_file.global_scope.symbols.get("mod") is Some(_))
    Err(_) => fail("Parse/bind failed")
  }
}

// ============================================================================
// Export Binding Tests
// ============================================================================

///|
test "binder/module_system - binds exported variable" {
  let source = "export const myVar = 42;"
  match parse_and_bind_module(source) {
    Ok(bound_file) => {
      // Variable should be in scope
      let symbol = bound_file.global_scope.symbols.get("myVar")
      match symbol {
        Some(s) => assert_eq(s.name, "myVar")
        None => fail("Expected myVar to be in scope")
      }
      // Export should be tracked in module_info.exports
      assert_true(bound_file.module_info.exports.length() > 0)
    }
    Err(_) => fail("Parse/bind failed")
  }
}

///|
test "binder/module_system - binds exported function" {
  let source = "export function myFunc() {}"
  match parse_and_bind_module(source) {
    Ok(bound_file) => {
      // Function should be in scope
      let symbol = bound_file.global_scope.symbols.get("myFunc")
      match symbol {
        Some(s) => assert_eq(s.name, "myFunc")
        None => fail("Expected myFunc to be in scope")
      }
      // Export should be tracked in module_info.exports
      assert_true(bound_file.module_info.exports.length() > 0)
    }
    Err(_) => fail("Parse/bind failed")
  }
}

///|
test "binder/module_system - binds exported class" {
  let source = "export class MyClass {}"
  match parse_and_bind_module(source) {
    Ok(bound_file) => {
      // Class should be in scope
      let symbol = bound_file.global_scope.symbols.get("MyClass")
      match symbol {
        Some(s) => assert_eq(s.name, "MyClass")
        None => fail("Expected MyClass to be in scope")
      }
      // Export should be tracked in module_info.exports
      assert_true(bound_file.module_info.exports.length() > 0)
    }
    Err(_) => fail("Parse/bind failed")
  }
}

// ============================================================================
// Type-Only Import Tests
// ============================================================================

///|
test "binder/module_system - binds type-only import" {
  let source = "import type { MyType } from './types';"
  match parse_and_bind_module(source) {
    Ok(bound_file) => {
      assert_eq(bound_file.module_info.is_external_module, true)
      // Type-only imports should still create symbols
      assert_true(bound_file.global_scope.symbols.get("MyType") is Some(_))
    }
    Err(_) => fail("Parse/bind failed")
  }
}

///|
test "binder/module_system - binds inline type-only specifier" {
  let source = "import { type MyType, myValue } from './module';"
  match parse_and_bind_module(source) {
    Ok(bound_file) => {
      assert_true(bound_file.global_scope.symbols.get("MyType") is Some(_))
      assert_true(bound_file.global_scope.symbols.get("myValue") is Some(_))
    }
    Err(_) => fail("Parse/bind failed")
  }
}

// ============================================================================
// Re-export Tests
// ============================================================================

///|
test "binder/module_system - handles star re-export" {
  let source = "export * from './other';"
  match parse_and_bind_module(source) {
    Ok(bound_file) => assert_eq(bound_file.module_info.is_external_module, true)
    Err(_) => fail("Parse/bind failed")
  }
}

///|
test "binder/module_system - handles named re-export" {
  let source = "export { foo, bar } from './other';"
  match parse_and_bind_module(source) {
    Ok(bound_file) => assert_eq(bound_file.module_info.is_external_module, true)
    Err(_) => fail("Parse/bind failed")
  }
}

///|
test "binder/module_system - handles namespace re-export" {
  let source = "export * as ns from './other';"
  match parse_and_bind_module(source) {
    Ok(bound_file) => assert_eq(bound_file.module_info.is_external_module, true)
    Err(_) => fail("Parse/bind failed")
  }
}

// ============================================================================
// Combined Import/Export Tests
// ============================================================================

///|
test "binder/module_system - handles multiple imports and exports" {
  let source =
    #|import { a } from './a';
    #|import { b } from './b';
    #|export const c = a + b;
    #|export function d() { return c; }
  match parse_and_bind_module(source) {
    Ok(bound_file) => {
      assert_eq(bound_file.module_info.is_external_module, true)
      assert_true(bound_file.global_scope.symbols.get("a") is Some(_))
      assert_true(bound_file.global_scope.symbols.get("b") is Some(_))
      assert_true(bound_file.global_scope.symbols.get("c") is Some(_))
      assert_true(bound_file.global_scope.symbols.get("d") is Some(_))
    }
    Err(_) => fail("Parse/bind failed")
  }
}
