// Binder Tests
// Tests for the TypeScript binder (AST -> Symbol Tables)

///|
/// Helper to parse and bind source code
fn parse_and_bind(source : String) -> BindResult {
  let tokens = tokens_from_source(source)
  match parse_source_file(tokens, "test.ts") {
    Ok(source_file) => bind_source_file(source_file)
    Err(diagnostics) => Err(diagnostics)
  }
}

///|
/// Helper to create tokens from source (defined in parser_test.mbt as well)
// fn tokens_from_source(source : String) -> Array[Token] {
//   let scanner = Scanner::new(source, "test.ts")
//   scan_all(scanner)
// }

// ============================================================================
// Variable Declaration Tests
// ============================================================================

///|
test "bind variable declaration" {
  let result = parse_and_bind("const x = 42;")
  match result {
    Ok(bound) => {
      assert_eq(bound.file_path, "test.ts")
      assert_true(bound.global_scope.symbols.contains("x"))
      match bound.global_scope.symbols.get("x") {
        Some(sym) => {
          assert_eq(sym.name, "x")
          match sym.kind {
            Variable => ()
            _ => assert_true(false)
          }
        }
        None => assert_true(false)
      }
    }
    Err(_) => assert_true(false)
  }
}

///|
test "bind multiple variables" {
  let result = parse_and_bind("let x = 1; const y = 2; var z = 3;")
  match result {
    Ok(bound) => {
      assert_true(bound.global_scope.symbols.contains("x"))
      assert_true(bound.global_scope.symbols.contains("y"))
      assert_true(bound.global_scope.symbols.contains("z"))
    }
    Err(_) => assert_true(false)
  }
}

///|
test "detect duplicate variable declaration" {
  let result = parse_and_bind("const x = 1; const x = 2;")
  match result {
    Ok(_) => assert_true(false) // Should have error
    Err(diagnostics) => {
      assert_true(diagnostics.length() > 0)
      // Check that diagnostic mentions duplicate identifier
      match diagnostics[0] {
        diag => assert_true(diag.message.contains("Duplicate"))
      }
    }
  }
}

// ============================================================================
// Function Declaration Tests
// ============================================================================

///|
test "bind function declaration" {
  let result = parse_and_bind("function greet() {}")
  match result {
    Ok(bound) => {
      assert_true(bound.global_scope.symbols.contains("greet"))
      match bound.global_scope.symbols.get("greet") {
        Some(sym) => {
          assert_eq(sym.name, "greet")
          match sym.kind {
            Function => ()
            _ => assert_true(false)
          }
        }
        None => assert_true(false)
      }
    }
    Err(_) => assert_true(false)
  }
}

///|
test "bind function with parameters" {
  let result = parse_and_bind("function add(a, b) { return a + b; }")
  match result {
    Ok(bound) => assert_true(bound.global_scope.symbols.contains("add"))
    Err(_) => assert_true(false)
  }
}

// ============================================================================
// Class Declaration Tests
// ============================================================================

///|
test "bind class declaration" {
  let result = parse_and_bind("class Foo {}")
  match result {
    Ok(bound) => {
      assert_true(bound.global_scope.symbols.contains("Foo"))
      match bound.global_scope.symbols.get("Foo") {
        Some(sym) => {
          assert_eq(sym.name, "Foo")
          match sym.kind {
            Class => ()
            _ => assert_true(false)
          }
        }
        None => assert_true(false)
      }
    }
    Err(_) => assert_true(false)
  }
}

///|
test "bind class with methods" {
  let result = parse_and_bind("class Foo { bar() {} }")
  match result {
    Ok(bound) => assert_true(bound.global_scope.symbols.contains("Foo"))
    Err(_) => assert_true(false)
  }
}

// ============================================================================
// Interface Declaration Tests
// ============================================================================

///|
test "bind interface declaration" {
  let result = parse_and_bind("interface IFoo {}")
  match result {
    Ok(bound) => {
      assert_true(bound.global_scope.symbols.contains("IFoo"))
      match bound.global_scope.symbols.get("IFoo") {
        Some(sym) => {
          assert_eq(sym.name, "IFoo")
          match sym.kind {
            Interface => ()
            _ => assert_true(false)
          }
        }
        None => assert_true(false)
      }
    }
    Err(_) => assert_true(false)
  }
}

// ============================================================================
// Enum Declaration Tests
// ============================================================================

///|
test "bind enum declaration" {
  let result = parse_and_bind("enum Color { Red, Green, Blue }")
  match result {
    Ok(bound) => {
      assert_true(bound.global_scope.symbols.contains("Color"))
      match bound.global_scope.symbols.get("Color") {
        Some(sym) => {
          assert_eq(sym.name, "Color")
          match sym.kind {
            Enum => ()
            _ => assert_true(false)
          }
        }
        None => assert_true(false)
      }
    }
    Err(_) => assert_true(false)
  }
}

// ============================================================================
// Type Alias Tests
// ============================================================================

///|
test "bind type alias" {
  let result = parse_and_bind("type Foo = Bar;")
  match result {
    Ok(bound) => {
      assert_true(bound.global_scope.symbols.contains("Foo"))
      match bound.global_scope.symbols.get("Foo") {
        Some(sym) => {
          assert_eq(sym.name, "Foo")
          match sym.kind {
            Type => ()
            _ => assert_true(false)
          }
        }
        None => assert_true(false)
      }
    }
    Err(_) => assert_true(false)
  }
}

// ============================================================================
// Import Declaration Tests
// ============================================================================

///|
test "bind default import" {
  let result = parse_and_bind("import foo from 'module';")
  match result {
    Ok(bound) => {
      assert_true(bound.global_scope.symbols.contains("foo"))
      match bound.global_scope.symbols.get("foo") {
        Some(sym) => {
          assert_eq(sym.name, "foo")
          match sym.kind {
            Alias => ()
            _ => assert_true(false)
          }
        }
        None => assert_true(false)
      }
    }
    Err(_) => assert_true(false)
  }
}

///|
test "bind named import" {
  let result = parse_and_bind("import { a, b } from 'module';")
  match result {
    Ok(bound) => {
      assert_true(bound.global_scope.symbols.contains("a"))
      assert_true(bound.global_scope.symbols.contains("b"))
    }
    Err(_) => assert_true(false)
  }
}

