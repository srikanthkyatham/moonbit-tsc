// Binder Tests
// Tests for the binder functionality including:
// - Symbol binding
// - Module detection
// - Declaration merging
// - Control flow graph nodes

///|
/// Helper function to parse and bind source code
fn parse_and_bind(source : String) -> Result[@compiler.BoundSourceFile, Array[@compiler.Diagnostic]] {
  let scanner = @compiler.Scanner::new(source, "test.ts")
  let tokens = @compiler.scan_all(scanner)
  match @compiler.parse_source_file(tokens, "test.ts") {
    Ok(source_file) => @compiler.bind_source_file(source_file)
    Err(_) => Err([])
  }
}

///|
/// Check if symbol kind is Variable
fn is_variable_kind(kind : @compiler.SymbolKind) -> Bool {
  match kind {
    Variable => true
    _ => false
  }
}

///|
/// Check if symbol kind is Function
fn is_function_kind(kind : @compiler.SymbolKind) -> Bool {
  match kind {
    Function => true
    _ => false
  }
}

///|
/// Check if symbol kind is Class
fn is_class_kind(kind : @compiler.SymbolKind) -> Bool {
  match kind {
    Class => true
    _ => false
  }
}

///|
/// Check if symbol kind is Interface
fn is_interface_kind(kind : @compiler.SymbolKind) -> Bool {
  match kind {
    Interface => true
    _ => false
  }
}

///|
/// Check if symbol kind is Enum
fn is_enum_kind(kind : @compiler.SymbolKind) -> Bool {
  match kind {
    Enum => true
    _ => false
  }
}

///|
/// Check if symbol kind is Type
fn is_type_kind(kind : @compiler.SymbolKind) -> Bool {
  match kind {
    Type => true
    _ => false
  }
}

///|
/// Check if symbol kind is Module
fn is_module_kind(kind : @compiler.SymbolKind) -> Bool {
  match kind {
    Module => true
    _ => false
  }
}

// ============================================================================
// Symbol Binding Tests
// ============================================================================

///|
test "bind variable declaration" {
  let source = "const x = 1;"
  match parse_and_bind(source) {
    Ok(bound_file) => {
      let symbol = bound_file.global_scope.symbols.get("x")
      assert_true(symbol.is_some())
      match symbol {
        Some(s) => {
          assert_true(is_variable_kind(s.kind))
          assert_eq(s.name, "x")
          assert_eq(s.flags.is_const, true)
        }
        None => assert_true(false)
      }
    }
    Err(_) => assert_true(false)
  }
}

///|
test "bind let variable declaration" {
  let source = "let y = 2;"
  match parse_and_bind(source) {
    Ok(bound_file) => {
      let symbol = bound_file.global_scope.symbols.get("y")
      assert_true(symbol.is_some())
      match symbol {
        Some(s) => {
          assert_true(is_variable_kind(s.kind))
          assert_eq(s.flags.is_const, false)
        }
        None => assert_true(false)
      }
    }
    Err(_) => assert_true(false)
  }
}

///|
test "bind function declaration" {
  let source = "function foo() {}"
  match parse_and_bind(source) {
    Ok(bound_file) => {
      let symbol = bound_file.global_scope.symbols.get("foo")
      assert_true(symbol.is_some())
      match symbol {
        Some(s) => {
          assert_true(is_function_kind(s.kind))
          assert_eq(s.name, "foo")
        }
        None => assert_true(false)
      }
    }
    Err(_) => assert_true(false)
  }
}

///|
test "bind class declaration" {
  let source = "class MyClass {}"
  match parse_and_bind(source) {
    Ok(bound_file) => {
      let symbol = bound_file.global_scope.symbols.get("MyClass")
      assert_true(symbol.is_some())
      match symbol {
        Some(s) => {
          assert_true(is_class_kind(s.kind))
          assert_eq(s.name, "MyClass")
        }
        None => assert_true(false)
      }
    }
    Err(_) => assert_true(false)
  }
}

///|
test "bind interface declaration" {
  let source = "interface IFoo { x: number; }"
  match parse_and_bind(source) {
    Ok(bound_file) => {
      let symbol = bound_file.global_scope.symbols.get("IFoo")
      assert_true(symbol.is_some())
      match symbol {
        Some(s) => {
          assert_true(is_interface_kind(s.kind))
          assert_eq(s.name, "IFoo")
        }
        None => assert_true(false)
      }
    }
    Err(_) => assert_true(false)
  }
}

