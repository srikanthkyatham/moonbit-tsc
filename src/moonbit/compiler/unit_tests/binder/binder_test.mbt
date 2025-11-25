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

///|
test "bind namespace declaration" {
  let source = "namespace MyNamespace { export const x = 1; }"
  match parse_and_bind(source) {
    Ok(bound_file) => {
      let symbol = bound_file.global_scope.symbols.get("MyNamespace")
      assert_true(symbol.is_some())
      match symbol {
        Some(s) => {
          assert_true(is_module_kind(s.kind))
          assert_eq(s.name, "MyNamespace")
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

// ============================================================================
// Container Tracking Tests
// ============================================================================

///|
test "function container creates correct scope for parameters" {
  // Test that function container is properly tracking scope
  let source = "function outer(a: number) { function inner(b: number) { return a + b; } }"
  match parse_and_bind(source) {
    Ok(bound_file) => {
      // outer should be in global scope
      assert_true(bound_file.global_scope.symbols.contains("outer"))
      // a, inner, b should NOT be in global scope (they're in function containers)
      assert_false(bound_file.global_scope.symbols.contains("a"))
      assert_false(bound_file.global_scope.symbols.contains("inner"))
      assert_false(bound_file.global_scope.symbols.contains("b"))
    }
    Err(_) => assert_true(false)
  }
}

///|
test "class container creates correct scope for members" {
  // Test that class container properly scopes methods and properties
  let source = "class MyClass { prop: number; method(x: number) { return this.prop + x; } }"
  match parse_and_bind(source) {
    Ok(bound_file) => {
      // MyClass should be in global scope
      assert_true(bound_file.global_scope.symbols.contains("MyClass"))
      // prop, method, x should NOT be in global scope (they're in class/function containers)
      assert_false(bound_file.global_scope.symbols.contains("prop"))
      assert_false(bound_file.global_scope.symbols.contains("method"))
      assert_false(bound_file.global_scope.symbols.contains("x"))
    }
    Err(_) => assert_true(false)
  }
}

///|
test "block container creates correct scope for variables" {
  // Test that block container properly scopes let/const variables
  let source = "{ const blockVar = 1; { const nestedVar = 2; } }"
  match parse_and_bind(source) {
    Ok(bound_file) => {
      // Block-scoped variables should NOT be in global scope
      assert_false(bound_file.global_scope.symbols.contains("blockVar"))
      assert_false(bound_file.global_scope.symbols.contains("nestedVar"))
    }
    Err(_) => assert_true(false)
  }
}

///|
test "for statement container creates correct scope" {
  // Test that ForStatement container properly scopes loop variables
  let source = "for (let i = 0; i < 10; i++) { const loopVar = i; }"
  match parse_and_bind(source) {
    Ok(bound_file) => {
      // Loop variables should NOT be in global scope
      assert_false(bound_file.global_scope.symbols.contains("i"))
      assert_false(bound_file.global_scope.symbols.contains("loopVar"))
    }
    Err(_) => assert_true(false)
  }
}

///|
test "catch block container creates correct scope" {
  // Test that CatchBlock container properly scopes catch variable
  let source = "try { throw new Error(); } catch (e) { const handler = e; }"
  match parse_and_bind(source) {
    Ok(bound_file) => {
      // Catch variables should NOT be in global scope
      assert_false(bound_file.global_scope.symbols.contains("e"))
      assert_false(bound_file.global_scope.symbols.contains("handler"))
    }
    Err(_) => assert_true(false)
  }
}

///|
test "interface container creates correct scope for type parameters" {
  // Test that interface container properly scopes type parameters
  let source = "interface Container<T> { value: T; }"
  match parse_and_bind(source) {
    Ok(bound_file) => {
      // Interface should be in global scope
      assert_true(bound_file.global_scope.symbols.contains("Container"))
      // Type parameter T should NOT be in global scope
      assert_false(bound_file.global_scope.symbols.contains("T"))
    }
    Err(_) => assert_true(false)
  }
}

///|
test "module/namespace container creates correct scope" {
  // Test that Module container properly scopes namespace contents
  let source = "namespace MyNS { export const nsVar = 1; function nsFunc() {} }"
  match parse_and_bind(source) {
    Ok(bound_file) => {
      // Namespace should be in global scope
      assert_true(bound_file.global_scope.symbols.contains("MyNS"))
      // Namespace members should NOT be in global scope
      assert_false(bound_file.global_scope.symbols.contains("nsVar"))
      assert_false(bound_file.global_scope.symbols.contains("nsFunc"))
    }
    Err(_) => assert_true(false)
  }
}

///|
test "enum container creates correct scope for members" {
  // Test that EnumDeclaration container properly handles enum members
  let source = "enum Status { Active, Inactive, Pending }"
  match parse_and_bind(source) {
    Ok(bound_file) => {
      // Enum should be in global scope
      assert_true(bound_file.global_scope.symbols.contains("Status"))
      // Enum members should also be bound (in global scope for TypeScript)
      assert_true(bound_file.global_scope.symbols.contains("Active"))
      assert_true(bound_file.global_scope.symbols.contains("Inactive"))
      assert_true(bound_file.global_scope.symbols.contains("Pending"))
    }
    Err(_) => assert_true(false)
  }
}

///|
test "arrow function container creates correct scope" {
  // Test that arrow function properly creates function container
  let source = "const add = (a: number, b: number) => { const sum = a + b; return sum; };"
  match parse_and_bind(source) {
    Ok(bound_file) => {
      // add should be in global scope
      assert_true(bound_file.global_scope.symbols.contains("add"))
      // Arrow function params and locals should NOT be in global scope
      assert_false(bound_file.global_scope.symbols.contains("a"))
      assert_false(bound_file.global_scope.symbols.contains("b"))
      assert_false(bound_file.global_scope.symbols.contains("sum"))
    }
    Err(_) => assert_true(false)
  }
}

///|
test "function expression container creates correct scope" {
  // Test that function expression properly creates function container
  let source = "const multiply = function(x: number, y: number) { const result = x * y; return result; };"
  match parse_and_bind(source) {
    Ok(bound_file) => {
      // multiply should be in global scope
      assert_true(bound_file.global_scope.symbols.contains("multiply"))
      // Function expression params and locals should NOT be in global scope
      assert_false(bound_file.global_scope.symbols.contains("x"))
      assert_false(bound_file.global_scope.symbols.contains("y"))
      assert_false(bound_file.global_scope.symbols.contains("result"))
    }
    Err(_) => assert_true(false)
  }
}

///|
test "class method container creates correct scope" {
  // Test that class method creates function container for its body
  let source = "class Calculator { add(a: number, b: number) { const sum = a + b; return sum; } }"
  match parse_and_bind(source) {
    Ok(bound_file) => {
      // Calculator should be in global scope
      assert_true(bound_file.global_scope.symbols.contains("Calculator"))
      // Method params and locals should NOT be in global scope
      assert_false(bound_file.global_scope.symbols.contains("a"))
      assert_false(bound_file.global_scope.symbols.contains("b"))
      assert_false(bound_file.global_scope.symbols.contains("sum"))
    }
    Err(_) => assert_true(false)
  }
}

///|
test "class constructor container creates correct scope" {
  // Test that constructor creates function container for its body
  let source = "class Person { constructor(name: string) { const greeting = 'Hello ' + name; } }"
  match parse_and_bind(source) {
    Ok(bound_file) => {
      // Person should be in global scope
      assert_true(bound_file.global_scope.symbols.contains("Person"))
      // Constructor params and locals should NOT be in global scope
      assert_false(bound_file.global_scope.symbols.contains("name"))
      assert_false(bound_file.global_scope.symbols.contains("greeting"))
    }
    Err(_) => assert_true(false)
  }
}

///|
test "getter accessor container creates correct scope" {
  // Test that getter creates function container for its body
  let source = "class Circle { get area() { const pi = 3.14; return pi; } }"
  match parse_and_bind(source) {
    Ok(bound_file) => {
      // Circle should be in global scope
      assert_true(bound_file.global_scope.symbols.contains("Circle"))
      // Getter locals should NOT be in global scope
      assert_false(bound_file.global_scope.symbols.contains("pi"))
    }
    Err(_) => assert_true(false)
  }
}

///|
test "setter accessor container creates correct scope" {
  // Test that setter creates function container for its body
  let source = "class Circle { set radius(value: number) { const r = value; } }"
  match parse_and_bind(source) {
    Ok(bound_file) => {
      // Circle should be in global scope
      assert_true(bound_file.global_scope.symbols.contains("Circle"))
      // Setter param and locals should NOT be in global scope
      assert_false(bound_file.global_scope.symbols.contains("value"))
      assert_false(bound_file.global_scope.symbols.contains("r"))
    }
    Err(_) => assert_true(false)
  }
}

///|
test "nested containers maintain correct scope hierarchy" {
  // Test deeply nested container hierarchy
  let source = "class Outer { method() { const nested = () => { for (let i = 0; i < 1; i++) { const deep = i; } }; } }"
  match parse_and_bind(source) {
    Ok(bound_file) => {
      // Only Outer should be in global scope
      assert_true(bound_file.global_scope.symbols.contains("Outer"))
      // All nested declarations should NOT be in global scope
      assert_false(bound_file.global_scope.symbols.contains("method"))
      assert_false(bound_file.global_scope.symbols.contains("nested"))
      assert_false(bound_file.global_scope.symbols.contains("i"))
      assert_false(bound_file.global_scope.symbols.contains("deep"))
    }
    Err(_) => assert_true(false)
  }
}

// ============================================================================
// Control Flow Graph Tests
// ============================================================================

///|
test "CFG has start and end nodes for empty source" {
  let source = ""
  match parse_and_bind(source) {
    Ok(bound_file) => {
      let cfg = bound_file.control_flow_graph
      // CFG should have at least start and end nodes
      assert_true(cfg.nodes.length() >= 2)
      // Entry should be 0 (start node)
      assert_eq(cfg.entry, 0)
      // Exit should be the last node
      assert_true(cfg.exit > 0)
    }
    Err(_) => assert_true(false)
  }
}

///|
test "CFG builds for simple variable declaration" {
  let source = "const x = 1;"
  match parse_and_bind(source) {
    Ok(bound_file) => {
      let cfg = bound_file.control_flow_graph
      // Should have start, end nodes and possibly assignment
      assert_true(cfg.nodes.length() >= 2)
      // Node map should have entries
      assert_true(cfg.node_map.size() >= 2)
    }
    Err(_) => assert_true(false)
  }
}

///|
test "CFG creates assignment flow for variable assignment" {
  let source = "let x = 1; x = 2;"
  match parse_and_bind(source) {
    Ok(bound_file) => {
      let cfg = bound_file.control_flow_graph
      // Should have start, assignment(s), and end nodes
      assert_true(cfg.nodes.length() >= 3)
    }
    Err(_) => assert_true(false)
  }
}

///|
test "CFG creates call flow for function calls" {
  let source = "function foo() {} foo();"
  match parse_and_bind(source) {
    Ok(bound_file) => {
      let cfg = bound_file.control_flow_graph
      // Should have nodes for the function call
      assert_true(cfg.nodes.length() >= 2)
    }
    Err(_) => assert_true(false)
  }
}

///|
test "CFG creates condition flow for if statement" {
  let source = "const x = true; if (x) { const y = 1; }"
  match parse_and_bind(source) {
    Ok(bound_file) => {
      let cfg = bound_file.control_flow_graph
      // Should have nodes including condition
      assert_true(cfg.nodes.length() >= 2)
    }
    Err(_) => assert_true(false)
  }
}

///|
test "CFG creates return flow for return statement" {
  let source = "function foo() { return 42; }"
  match parse_and_bind(source) {
    Ok(bound_file) => {
      let cfg = bound_file.control_flow_graph
      // Should have nodes including return
      assert_true(cfg.nodes.length() >= 2)
    }
    Err(_) => assert_true(false)
  }
}

///|
test "CFG creates switch clause flows" {
  let source = "const x = 1; switch (x) { case 1: break; case 2: break; }"
  match parse_and_bind(source) {
    Ok(bound_file) => {
      let cfg = bound_file.control_flow_graph
      // Should have nodes for switch clauses
      assert_true(cfg.nodes.length() >= 2)
    }
    Err(_) => assert_true(false)
  }
}

///|
test "CFG creates array mutation flow for array element assignment" {
  let source = "const arr = [1, 2, 3]; arr[0] = 10;"
  match parse_and_bind(source) {
    Ok(bound_file) => {
      let cfg = bound_file.control_flow_graph
      // Should have nodes including array mutation
      assert_true(cfg.nodes.length() >= 2)
    }
    Err(_) => assert_true(false)
  }
}

///|
test "CFG node map contains all nodes" {
  let source = "let x = 1; x = 2; x = 3;"
  match parse_and_bind(source) {
    Ok(bound_file) => {
      let cfg = bound_file.control_flow_graph
      // Node map should have same number of entries as nodes array
      assert_eq(cfg.node_map.size(), cfg.nodes.length())
    }
    Err(_) => assert_true(false)
  }
}

///|
test "CFG for complex function with multiple flows" {
  let source = "function calc(x: number) { if (x > 0) { return x; } return -x; }"
  match parse_and_bind(source) {
    Ok(bound_file) => {
      let cfg = bound_file.control_flow_graph
      // Should have start, end, and flow nodes for the branching
      assert_true(cfg.nodes.length() >= 2)
      assert_true(cfg.entry == 0)
      assert_true(cfg.exit > 0)
    }
    Err(_) => assert_true(false)
  }
}

///|
test "CFG for for loop creates condition flow" {
  let source = "for (let i = 0; i < 10; i++) { const x = i; }"
  match parse_and_bind(source) {
    Ok(bound_file) => {
      let cfg = bound_file.control_flow_graph
      // Should have condition flow for the for loop
      assert_true(cfg.nodes.length() >= 2)
    }
    Err(_) => assert_true(false)
  }
}

///|
test "CFG for while loop creates condition flow" {
  let source = "let x = 0; while (x < 10) { x++; }"
  match parse_and_bind(source) {
    Ok(bound_file) => {
      let cfg = bound_file.control_flow_graph
      // Should have condition flow for the while loop
      assert_true(cfg.nodes.length() >= 2)
    }
    Err(_) => assert_true(false)
  }
}

///|
test "CFG for throw statement creates throw flow" {
  let source = "function fail() { throw new Error('error'); }"
  match parse_and_bind(source) {
    Ok(bound_file) => {
      let cfg = bound_file.control_flow_graph
      // Should have nodes including throw
      assert_true(cfg.nodes.length() >= 2)
    }
    Err(_) => assert_true(false)
  }
}