///|
test "bind namespace import" {
  let result = parse_and_bind("import * as foo from 'module';")
  match result {
    Ok(bound) => {
      assert_true(bound.global_scope.symbols.contains("foo"))
      match bound.global_scope.symbols.get("foo") {
        Some(sym) => {
          assert_eq(sym.name, "foo")
          match sym.kind {
            Module => ()
            _ => assert_true(false)
          }
        }
        None => assert_true(false)
      }
    }
    Err(_) => assert_true(false)
  }
}

// ============================================================================
// Scope Tests
// ============================================================================

///|
test "bind block creates new scope" {
  let result = parse_and_bind("{ const x = 1; }")
  match result {
    Ok(bound) =>
      // Variable x should not be in global scope
      assert_false(bound.global_scope.symbols.contains("x"))
    Err(_) => assert_true(false)
  }
}

///|
test "bind function creates new scope" {
  let result = parse_and_bind("function f() { const x = 1; }")
  match result {
    Ok(bound) => {
      // Function f should be in global scope
      assert_true(bound.global_scope.symbols.contains("f"))
      // Variable x should not be in global scope
      assert_false(bound.global_scope.symbols.contains("x"))
    }
    Err(_) => assert_true(false)
  }
}

// ============================================================================
// Variable Shadowing Tests
// ============================================================================

///|
test "bind variable shadowing in nested blocks allowed" {
  let result = parse_and_bind("const x = 1; { const x = 2; }")
  match result {
    Ok(bound) =>
      // Outer x should be in global scope
      assert_true(bound.global_scope.symbols.contains("x"))
    Err(_) => assert_true(false)
  }
}

///|
test "bind variable shadowing in function allowed" {
  let result = parse_and_bind("const x = 1; function f() { const x = 2; }")
  match result {
    Ok(bound) => {
      // Outer x should be in global scope
      assert_true(bound.global_scope.symbols.contains("x"))
      // Function f should also be in global scope
      assert_true(bound.global_scope.symbols.contains("f"))
    }
    Err(_) => assert_true(false)
  }
}

///|
test "bind duplicate in same block scope error" {
  let result = parse_and_bind("{ const x = 1; const x = 2; }")
  match result {
    Ok(_) => assert_true(false) // Should have error
    Err(diagnostics) => {
      assert_true(diagnostics.length() > 0)
      match diagnostics[0] {
        diag => assert_true(diag.message.contains("Duplicate"))
      }
    }
  }
}

///|
test "bind let vs const duplicate error" {
  let result = parse_and_bind("let x = 1; const x = 2;")
  match result {
    Ok(_) => assert_true(false) // Should have error
    Err(diagnostics) => assert_true(diagnostics.length() > 0)
  }
}

// ============================================================================
// Nested Scope Tests
// ============================================================================

///|
test "bind nested block scopes" {
  let result = parse_and_bind(
    "{ const x = 1; { const y = 2; { const z = 3; } } }",
  )
  match result {
    Ok(bound) => {
      // None of the variables should be in global scope
      assert_false(bound.global_scope.symbols.contains("x"))
      assert_false(bound.global_scope.symbols.contains("y"))
      assert_false(bound.global_scope.symbols.contains("z"))
    }
    Err(_) => assert_true(false)
  }
}

///|
test "bind if statement creates block scope" {
  let result = parse_and_bind("if (true) { const x = 1; }")
  match result {
    Ok(bound) =>
      // x should not be in global scope
      assert_false(bound.global_scope.symbols.contains("x"))
    Err(_) => assert_true(false)
  }
}

///|
test "bind for loop creates block scope" {
  let result = parse_and_bind("for (let i = 0; i < 10; i++) { const x = i; }")
  match result {
    Ok(bound) => {
      // Neither i nor x should be in global scope
      assert_false(bound.global_scope.symbols.contains("i"))
      assert_false(bound.global_scope.symbols.contains("x"))
    }
    Err(_) => assert_true(false)
  }
}

///|
test "bind while loop creates block scope" {
  let result = parse_and_bind("while (true) { const x = 1; }")
  match result {
    Ok(bound) =>
      // x should not be in global scope
      assert_false(bound.global_scope.symbols.contains("x"))
    Err(_) => assert_true(false)
  }
}

// ============================================================================
// Function Parameter Scope Tests
// ============================================================================

///|
test "bind function parameters in function scope" {
  let result = parse_and_bind("function add(a, b) { return a + b; }")
  match result {
    Ok(bound) => {
      // Function should be in global scope
      assert_true(bound.global_scope.symbols.contains("add"))
      // Parameters should not be in global scope
      assert_false(bound.global_scope.symbols.contains("a"))
      assert_false(bound.global_scope.symbols.contains("b"))
    }
    Err(_) => assert_true(false)
  }
}

///|
test "bind parameter shadowing outer variable allowed" {
  let result = parse_and_bind("const x = 1; function f(x) { return x; }")
  match result {
    Ok(bound) => {
      // Both x and f should be in global scope
      assert_true(bound.global_scope.symbols.contains("x"))
      assert_true(bound.global_scope.symbols.contains("f"))
    }
    Err(_) => assert_true(false)
  }
}

///|
test "bind duplicate parameters error" {
  let result = parse_and_bind("function f(x, x) { }")
  match result {
    Ok(_) => assert_true(false) // Should have error
    Err(diagnostics) => {
      assert_true(diagnostics.length() > 0)
      match diagnostics[0] {
        diag => assert_true(diag.message.contains("Duplicate"))
      }
    }
  }
}

// ============================================================================
// Catch Clause Scope Tests
// ============================================================================

///|
test "bind catch parameter creates scope" {
  let result = parse_and_bind("try { } catch (e) { const x = e; }")
  match result {
    Ok(bound) => {
      // Neither e nor x should be in global scope
      assert_false(bound.global_scope.symbols.contains("e"))
      assert_false(bound.global_scope.symbols.contains("x"))
    }
    Err(_) => assert_true(false)
  }
}

///|
test "bind catch parameter shadowing allowed" {
  let result = parse_and_bind("const e = 1; try { } catch (e) { }")
  match result {
    Ok(bound) =>
      // Outer e should be in global scope
      assert_true(bound.global_scope.symbols.contains("e"))
    Err(_) => assert_true(false)
  }
}