///|
test "bind enum declaration" {
  let source = "enum Color { Red, Green, Blue }"
  match parse_and_bind(source) {
    Ok(bound_file) => {
      let symbol = bound_file.global_scope.symbols.get("Color")
      assert_true(symbol.is_some())
      match symbol {
        Some(s) => {
          assert_true(is_enum_kind(s.kind))
          assert_eq(s.name, "Color")
        }
        None => assert_true(false)
      }
    }
    Err(_) => assert_true(false)
  }
}

///|
test "bind type alias declaration" {
  let source = "type StringOrNumber = string | number;"
  match parse_and_bind(source) {
    Ok(bound_file) => {
      let symbol = bound_file.global_scope.symbols.get("StringOrNumber")
      assert_true(symbol.is_some())
      match symbol {
        Some(s) => {
          assert_true(is_type_kind(s.kind))
          assert_eq(s.name, "StringOrNumber")
        }
        None => assert_true(false)
      }
    }
    Err(_) => assert_true(false)
  }
}

// ============================================================================
// Module Detection Tests
// ============================================================================

///|
test "detect ES module with import" {
  let source = "import { foo } from 'bar';"
  match parse_and_bind(source) {
    Ok(bound_file) => {
      assert_eq(bound_file.module_info.is_external_module, true)
      assert_eq(bound_file.module_info.imports.length() > 0, true)
    }
    Err(_) => assert_true(false)
  }
}

///|
test "detect ES module with export" {
  let source = "export const x = 1;"
  match parse_and_bind(source) {
    Ok(bound_file) => {
      assert_eq(bound_file.module_info.is_external_module, true)
      assert_eq(bound_file.module_info.exports.length() > 0, true)
    }
    Err(_) => assert_true(false)
  }
}

///|
test "detect strict mode" {
  let source = "\"use strict\";\nconst x = 1;"
  match parse_and_bind(source) {
    Ok(bound_file) => {
      assert_eq(bound_file.module_info.is_strict_mode, true)
    }
    Err(_) => assert_true(false)
  }
}

///|
test "detect non-module script" {
  let source = "const x = 1; function foo() {}"
  match parse_and_bind(source) {
    Ok(bound_file) => {
      assert_eq(bound_file.module_info.is_external_module, false)
      assert_eq(bound_file.module_info.is_commonjs_module, false)
    }
    Err(_) => assert_true(false)
  }
}

// ============================================================================
// Declaration Merging Tests
// ============================================================================

///|
test "can merge interfaces from parsed source" {
  // Test merging by parsing two interface declarations
  let source = "interface IFoo { x: number; }\ninterface IFoo { y: string; }"
  match parse_and_bind(source) {
    Ok(bound_file) => {
      // Should succeed - interfaces can merge
      let symbol = bound_file.global_scope.symbols.get("IFoo")
      assert_true(symbol.is_some())
    }
    Err(_) => assert_true(false)
  }
}

///|
test "cannot merge variables from parsed source" {
  // Variables cannot merge - should get duplicate error
  let source = "const x = 1;\nconst x = 2;"
  match parse_and_bind(source) {
    Ok(_) => assert_true(false) // Should have errors
    Err(diagnostics) => {
      assert_true(diagnostics.length() > 0)
    }
  }
}

///|
test "cannot merge type aliases from parsed source" {
  // Type aliases cannot merge
  let source = "type T = string;\ntype T = number;"
  match parse_and_bind(source) {
    Ok(_) => assert_true(false) // Should have errors
    Err(diagnostics) => {
      assert_true(diagnostics.length() > 0)
    }
  }
}

// ============================================================================
// Scope Tests
// ============================================================================

///|
test "function creates new scope" {
  let source = "function foo(x: number) { const y = x; }"
  match parse_and_bind(source) {
    Ok(bound_file) => {
      // Function should be in global scope
      let foo_symbol = bound_file.global_scope.symbols.get("foo")
      assert_true(foo_symbol.is_some())
      // Parameter and local variable are in function scope, not global
      let x_symbol = bound_file.global_scope.symbols.get("x")
      let y_symbol = bound_file.global_scope.symbols.get("y")
      assert_true(x_symbol.is_none())
      assert_true(y_symbol.is_none())
    }
    Err(_) => assert_true(false)
  }
}

///|
test "class creates new scope for members" {
  let source = "class Foo { x: number; foo() {} }"
  match parse_and_bind(source) {
    Ok(bound_file) => {
      // Class should be in global scope
      let class_symbol = bound_file.global_scope.symbols.get("Foo")
      assert_true(class_symbol.is_some())
      // Class members are not in global scope
      let x_symbol = bound_file.global_scope.symbols.get("x")
      assert_true(x_symbol.is_none())
    }
    Err(_) => assert_true(false)
  }
}

