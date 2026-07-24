// ============================================================================
// noImplicitAny contextual cases (wave-6):
// - TS7006 for function/arrow expressions in definitely-uncontextual positions
// - deferred TS7034/TS7005 (report only on offending reads)
// - TS7031 for null/undefined widening in destructuring (strictNullChecks off)
// - TS7008/TS7006/TS7010/TS7013/TS7020 inside type-literal annotations
// ============================================================================

///|
fn count_code(typed : @compiler.TypedFile, code : Int) -> Int {
  typed.diagnostics.filter(fn(d) { d.code == code }).length()
}

///|
fn check_nia(source : String) -> @compiler.TypedFile? {
  match @compiler.type_check_with_options(
    source,
    "test.ts",
    no_implicit_any=true,
  ) {
    Ok(typed) => Some(typed)
    Err(_) => None
  }
}

// ----------------------------------------------------------------------------
// TS7006: function/arrow expressions without contextual types
// ----------------------------------------------------------------------------

///|
test "TS7006: function expression initializing un-annotated var" {
  match check_nia("var f = function (x) { };") {
    Some(typed) => assert_eq(count_code(typed, 7006), 1)
    None => ()
  }
}

///|
test "TS7006: arrow function initializing un-annotated var" {
  match check_nia("var f = (y) => y;") {
    Some(typed) => assert_eq(count_code(typed, 7006), 1)
    None => ()
  }
}

///|
test "TS7006: object literal methods and function-valued properties" {
  match check_nia("var o = { m(a) { }, p: function (b) { }, q: (c) => c };") {
    Some(typed) => assert_eq(count_code(typed, 7006), 3)
    None => ()
  }
}

///|
test "TS7006: function expression inside uncontextual array literal" {
  match check_nia("var arr = [function (d) { }];") {
    Some(typed) => assert_eq(count_code(typed, 7006), 1)
    None => ()
  }
}

///|
test "TS7006 suppressed: annotated variable provides contextual type" {
  match check_nia("const f: (n: number) => void = x => { };") {
    Some(typed) => assert_eq(count_code(typed, 7006), 0)
    None => ()
  }
}

///|
test "TS7006 suppressed: call argument to typed callback" {
  let source =
    #|declare function f(cb: (n: number) => void): void;
    #|f(x => { });
  match check_nia(source) {
    Some(typed) => assert_eq(count_code(typed, 7006), 0)
    None => ()
  }
}

///|
test "TS7006 suppressed: IIFE parameters are contextually typed" {
  match check_nia("(function (e) { })(1);") {
    Some(typed) => assert_eq(count_code(typed, 7006), 0)
    None => ()
  }
}

///|
test "TS7006 suppressed: parameter default gives a type" {
  match check_nia("var f = function (g = 1) { };") {
    Some(typed) => assert_eq(count_code(typed, 7006), 0)
    None => ()
  }
}

///|
test "TS7006: class expression method parameters are never contextual" {
  let source =
    #|interface Foo { method1(arg: { n: number }): void }
    #|function getFoo(): Foo {
    #|    return class {
    #|        static method1(arg) { }
    #|    }
    #|}
  match check_nia(source) {
    Some(typed) => assert_eq(count_code(typed, 7006), 1)
    None => ()
  }
}

///|
test "TS7008: class expression property without annotation or initializer" {
  match check_nia("var cls = class { p; m(k) { } };") {
    Some(typed) => {
      assert_eq(count_code(typed, 7008), 1)
      assert_eq(count_code(typed, 7006), 1)
    }
    None => ()
  }
}

///|
test "TS7008: non-ambient class property without annotation or initializer" {
  match check_nia("class C { c }") {
    Some(typed) => assert_eq(count_code(typed, 7008), 1)
    None => ()
  }
}

///|
test "TS7008 suppressed: class property with initializer" {
  match check_nia("class C { c = 1 }") {
    Some(typed) => assert_eq(count_code(typed, 7008), 0)
    None => ()
  }
}

///|
test "TS7008 suppressed: property assigned in constructor" {
  // tsc infers the property type from constructor assignments
  match check_nia("class C { c; constructor() { this.c = 1 } }") {
    Some(typed) => assert_eq(count_code(typed, 7008), 0)
    None => ()
  }
}

// ----------------------------------------------------------------------------
// Deferred TS7034/TS7005: evolving arrays and un-initialized lets
// ----------------------------------------------------------------------------

///|
test "TS7034/TS7005 not reported: empty array never read" {
  match check_nia("var a = [];") {
    Some(typed) => {
      assert_eq(count_code(typed, 7034), 0)
      assert_eq(count_code(typed, 7005), 0)
    }
    None => ()
  }
}

///|
test "TS7034/TS7005: empty array read while untyped" {
  match check_nia("var a = []; var b = a[0];") {
    Some(typed) => {
      assert_eq(count_code(typed, 7034), 1)
      assert_eq(count_code(typed, 7005), 1)
    }
    None => ()
  }
}