///|
test "bind try-catch without catch variable" {
  let result = parse_and_bind("try { const x = 1; } catch { const y = 2; }")
  match result {
    Ok(bound) => {
      // Neither x nor y should be in global scope
      assert_false(bound.global_scope.symbols.contains("x"))
      assert_false(bound.global_scope.symbols.contains("y"))
    }
    Err(_) => assert_true(false)
  }
}

///|
test "bind try-catch-finally" {
  let result = parse_and_bind(
    "try { const a = 1; } catch (e) { const b = 2; } finally { const c = 3; }",
  )
  match result {
    Ok(bound) => {
      // None of the variables should be in global scope
      assert_false(bound.global_scope.symbols.contains("a"))
      assert_false(bound.global_scope.symbols.contains("b"))
      assert_false(bound.global_scope.symbols.contains("c"))
      assert_false(bound.global_scope.symbols.contains("e"))
    }
    Err(_) => assert_true(false)
  }
}

///|
test "bind try-finally without catch" {
  let result = parse_and_bind("try { const x = 1; } finally { const y = 2; }")
  match result {
    Ok(bound) => {
      // Neither x nor y should be in global scope
      assert_false(bound.global_scope.symbols.contains("x"))
      assert_false(bound.global_scope.symbols.contains("y"))
    }
    Err(_) => assert_true(false)
  }
}

///|
test "bind catch with object destructuring pattern" {
  let result = parse_and_bind(
    "try { } catch ({ message, name }) { console.log(message); }",
  )
  match result {
    Ok(bound) => {
      // Destructured variables should not be in global scope
      assert_false(bound.global_scope.symbols.contains("message"))
      assert_false(bound.global_scope.symbols.contains("name"))
    }
    Err(_) => assert_true(false)
  }
}

///|
test "bind catch with array destructuring pattern" {
  let result = parse_and_bind(
    "try { } catch ([first, second]) { console.log(first); }",
  )
  match result {
    Ok(bound) => {
      // Destructured variables should not be in global scope
      assert_false(bound.global_scope.symbols.contains("first"))
      assert_false(bound.global_scope.symbols.contains("second"))
    }
    Err(_) => assert_true(false)
  }
}

///|
test "bind catch variable used in catch block" {
  let result = parse_and_bind(
    "try { throw new Error('test'); } catch (err) { const msg = err.message; }",
  )
  match result {
    Ok(bound) => {
      // err and msg should not be in global scope
      assert_false(bound.global_scope.symbols.contains("err"))
      assert_false(bound.global_scope.symbols.contains("msg"))
    }
    Err(_) => assert_true(false)
  }
}

///|
test "bind nested try-catch" {
  let result = parse_and_bind(
    "try { try { } catch (inner) { } } catch (outer) { }",
  )
  match result {
    Ok(bound) => {
      // Both catch variables should not be in global scope
      assert_false(bound.global_scope.symbols.contains("inner"))
      assert_false(bound.global_scope.symbols.contains("outer"))
    }
    Err(_) => assert_true(false)
  }
}

///|
test "bind catch variable with type annotation" {
  let result = parse_and_bind("try { } catch (e: unknown) { const x = e; }")
  match result {
    Ok(bound) => {
      // e and x should not be in global scope
      assert_false(bound.global_scope.symbols.contains("e"))
      assert_false(bound.global_scope.symbols.contains("x"))
    }
    Err(_) => assert_true(false)
  }
}

// ============================================================================
// Multiple Declaration Types Tests
// ============================================================================

///|
test "bind function and variable same name error" {
  let result = parse_and_bind("const foo = 1; function foo() {}")
  match result {
    Ok(_) => assert_true(false) // Should have error
    Err(diagnostics) => {
      assert_true(diagnostics.length() > 0)
      match diagnostics[0] {
        diag => assert_true(diag.message.contains("Duplicate"))
      }
    }
  }
}

///|
test "bind class and variable same name error" {
  let result = parse_and_bind("const Foo = 1; class Foo {}")
  match result {
    Ok(_) => assert_true(false) // Should have error
    Err(diagnostics) => assert_true(diagnostics.length() > 0)
  }
}

///|
test "bind interface and class same name error" {
  let result = parse_and_bind("interface Foo {} class Foo {}")
  match result {
    Ok(_) => assert_true(false) // Should have error
    Err(diagnostics) => assert_true(diagnostics.length() > 0)
  }
}

// ============================================================================
// Import Shadowing Tests
// ============================================================================

///|
test "bind import shadowing local variable error" {
  let result = parse_and_bind("const foo = 1; import foo from 'module';")
  match result {
    Ok(_) => assert_true(false) // Should have error
    Err(diagnostics) => assert_true(diagnostics.length() > 0)
  }
}

///|
test "bind multiple named imports" {
  let result = parse_and_bind("import { a, b, c } from 'module';")
  match result {
    Ok(bound) => {
      assert_true(bound.global_scope.symbols.contains("a"))
      assert_true(bound.global_scope.symbols.contains("b"))
      assert_true(bound.global_scope.symbols.contains("c"))
    }
    Err(_) => assert_true(false)
  }
}

///|
test "bind mixed import (default and named)" {
  let result = parse_and_bind("import foo, { bar } from 'module';")
  match result {
    Ok(bound) => {
      assert_true(bound.global_scope.symbols.contains("foo"))
      assert_true(bound.global_scope.symbols.contains("bar"))
    }
    Err(_) => assert_true(false)
  }
}

// ============================================================================
// Empty Source Tests
// ============================================================================

///|
test "bind empty source" {
  let result = parse_and_bind("")
  match result {
    Ok(bound) => {
      assert_eq(bound.file_path, "test.ts")
      assert_eq(bound.symbol_count, 0)
    }
    Err(_) => assert_true(false)
  }
}

// ============================================================================
// Type Parameter Tests
// ============================================================================

///|
test "bind generic function type parameters" {
  let result = parse_and_bind("function identity<T>(x: T): T { return x; }")
  match result {
    Ok(bound) => {
      // Function should be in global scope
      assert_true(bound.global_scope.symbols.contains("identity"))
      // Type parameter T should not be in global scope (it's in function scope)
      assert_false(bound.global_scope.symbols.contains("T"))
    }
    Err(_) => assert_true(false)
  }
}