// ============================================================================
// Control Flow Tests
// ============================================================================

///|
test "return statement creates flow" {
  let source = "function foo() { return 1; }"
  match parse_and_bind(source) {
    Ok(bound_file) => {
      // Should bind successfully - return creates flow node
      let symbol = bound_file.global_scope.symbols.get("foo")
      assert_true(symbol.is_some())
    }
    Err(_) => assert_true(false)
  }
}

///|
test "if statement creates flow" {
  let source = "function foo(x: boolean) { if (x) { return 1; } return 2; }"
  match parse_and_bind(source) {
    Ok(bound_file) => {
      // Should bind successfully - if creates condition flow nodes
      let symbol = bound_file.global_scope.symbols.get("foo")
      assert_true(symbol.is_some())
    }
    Err(_) => assert_true(false)
  }
}

///|
test "while loop creates flow" {
  let source = "function foo() { let i = 0; while (i < 10) { i++; } }"
  match parse_and_bind(source) {
    Ok(bound_file) => {
      let symbol = bound_file.global_scope.symbols.get("foo")
      assert_true(symbol.is_some())
    }
    Err(_) => assert_true(false)
  }
}

///|
test "switch statement creates flow" {
  let source = "function foo(x: number) { switch (x) { case 1: return 'one'; default: return 'other'; } }"
  match parse_and_bind(source) {
    Ok(bound_file) => {
      let symbol = bound_file.global_scope.symbols.get("foo")
      assert_true(symbol.is_some())
    }
    Err(_) => assert_true(false)
  }
}

// ============================================================================
// ModuleInfo Tests
// ============================================================================

///|
test "script file has default module info" {
  let source = "const x = 1;"
  match parse_and_bind(source) {
    Ok(bound_file) => {
      assert_eq(bound_file.module_info.is_external_module, false)
      assert_eq(bound_file.module_info.is_commonjs_module, false)
      assert_eq(bound_file.module_info.is_ambient_module, false)
    }
    Err(_) => assert_true(false)
  }
}

///|
test "module file has exports in module info" {
  let source = "export const x = 1;"
  match parse_and_bind(source) {
    Ok(bound_file) => {
      assert_eq(bound_file.module_info.is_external_module, true)
      assert_true(bound_file.module_info.exports.length() > 0)
    }
    Err(_) => assert_true(false)
  }
}

///|
test "module file has imports in module info" {
  let source = "import { foo } from 'bar';"
  match parse_and_bind(source) {
    Ok(bound_file) => {
      assert_eq(bound_file.module_info.is_external_module, true)
      assert_true(bound_file.module_info.imports.length() > 0)
    }
    Err(_) => assert_true(false)
  }
}

// ============================================================================
// Duplicate Declaration and Overload Tests
// ============================================================================

///|
test "function overloads allowed" {
  let source = "function foo(): void;\nfunction foo(x: number): void;\nfunction foo(x?: number) {}"
  match parse_and_bind(source) {
    Ok(bound_file) => {
      // Should succeed without duplicate errors
      let symbol = bound_file.global_scope.symbols.get("foo")
      assert_true(symbol.is_some())
    }
    Err(_) => assert_true(false)
  }
}

// ============================================================================
// Import/Export Detection Tests
// ============================================================================

///|
test "named imports detection" {
  let source = "import { a, b as c } from 'module';"
  match parse_and_bind(source) {
    Ok(bound_file) => {
      assert_eq(bound_file.module_info.is_external_module, true)
      assert_eq(bound_file.module_info.imports.length(), 1)
      let import_info = bound_file.module_info.imports[0]
      assert_eq(import_info.module_specifier, "module")
    }
    Err(_) => assert_true(false)
  }
}

///|
test "export function detection" {
  let source = "export function myFunc() {}"
  match parse_and_bind(source) {
    Ok(bound_file) => {
      assert_eq(bound_file.module_info.is_external_module, true)
      assert_eq(bound_file.module_info.exports.length() > 0, true)
    }
    Err(_) => assert_true(false)
  }
}

///|
test "export class detection" {
  let source = "export class MyClass {}"
  match parse_and_bind(source) {
    Ok(bound_file) => {
      assert_eq(bound_file.module_info.is_external_module, true)
      let has_class_export = bound_file.module_info.exports.length() > 0
      assert_true(has_class_export)
    }
    Err(_) => assert_true(false)
  }
}