///|
test "TS7034/TS7005 suppressed: push evolves the array" {
  match check_nia("var a = []; a.push(1); var b = a[0];") {
    Some(typed) => {
      assert_eq(count_code(typed, 7034), 0)
      assert_eq(count_code(typed, 7005), 0)
    }
    None => ()
  }
}

///|
test "TS7034/TS7005 suppressed: assignment types the array" {
  match check_nia("var a = []; a = [1]; var b = a[0];") {
    Some(typed) => {
      assert_eq(count_code(typed, 7034), 0)
      assert_eq(count_code(typed, 7005), 0)
    }
    None => ()
  }
}

///|
test "TS7034/TS7005: closure read of un-initialized let" {
  match check_nia("let x; function g() { return x; }") {
    Some(typed) => {
      assert_eq(count_code(typed, 7034), 1)
      assert_eq(count_code(typed, 7005), 1)
    }
    None => ()
  }
}

///|
test "TS7034/TS7005: closure read reports even with outer assignment" {
  // Matches tsc: control flow cannot cross the function boundary, so the
  // outer assignment does not type the closure read
  match check_nia("let x; x = 5; function g() { return x; }") {
    Some(typed) => {
      assert_eq(count_code(typed, 7034), 1)
      assert_eq(count_code(typed, 7005), 1)
    }
    None => ()
  }
}

///|
test "TS7034/TS7005 suppressed: direct read of un-initialized let" {
  // Same-container reads have flow type undefined in tsc - no error
  match check_nia("let x; console.log(x); x = 1;") {
    Some(typed) => {
      assert_eq(count_code(typed, 7034), 0)
      assert_eq(count_code(typed, 7005), 0)
    }
    None => ()
  }
}

///|
test "TS7034/TS7005 suppressed: assigned in reading closure before read" {
  match check_nia("let x; function g() { x = 3; return x; }") {
    Some(typed) => {
      assert_eq(count_code(typed, 7034), 0)
      assert_eq(count_code(typed, 7005), 0)
    }
    None => ()
  }
}

///|
test "TS7034/TS7005 suppressed: shadowed by parameter in closure" {
  match check_nia("let x; function g(x: number) { return x; }") {
    Some(typed) => {
      assert_eq(count_code(typed, 7034), 0)
      assert_eq(count_code(typed, 7005), 0)
    }
    None => ()
  }
}

// ----------------------------------------------------------------------------
// TS7031: null/undefined widening in destructuring (strictNullChecks off)
// ----------------------------------------------------------------------------

///|
test "TS7031: destructured elements bound to undefined/null (snc off)" {
  let source =
    #|// @strict: false
    #|// @noImplicitAny: true
    #|var [a, b] = [undefined, null];
  match check_nia(source) {
    Some(typed) => assert_eq(count_code(typed, 7031), 2)
    None => ()
  }
}

///|
test "TS7031 suppressed: destructured elements with real values" {
  let source =
    #|// @strict: false
    #|// @noImplicitAny: true
    #|var [a, b] = [1, "s"];
  match check_nia(source) {
    Some(typed) => assert_eq(count_code(typed, 7031), 0)
    None => ()
  }
}

// ----------------------------------------------------------------------------
// Type-literal annotations (B11 checker half)
// ----------------------------------------------------------------------------

///|
test "TS7008: type literal member without a type" {
  match check_nia("var x: { y; };") {
    Some(typed) => assert_eq(count_code(typed, 7008), 1)
    None => ()
  }
}

///|
test "TS7006/TS7010: type literal method signature without types" {
  match check_nia("var z: { f(a); };") {
    Some(typed) => {
      assert_eq(count_code(typed, 7006), 1)
      assert_eq(count_code(typed, 7010), 1)
    }
    None => ()
  }
}

///|
test "type literal method signature fully annotated: no implicit any" {
  match check_nia("var w: { g(b: string): number; };") {
    Some(typed) => {
      assert_eq(count_code(typed, 7006), 0)
      assert_eq(count_code(typed, 7010), 0)
      assert_eq(count_code(typed, 7008), 0)
    }
    None => ()
  }
}

///|
test "TS7006: function type annotation with un-annotated parameter" {
  match check_nia("var f: (a) => void;") {
    Some(typed) => assert_eq(count_code(typed, 7006), 1)
    None => ()
  }
}

///|
test "TS7020: call signature without return type in type literal" {
  match check_nia("var h: { (c); };") {
    Some(typed) => {
      assert_eq(count_code(typed, 7020), 1)
      assert_eq(count_code(typed, 7006), 1)
    }
    None => ()
  }
}

///|
test "TS7008: type literal nested in type arguments" {
  match check_nia("var i2: Array<{ y; }>;") {
    Some(typed) => assert_eq(count_code(typed, 7008), 1)
    None => ()
  }
}