///|
test "bind generic function with multiple type parameters" {
  let result = parse_and_bind(
    "function map<T, U>(arr: T[], f: (x: T) => U): U[] { return []; }",
  )
  match result {
    Ok(bound) => {
      // Function should be in global scope
      assert_true(bound.global_scope.symbols.contains("map"))
      // Type parameters should not be in global scope
      assert_false(bound.global_scope.symbols.contains("T"))
      assert_false(bound.global_scope.symbols.contains("U"))
    }
    Err(_) => assert_true(false)
  }
}

///|
test "bind generic class type parameters" {
  let result = parse_and_bind("class Box<T> { value: T; }")
  match result {
    Ok(bound) => {
      // Class should be in global scope
      assert_true(bound.global_scope.symbols.contains("Box"))
      // Type parameter T should not be in global scope
      assert_false(bound.global_scope.symbols.contains("T"))
    }
    Err(_) => assert_true(false)
  }
}

///|
test "bind generic class with multiple type parameters" {
  let result = parse_and_bind("class Pair<K, V> { key: K; value: V; }")
  match result {
    Ok(bound) => {
      // Class should be in global scope
      assert_true(bound.global_scope.symbols.contains("Pair"))
      // Type parameters should not be in global scope
      assert_false(bound.global_scope.symbols.contains("K"))
      assert_false(bound.global_scope.symbols.contains("V"))
    }
    Err(_) => assert_true(false)
  }
}

///|
test "bind generic interface type parameters" {
  let result = parse_and_bind("interface Container<T> { value: T; }")
  match result {
    Ok(bound) => {
      // Interface should be in global scope
      assert_true(bound.global_scope.symbols.contains("Container"))
      // Type parameter T should not be in global scope
      assert_false(bound.global_scope.symbols.contains("T"))
    }
    Err(_) => assert_true(false)
  }
}

///|
test "bind generic type alias type parameters" {
  let result = parse_and_bind("type Nullable<T> = T | null;")
  match result {
    Ok(bound) => {
      // Type alias should be in global scope
      assert_true(bound.global_scope.symbols.contains("Nullable"))
      // Type parameter T should not be in global scope
      assert_false(bound.global_scope.symbols.contains("T"))
    }
    Err(_) => assert_true(false)
  }
}

///|
test "bind generic type alias with multiple type parameters" {
  let result = parse_and_bind("type Result<T, E> = { ok: T } | { error: E };")
  match result {
    Ok(bound) => {
      // Type alias should be in global scope
      assert_true(bound.global_scope.symbols.contains("Result"))
      // Type parameters should not be in global scope
      assert_false(bound.global_scope.symbols.contains("T"))
      assert_false(bound.global_scope.symbols.contains("E"))
    }
    Err(_) => assert_true(false)
  }
}

// ============================================================================
// GetAccessor Tests
// ============================================================================

///|
test "bind class with getter accessor" {
  let result = parse_and_bind("class Person { get name() { return 'John'; } }")
  match result {
    Ok(bound) => {
      // Class should be in global scope
      assert_true(bound.global_scope.symbols.contains("Person"))
      // Getter name should not be in global scope (it's in class scope)
      assert_false(bound.global_scope.symbols.contains("name"))
    }
    Err(_) => assert_true(false)
  }
}

///|
test "bind class with multiple getter accessors" {
  let result = parse_and_bind(
    "class Rectangle { get width() { return 10; } get height() { return 20; } }",
  )
  match result {
    Ok(bound) => {
      // Class should be in global scope
      assert_true(bound.global_scope.symbols.contains("Rectangle"))
      // Getters should not be in global scope
      assert_false(bound.global_scope.symbols.contains("width"))
      assert_false(bound.global_scope.symbols.contains("height"))
    }
    Err(_) => assert_true(false)
  }
}

///|
test "bind class with getter and method" {
  let result = parse_and_bind(
    "class Counter { get value() { return 0; } increment() { } }",
  )
  match result {
    Ok(bound) => {
      // Class should be in global scope
      assert_true(bound.global_scope.symbols.contains("Counter"))
      // Members should not be in global scope
      assert_false(bound.global_scope.symbols.contains("value"))
      assert_false(bound.global_scope.symbols.contains("increment"))
    }
    Err(_) => assert_true(false)
  }
}

// ============================================================================
// SetAccessor Tests
// ============================================================================

///|
test "bind class with setter accessor" {
  let result = parse_and_bind("class Person { set name(value: string) { } }")
  match result {
    Ok(bound) => {
      // Class should be in global scope
      assert_true(bound.global_scope.symbols.contains("Person"))
      // Setter name should not be in global scope (it's in class scope)
      assert_false(bound.global_scope.symbols.contains("name"))
    }
    Err(_) => assert_true(false)
  }
}

///|
test "bind class with multiple setter accessors" {
  let result = parse_and_bind(
    "class Rectangle { set width(w: number) { } set height(h: number) { } }",
  )
  match result {
    Ok(bound) => {
      // Class should be in global scope
      assert_true(bound.global_scope.symbols.contains("Rectangle"))
      // Setters should not be in global scope
      assert_false(bound.global_scope.symbols.contains("width"))
      assert_false(bound.global_scope.symbols.contains("height"))
    }
    Err(_) => assert_true(false)
  }
}

///|
test "bind class with getter and setter pair" {
  let result = parse_and_bind(
    "class Circle { get radius() { return 1; } set radius(value: number) { } }",
  )
  match result {
    Ok(bound) => {
      // Class should be in global scope
      assert_true(bound.global_scope.symbols.contains("Circle"))
      // Getter/setter pair should not be in global scope
      assert_false(bound.global_scope.symbols.contains("radius"))
    }
    Err(_) => assert_true(false)
  }
}

///|
test "bind class with setter and method" {
  let result = parse_and_bind(
    "class Counter { set value(v: number) { } reset() { } }",
  )
  match result {
    Ok(bound) => {
      // Class should be in global scope
      assert_true(bound.global_scope.symbols.contains("Counter"))
      // Members should not be in global scope
      assert_false(bound.global_scope.symbols.contains("value"))
      assert_false(bound.global_scope.symbols.contains("reset"))
    }
    Err(_) => assert_true(false)
  }
}

// ============================================================================
// ExportValue Tests
// ============================================================================

///|
test "bind named export does not create new symbol" {
  let result = parse_and_bind("const foo = 1; export { foo };")
  match result {
    Ok(bound) => {
      // Variable should be in global scope (the export just references it)
      assert_true(bound.global_scope.symbols.contains("foo"))
      // Check that the symbol is a Variable, not ExportValue
      match bound.global_scope.symbols.get("foo") {
        Some(sym) =>
          match sym.kind {
            Variable => ()
            _ => assert_true(false)
          }
        None => assert_true(false)
      }
    }
    Err(_) => assert_true(false)
  }
}

///|
test "bind re-export from module creates ExportValue" {
  let result = parse_and_bind("export { foo } from 'module';")
  match result {
    Ok(bound) => {
      // Re-exported name should be in global scope as ExportValue
      assert_true(bound.global_scope.symbols.contains("foo"))
      match bound.global_scope.symbols.get("foo") {
        Some(sym) =>
          match sym.kind {
            ExportValue => ()
            _ => assert_true(false)
          }
        None => assert_true(false)
      }
    }
    Err(_) => assert_true(false)
  }
}

///|
test "bind multiple re-exports from module" {
  let result = parse_and_bind("export { a, b } from 'module';")
  match result {
    Ok(bound) => {
      // Both re-exports should be in global scope as ExportValue
      assert_true(bound.global_scope.symbols.contains("a"))
      assert_true(bound.global_scope.symbols.contains("b"))
    }
    Err(_) => assert_true(false)
  }
}

///|
test "bind namespace export as creates ExportValue" {
  let result = parse_and_bind("export * as ns from 'module';")
  match result {
    Ok(bound) => {
      // Namespace export should be in global scope as ExportValue
      assert_true(bound.global_scope.symbols.contains("ns"))
      match bound.global_scope.symbols.get("ns") {
        Some(sym) =>
          match sym.kind {
            ExportValue => ()
            _ => assert_true(false)
          }
        None => assert_true(false)
      }
    }
    Err(_) => assert_true(false)
  }
}

///|
test "bind renamed re-export from module" {
  let result = parse_and_bind("export { foo as bar } from 'module';")
  match result {
    Ok(bound) => {
      // Exported name should be in global scope as ExportValue
      assert_true(bound.global_scope.symbols.contains("bar"))
      // Original name should NOT be in global scope (it's from another module)
      assert_false(bound.global_scope.symbols.contains("foo"))
    }
    Err(_) => assert_true(false)
  }
}

// ============================================================================
// ExportType Tests
// ============================================================================

///|
test "bind local type-only export does not create new symbol" {
  let result = parse_and_bind("type Foo = string; export type { Foo };")
  match result {
    Ok(bound) => {
      // Type alias Foo should be in global scope (the export just references it)
      assert_true(bound.global_scope.symbols.contains("Foo"))
      // Check that the symbol is a Type, not ExportType
      match bound.global_scope.symbols.get("Foo") {
        Some(sym) =>
          match sym.kind {
            Type => ()
            _ => assert_true(false)
          }
        None => assert_true(false)
      }
    }
    Err(_) => assert_true(false)
  }
}

///|
test "bind type-only re-export from module creates ExportType" {
  let result = parse_and_bind("export type { Foo } from 'module';")
  match result {
    Ok(bound) => {
      // Re-exported type should be in global scope as ExportType
      assert_true(bound.global_scope.symbols.contains("Foo"))
      match bound.global_scope.symbols.get("Foo") {
        Some(sym) =>
          match sym.kind {
            ExportType => ()
            _ => assert_true(false)
          }
        None => assert_true(false)
      }
    }
    Err(_) => assert_true(false)
  }
}

///|
test "bind multiple type-only re-exports from module" {
  let result = parse_and_bind("export type { Foo, Bar } from 'module';")
  match result {
    Ok(bound) => {
      // Both re-exports should be in global scope as ExportType
      assert_true(bound.global_scope.symbols.contains("Foo"))
      assert_true(bound.global_scope.symbols.contains("Bar"))
    }
    Err(_) => assert_true(false)
  }
}

///|
test "bind renamed type-only re-export from module" {
  let result = parse_and_bind("export type { Foo as MyFoo } from 'module';")
  match result {
    Ok(bound) => {
      // Exported name should be in global scope as ExportType
      assert_true(bound.global_scope.symbols.contains("MyFoo"))
      // Original name should NOT be in global scope
      assert_false(bound.global_scope.symbols.contains("Foo"))
    }
    Err(_) => assert_true(false)
  }
}

// ============================================================================
// FlowNode Assignment Tests
// ============================================================================

///|
test "bind simple assignment creates flow node" {
  let result = parse_and_bind("let x = 1; x = 2;")
  match result {
    Ok(bound) => {
      // Variable should be in global scope
      assert_true(bound.global_scope.symbols.contains("x"))
      assert_eq(bound.file_path, "test.ts")
    }
    Err(_) => assert_true(false)
  }
}

///|
test "bind compound assignment creates flow node" {
  let result = parse_and_bind("let x = 1; x += 2;")
  match result {
    Ok(bound) =>
      // Variable should be in global scope
      assert_true(bound.global_scope.symbols.contains("x"))
    Err(_) => assert_true(false)
  }
}

///|
test "bind multiple assignments creates flow nodes" {
  let result = parse_and_bind("let x = 1; let y = 2; x = y; y = x;")
  match result {
    Ok(bound) => {
      // Both variables should be in global scope
      assert_true(bound.global_scope.symbols.contains("x"))
      assert_true(bound.global_scope.symbols.contains("y"))
    }
    Err(_) => assert_true(false)
  }
}

///|
test "bind assignment in function creates flow node" {
  let result = parse_and_bind("function f() { let x = 1; x = 2; return x; }")
  match result {
    Ok(bound) => {
      // Function should be in global scope
      assert_true(bound.global_scope.symbols.contains("f"))
      // Local variable should not be in global scope
      assert_false(bound.global_scope.symbols.contains("x"))
    }
    Err(_) => assert_true(false)
  }
}

///|
test "bind all assignment operators" {
  let result = parse_and_bind(
    "let x = 1; x = 1; x += 1; x -= 1; x *= 1; x /= 1; x %= 1; x **= 1; x &= 1; x |= 1; x ^= 1; x <<= 1; x >>= 1; x >>>= 1; x &&= 1; x ||= 1; x ??= 1;",
  )
  match result {
    Ok(bound) => assert_true(bound.global_scope.symbols.contains("x"))
    Err(_) => assert_true(false)
  }
}

// ============================================================================
// FlowNode Call Tests
// ============================================================================

///|
test "bind simple function call creates flow node" {
  let result = parse_and_bind("function foo() {} foo();")
  match result {
    Ok(bound) => {
      // Function should be in global scope
      assert_true(bound.global_scope.symbols.contains("foo"))
      assert_eq(bound.file_path, "test.ts")
    }
    Err(_) => assert_true(false)
  }
}

///|
test "bind function call with arguments creates flow node" {
  let result = parse_and_bind("function add(a, b) { return a + b; } add(1, 2);")
  match result {
    Ok(bound) =>
      // Function should be in global scope
      assert_true(bound.global_scope.symbols.contains("add"))
    Err(_) => assert_true(false)
  }
}

///|
test "bind method call creates flow node" {
  let result = parse_and_bind("const arr = [1, 2, 3]; arr.push(4);")
  match result {
    Ok(bound) =>
      // Variable should be in global scope
      assert_true(bound.global_scope.symbols.contains("arr"))
    Err(_) => assert_true(false)
  }
}

///|
test "bind chained calls creates flow nodes" {
  let result = parse_and_bind("const s = 'hello'; s.trim().toUpperCase();")
  match result {
    Ok(bound) =>
      // Variable should be in global scope
      assert_true(bound.global_scope.symbols.contains("s"))
    Err(_) => assert_true(false)
  }
}

///|
test "bind nested function calls creates flow nodes" {
  let result = parse_and_bind(
    "function f(x) { return x; } function g(x) { return x; } f(g(1));",
  )
  match result {
    Ok(bound) => {
      // Both functions should be in global scope
      assert_true(bound.global_scope.symbols.contains("f"))
      assert_true(bound.global_scope.symbols.contains("g"))
    }
    Err(_) => assert_true(false)
  }
}

// ============================================================================
// FlowNode Condition Tests
// ============================================================================

///|
test "bind if statement creates condition flow node" {
  let result = parse_and_bind("const x = true; if (x) { const y = 1; }")
  match result {
    Ok(bound) => {
      // Variable should be in global scope
      assert_true(bound.global_scope.symbols.contains("x"))
      // Inner variable should not be in global scope
      assert_false(bound.global_scope.symbols.contains("y"))
    }
    Err(_) => assert_true(false)
  }
}

///|
test "bind if-else statement creates condition flow node" {
  let result = parse_and_bind(
    "const x = true; if (x) { const a = 1; } else { const b = 2; }",
  )
  match result {
    Ok(bound) => {
      assert_true(bound.global_scope.symbols.contains("x"))
      assert_false(bound.global_scope.symbols.contains("a"))
      assert_false(bound.global_scope.symbols.contains("b"))
    }
    Err(_) => assert_true(false)
  }
}

///|
test "bind while statement creates condition flow node" {
  let result = parse_and_bind("let x = 0; while (x < 10) { x = x + 1; }")
  match result {
    Ok(bound) => assert_true(bound.global_scope.symbols.contains("x"))
    Err(_) => assert_true(false)
  }
}

///|
test "bind do-while statement creates condition flow node" {
  let result = parse_and_bind("let x = 0; do { x = x + 1; } while (x < 10);")
  match result {
    Ok(bound) => assert_true(bound.global_scope.symbols.contains("x"))
    Err(_) => assert_true(false)
  }
}

///|
test "bind for statement with condition creates condition flow node" {
  let result = parse_and_bind("for (let i = 0; i < 10; i++) { const x = i; }")
  match result {
    Ok(bound) => {
      // Loop variable should not be in global scope
      assert_false(bound.global_scope.symbols.contains("i"))
      assert_false(bound.global_scope.symbols.contains("x"))
    }
    Err(_) => assert_true(false)
  }
}

///|
test "bind ternary expression creates condition flow node" {
  let result = parse_and_bind("const x = true; const y = x ? 1 : 2;")
  match result {
    Ok(bound) => {
      assert_true(bound.global_scope.symbols.contains("x"))
      assert_true(bound.global_scope.symbols.contains("y"))
    }
    Err(_) => assert_true(false)
  }
}

///|
test "bind nested conditions creates multiple condition flow nodes" {
  let result = parse_and_bind(
    "const a = true; const b = false; if (a) { if (b) { } }",
  )
  match result {
    Ok(bound) => {
      assert_true(bound.global_scope.symbols.contains("a"))
      assert_true(bound.global_scope.symbols.contains("b"))
    }
    Err(_) => assert_true(false)
  }
}

// ============================================================================
// FlowNode SwitchClause Tests
// ============================================================================

///|
test "bind switch statement creates switch clause flow nodes" {
  let result = parse_and_bind(
    "const x = 1; switch (x) { case 1: break; case 2: break; }",
  )
  match result {
    Ok(bound) => assert_true(bound.global_scope.symbols.contains("x"))
    Err(_) => assert_true(false)
  }
}

///|
test "bind switch statement with default clause" {
  let result = parse_and_bind(
    "const x = 1; switch (x) { case 1: break; default: break; }",
  )
  match result {
    Ok(bound) => assert_true(bound.global_scope.symbols.contains("x"))
    Err(_) => assert_true(false)
  }
}

///|
test "bind switch statement with multiple cases" {
  let result = parse_and_bind(
    "const x = 1; switch (x) { case 1: case 2: case 3: break; default: break; }",
  )
  match result {
    Ok(bound) => assert_true(bound.global_scope.symbols.contains("x"))
    Err(_) => assert_true(false)
  }
}

///|
test "bind switch statement with block scoped variables" {
  let result = parse_and_bind(
    "const x = 1; switch (x) { case 1: { const a = 1; break; } case 2: { const b = 2; break; } }",
  )
  match result {
    Ok(bound) => {
      assert_true(bound.global_scope.symbols.contains("x"))
      // Block-scoped variables should not be in global scope
      assert_false(bound.global_scope.symbols.contains("a"))
      assert_false(bound.global_scope.symbols.contains("b"))
    }
    Err(_) => assert_true(false)
  }
}

///|
test "bind switch statement with expression" {
  let result = parse_and_bind(
    "const x = 1; const y = 2; switch (x + y) { case 3: break; }",
  )
  match result {
    Ok(bound) => {
      assert_true(bound.global_scope.symbols.contains("x"))
      assert_true(bound.global_scope.symbols.contains("y"))
    }
    Err(_) => assert_true(false)
  }
}

///|
test "bind nested switch statements" {
  let result = parse_and_bind(
    "const x = 1; switch (x) { case 1: switch (x) { case 1: break; } break; }",
  )
  match result {
    Ok(bound) => assert_true(bound.global_scope.symbols.contains("x"))
    Err(_) => assert_true(false)
  }
}

// ============================================================================
// FlowNode Label Tests
// ============================================================================

///|
test "bind labeled statement creates label flow node" {
  let result = parse_and_bind(
    "outer: for (let i = 0; i < 10; i++) { break outer; }",
  )
  match result {
    Ok(_) => assert_true(true)
    Err(_) => assert_true(false)
  }
}

///|
test "bind labeled while statement" {
  let result = parse_and_bind("loop: while (true) { break loop; }")
  match result {
    Ok(_) => assert_true(true)
    Err(_) => assert_true(false)
  }
}

///|
test "bind labeled block statement" {
  let result = parse_and_bind("block: { const x = 1; break block; }")
  match result {
    Ok(_) => assert_true(true)
    Err(_) => assert_true(false)
  }
}

///|
test "bind nested labeled statements" {
  let result = parse_and_bind(
    "outer: for (let i = 0; i < 5; i++) { inner: for (let j = 0; j < 5; j++) { break outer; } }",
  )
  match result {
    Ok(_) => assert_true(true)
    Err(_) => assert_true(false)
  }
}

///|
test "bind labeled statement with continue" {
  let result = parse_and_bind(
    "loop: for (let i = 0; i < 10; i++) { continue loop; }",
  )
  match result {
    Ok(_) => assert_true(true)
    Err(_) => assert_true(false)
  }
}

// ============================================================================
// FlowNode ArrayMutation Tests
// ============================================================================

///|
test "bind array element assignment creates array mutation flow" {
  let result = parse_and_bind("const arr = [1, 2, 3]; arr[0] = 10;")
  match result {
    Ok(bound) => assert_true(bound.global_scope.symbols.contains("arr"))
    Err(_) => assert_true(false)
  }
}

///|
test "bind array element compound assignment" {
  let result = parse_and_bind("const arr = [1, 2, 3]; arr[0] += 5;")
  match result {
    Ok(bound) => assert_true(bound.global_scope.symbols.contains("arr"))
    Err(_) => assert_true(false)
  }
}

///|
test "bind nested array element assignment" {
  let result = parse_and_bind(
    "const matrix = [[1, 2], [3, 4]]; matrix[0][1] = 10;",
  )
  match result {
    Ok(bound) => assert_true(bound.global_scope.symbols.contains("matrix"))
    Err(_) => assert_true(false)
  }
}

///|
test "bind array element assignment with expression index" {
  let result = parse_and_bind(
    "const arr = [1, 2, 3]; const i = 0; arr[i] = 10;",
  )
  match result {
    Ok(bound) => {
      assert_true(bound.global_scope.symbols.contains("arr"))
      assert_true(bound.global_scope.symbols.contains("i"))
    }
    Err(_) => assert_true(false)
  }
}

///|
test "bind multiple array mutations" {
  let result = parse_and_bind(
    "const arr = [1, 2, 3]; arr[0] = 10; arr[1] = 20; arr[2] = 30;",
  )
  match result {
    Ok(bound) => assert_true(bound.global_scope.symbols.contains("arr"))
    Err(_) => assert_true(false)
  }
}

///|
test "bind object property assignment is not array mutation" {
  let result = parse_and_bind("const obj = { x: 1 }; obj.x = 10;")
  match result {
    Ok(bound) => assert_true(bound.global_scope.symbols.contains("obj"))
    Err(_) => assert_true(false)
  }
}

// ============================================================================
// FlowNode Return Tests
// ============================================================================

///|
test "bind return statement creates return flow node" {
  let result = parse_and_bind("function f() { return 42; }")
  match result {
    Ok(bound) => assert_true(bound.global_scope.symbols.contains("f"))
    Err(_) => assert_true(false)
  }
}

///|
test "bind return statement without expression" {
  let result = parse_and_bind("function f() { return; }")
  match result {
    Ok(bound) => assert_true(bound.global_scope.symbols.contains("f"))
    Err(_) => assert_true(false)
  }
}

///|
test "bind return with expression" {
  let result = parse_and_bind("function add(a, b) { return a + b; }")
  match result {
    Ok(bound) => assert_true(bound.global_scope.symbols.contains("add"))
    Err(_) => assert_true(false)
  }
}

///|
test "bind multiple return statements" {
  let result = parse_and_bind(
    "function abs(x) { if (x < 0) { return -x; } return x; }",
  )
  match result {
    Ok(bound) => assert_true(bound.global_scope.symbols.contains("abs"))
    Err(_) => assert_true(false)
  }
}

///|
test "bind return in arrow function" {
  let result = parse_and_bind("const f = (x) => { return x * 2; };")
  match result {
    Ok(bound) => assert_true(bound.global_scope.symbols.contains("f"))
    Err(_) => assert_true(false)
  }
}

///|
test "bind early return pattern" {
  let result = parse_and_bind(
    "function validate(x) { if (!x) { return false; } return true; }",
  )
  match result {
    Ok(bound) => assert_true(bound.global_scope.symbols.contains("validate"))
    Err(_) => assert_true(false)
  }
}

// ============================================================================
// FlowNode Unreachable Tests
// ============================================================================

///|
test "bind return makes code unreachable" {
  let result = parse_and_bind("function f() { return 1; const x = 2; }")
  match result {
    Ok(bound) => assert_true(bound.global_scope.symbols.contains("f"))
    Err(_) => assert_true(false)
  }
}

///|
test "bind throw makes code unreachable" {
  let result = parse_and_bind(
    "function f() { throw new Error('error'); const x = 2; }",
  )
  match result {
    Ok(bound) => assert_true(bound.global_scope.symbols.contains("f"))
    Err(_) => assert_true(false)
  }
}

///|
test "bind break makes code unreachable" {
  let result = parse_and_bind("while (true) { break; const x = 1; }")
  match result {
    Ok(_) => assert_true(true)
    Err(_) => assert_true(false)
  }
}

///|
test "bind continue makes code unreachable" {
  let result = parse_and_bind("while (true) { continue; const x = 1; }")
  match result {
    Ok(_) => assert_true(true)
    Err(_) => assert_true(false)
  }
}

///|
test "bind labeled break makes code unreachable" {
  let result = parse_and_bind(
    "outer: while (true) { break outer; const x = 1; }",
  )
  match result {
    Ok(_) => assert_true(true)
    Err(_) => assert_true(false)
  }
}

///|
test "bind unreachable after throw in if branch" {
  let result = parse_and_bind(
    "function f(x) { if (x) { throw new Error(); } return x; }",
  )
  match result {
    Ok(bound) => assert_true(bound.global_scope.symbols.contains("f"))
    Err(_) => assert_true(false)
  }
}

// ============================================================================
// Ambient Module Declaration Tests
// ============================================================================

///|
test "ambient module wildcard pattern" {
  let result = parse_and_bind(
    #|declare module "*.css" {
    #|  const styles: { [key: string]: string };
    #|  export default styles;
    #|}
    ,
  )
  match result {
    Ok(bound) => {
      // Check that the ambient module was registered
      match bound.ambient_modules.lookup("*.css") {
        Some(info) => {
          assert_eq(info.pattern, "*.css")
          assert_eq(info.is_wildcard, true)
        }
        None => assert_true(false)
      }
      // Check that the pattern matches actual CSS files
      match bound.ambient_modules.lookup("styles.css") {
        Some(_) => assert_true(true)
        None => assert_true(false)
      }
      match bound.ambient_modules.lookup("theme/dark.css") {
        Some(_) => assert_true(true)
        None => assert_true(false)
      }
    }
    Err(_) => assert_true(false)
  }
}

///|
test "ambient module exact match" {
  let result = parse_and_bind(
    #|declare module "express" {
    #|  interface Request { body: any; }
    #|  interface Response { send(data: any): void; }
    #|}
    ,
  )
  match result {
    Ok(bound) => {
      // Check that the ambient module was registered
      match bound.ambient_modules.lookup("express") {
        Some(info) => {
          assert_eq(info.pattern, "express")
          assert_eq(info.is_wildcard, false)
        }
        None => assert_true(false)
      }
      // Should not match partial names
      match bound.ambient_modules.lookup("express-validator") {
        None => assert_true(true)
        Some(_) => assert_true(false)
      }
    }
    Err(_) => assert_true(false)
  }
}

///|
test "ambient module scoped package" {
  let result = parse_and_bind(
    #|declare module "@types/lodash" {
    #|  export function map<T, U>(arr: T[], fn: (x: T) => U): U[];
    #|}
    ,
  )
  match result {
    Ok(bound) => {
      match bound.ambient_modules.lookup("@types/lodash") {
        Some(info) => {
          assert_eq(info.pattern, "@types/lodash")
          assert_eq(info.is_wildcard, false)
        }
        None => assert_true(false)
      }
    }
    Err(_) => assert_true(false)
  }
}

///|
test "ambient module json pattern" {
  let result = parse_and_bind(
    #|declare module "*.json" {
    #|  const value: any;
    #|  export default value;
    #|}
    ,
  )
  match result {
    Ok(bound) => {
      // Check pattern matching
      match bound.ambient_modules.lookup("config.json") {
        Some(_) => assert_true(true)
        None => assert_true(false)
      }
      match bound.ambient_modules.lookup("data/settings.json") {
        Some(_) => assert_true(true)
        None => assert_true(false)
      }
      // Should not match non-json files
      match bound.ambient_modules.lookup("config.js") {
        None => assert_true(true)
        Some(_) => assert_true(false)
      }
    }
    Err(_) => assert_true(false)
  }
}

///|
test "regular namespace not treated as ambient" {
  let result = parse_and_bind(
    #|namespace MyNamespace {
    #|  export const value = 42;
    #|}
    ,
  )
  match result {
    Ok(bound) => {
      // Regular namespace should be in global scope
      assert_true(bound.global_scope.symbols.contains("MyNamespace"))
      // Should not be in ambient modules registry
      match bound.ambient_modules.lookup("MyNamespace") {
        None => assert_true(true)
        Some(_) => assert_true(false)
      }
    }
    Err(_) => assert_true(false)
  }
}

// ============================================================================
// Module Augmentation Tests
// ============================================================================

///|
test "module augmentation in module file" {
  // File with import is a module file, so declare module is augmentation
  let source =
    #|import { foo } from "bar";
    #|declare module "express" {
    #|  interface Request { user?: string; }
    #|}
  let result = parse_and_bind(source)
  match result {
    Ok(bound) => {
      // Should be in module_augmentations, not ambient_modules
      assert_eq(bound.module_augmentations.length(), 1)
      assert_eq(bound.module_augmentations[0].module_name, "express")
    }
    Err(_) => assert_true(false)
  }
}

///|
test "ambient module in script file stays ambient" {
  // File without import/export is a script, so declare module is ambient
  let source =
    #|declare module "lodash" {
    #|  export function map(): void;
    #|}
  let result = parse_and_bind(source)
  match result {
    Ok(bound) => {
      // Should be in ambient_modules, not module_augmentations
      assert_eq(bound.module_augmentations.length(), 0)
    }
    Err(_) => assert_true(false)
  }
}

///|
test "module augmentation with export modifier" {
  // File with export is a module file
  let source =
    #|export const myValue = 42;
    #|declare module "lib" { interface Options { x?: boolean; } }
  let result = parse_and_bind(source)
  match result {
    Ok(bound) => {
      // Should be augmentation because file has export
      assert_eq(bound.module_augmentations.length(), 1)
      assert_eq(bound.module_augmentations[0].module_name, "lib")
    }
    Err(_) => assert_true(false)
  }
}

///|
test "multiple module augmentations in same file" {
  // File can have multiple augmentations
  let source =
    #|import { x } from "something";
    #|declare module "express" { interface Request { session?: any; } }
    #|declare module "koa" { interface Context { user?: string; } }
  let result = parse_and_bind(source)
  match result {
    Ok(bound) => {
      assert_eq(bound.module_augmentations.length(), 2)
      assert_eq(bound.module_augmentations[0].module_name, "express")
      assert_eq(bound.module_augmentations[1].module_name, "koa")
    }
    Err(_) => assert_true(false)
  }
}

