// Class Member Parsing Tests
// Tests for various class member parsing features:
// 1. Computed property names in methods/getters/setters
// 2. extends null parsing
// 3. Parenthesized expression in extends clause
// 4. Reserved words as method/property names
// 5. Numeric literals as method/property names
// 6. String literals as method/property names

///|
/// Helper function to parse, bind, and check source code
fn parse_bind_check(source : String) -> @compiler.CheckResult {
  let tokens = @compiler.scan_all_v2(source, "test.ts")
  match @compiler.parse_source_file(tokens, "test.ts") {
    Ok(source_file) =>
      match @compiler.bind_source_file(source_file) {
        Ok(bound) => @compiler.check_source_file(bound)
        Err(diagnostics) => Err(diagnostics)
      }
    Err(diagnostics) => Err(diagnostics)
  }
}

///|
/// Helper to parse only and check for errors
fn parse_only(
  source : String,
) -> Result[@compiler.SourceFile, Array[@compiler.Diagnostic]] {
  let tokens = @compiler.scan_all_v2(source, "test.ts")
  @compiler.parse_source_file(tokens, "test.ts")
}

// ============================================================================
// Computed Property Names in Class Methods/Getters/Setters
// ============================================================================

///|
test "unit/parser/class-members/computed - computed method name with string literal" {
  let source =
    #|class Foo {
    #|  ["computedMethod"]() { return 42; }
    #|}
  match parse_only(source) {
    Ok(_) => assert_true(true)
    Err(diagnostics) => {
      println("Errors: \{diagnostics}")
      assert_true(false)
    }
  }
}

///|
test "unit/parser/class-members/computed - computed getter with string literal" {
  let source =
    #|class Foo {
    #|  get ["computedGetter"]() { return this._value; }
    #|}
  match parse_only(source) {
    Ok(_) => assert_true(true)
    Err(diagnostics) => {
      println("Errors: \{diagnostics}")
      assert_true(false)
    }
  }
}

///|
test "unit/parser/class-members/computed - computed setter with string literal" {
  let source =
    #|class Foo {
    #|  set ["computedSetter"](val: number) { this._value = val; }
    #|}
  match parse_only(source) {
    Ok(_) => assert_true(true)
    Err(diagnostics) => {
      println("Errors: \{diagnostics}")
      assert_true(false)
    }
  }
}

///|
test "unit/parser/class-members/computed - static computed method" {
  let source =
    #|class Foo {
    #|  static ["staticComputed"]() { return "static"; }
    #|}
  match parse_only(source) {
    Ok(_) => assert_true(true)
    Err(diagnostics) => {
      println("Errors: \{diagnostics}")
      assert_true(false)
    }
  }
}

///|
test "unit/parser/class-members/computed - computed property with expression" {
  let source =
    #|const key = "myKey";
    #|class Foo {
    #|  [key]: string = "value";
    #|}
  match parse_only(source) {
    Ok(_) => assert_true(true)
    Err(diagnostics) => {
      println("Errors: \{diagnostics}")
      assert_true(false)
    }
  }
}

// ============================================================================
// extends null Parsing
// ============================================================================

///|
test "unit/parser/class-members/extends-null - class extends null" {
  let source =
    #|class NullProto extends null {
    #|  constructor() {
    #|    return Object.create(null);
    #|  }
    #|}
  match parse_only(source) {
    Ok(_) => assert_true(true)
    Err(diagnostics) => {
      println("Errors: \{diagnostics}")
      assert_true(false)
    }
  }
}

///|
test "unit/parser/class-members/extends-null - class extends null with properties" {
  let source =
    #|class Dict extends null {
    #|  key: string;
    #|  value: number;
    #|}
  match parse_only(source) {
    Ok(_) => assert_true(true)
    Err(diagnostics) => {
      println("Errors: \{diagnostics}")
      assert_true(false)
    }
  }
}

// ============================================================================
// Parenthesized Expression in extends Clause
// ============================================================================

///|
test "unit/parser/class-members/extends-paren - parenthesized function call in extends" {
  let source =
    #|function getBase() { return class {}; }
    #|class Derived extends (getBase()) {
    #|}
  match parse_only(source) {
    Ok(_) => assert_true(true)
    Err(diagnostics) => {
      println("Errors: \{diagnostics}")
      assert_true(false)
    }
  }
}

///|
test "unit/parser/class-members/extends-paren - property access on parenthesized expression" {
  let source =
    #|const obj = { Base: class {} };
    #|class Derived extends (obj).Base {
    #|}
  match parse_only(source) {
    Ok(_) => assert_true(true)
    Err(diagnostics) => {
      println("Errors: \{diagnostics}")
      assert_true(false)
    }
  }
}

// ============================================================================
// Reserved Words as Method/Property Names
// ============================================================================

///|
test "unit/parser/class-members/reserved-word - interface as method name" {
  let source =
    #|class Foo {
    #|  interface() { return "interface method"; }
    #|}
  match parse_only(source) {
    Ok(_) => assert_true(true)
    Err(diagnostics) => {
      println("Errors: \{diagnostics}")
      assert_true(false)
    }
  }
}

///|
test "unit/parser/class-members/reserved-word - interface as property name" {
  let source =
    #|class Foo {
    #|  interface: string = "interface property";
    #|}
  match parse_only(source) {
    Ok(_) => assert_true(true)
    Err(diagnostics) => {
      println("Errors: \{diagnostics}")
      assert_true(false)
    }
  }
}

// ============================================================================
// Numeric Literals as Method/Property Names
// ============================================================================

///|
test "unit/parser/class-members/numeric-literal - decimal number as method name" {
  let source =
    #|class Foo {
    #|  11() { return "method 11"; }
    #|}
  match parse_only(source) {
    Ok(_) => assert_true(true)
    Err(diagnostics) => {
      println("Errors: \{diagnostics}")
      assert_true(false)
    }
  }
}

///|
test "unit/parser/class-members/numeric-literal - binary literal as method name" {
  let source =
    #|class Foo {
    #|  0b1110() { return "binary method"; }
    #|}
  match parse_only(source) {
    Ok(_) => assert_true(true)
    Err(diagnostics) => {
      println("Errors: \{diagnostics}")
      assert_true(false)
    }
  }
}

///|
test "unit/parser/class-members/numeric-literal - octal literal as property" {
  let source =
    #|class Foo {
    #|  0o23534 = "octal property";
    #|}
  match parse_only(source) {
    Ok(_) => assert_true(true)
    Err(diagnostics) => {
      println("Errors: \{diagnostics}")
      assert_true(false)
    }
  }
}

///|
test "unit/parser/class-members/numeric-literal - hex literal as method name" {
  let source =
    #|class Foo {
    #|  0xFF() { return 255; }
    #|}
  match parse_only(source) {
    Ok(_) => assert_true(true)
    Err(diagnostics) => {
      println("Errors: \{diagnostics}")
      assert_true(false)
    }
  }
}

///|
test "unit/parser/class-members/numeric-literal - static numeric method" {
  let source =
    #|class Foo {
    #|  static 22() { return "static 22"; }
    #|}
  match parse_only(source) {
    Ok(_) => assert_true(true)
    Err(diagnostics) => {
      println("Errors: \{diagnostics}")
      assert_true(false)
    }
  }
}

///|
test "unit/parser/class-members/numeric-literal - static numeric property" {
  let source =
    #|class Foo {
    #|  static 42 = "forty-two";
    #|}
  match parse_only(source) {
    Ok(_) => assert_true(true)
    Err(diagnostics) => {
      println("Errors: \{diagnostics}")
      assert_true(false)
    }
  }
}

// ============================================================================
// String Literals as Method/Property Names
// ============================================================================

///|
test "unit/parser/class-members/string-literal - string as method name" {
  let source =
    #|class Foo {
    #|  "foo"() { return "method foo"; }
    #|}
  match parse_only(source) {
    Ok(_) => assert_true(true)
    Err(diagnostics) => {
      println("Errors: \{diagnostics}")
      assert_true(false)
    }
  }
}

///|
test "unit/parser/class-members/string-literal - string as property name" {
  let source =
    #|class Foo {
    #|  "hello" = 10;
    #|}
  match parse_only(source) {
    Ok(_) => assert_true(true)
    Err(diagnostics) => {
      println("Errors: \{diagnostics}")
      assert_true(false)
    }
  }
}

///|
test "unit/parser/class-members/string-literal - static string method" {
  let source =
    #|class Foo {
    #|  static "staticMethod"() { return "static"; }
    #|}
  match parse_only(source) {
    Ok(_) => assert_true(true)
    Err(diagnostics) => {
      println("Errors: \{diagnostics}")
      assert_true(false)
    }
  }
}

///|
test "unit/parser/class-members/string-literal - static string property" {
  let source =
    #|class Foo {
    #|  static "hi" = 10000;
    #|}
  match parse_only(source) {
    Ok(_) => assert_true(true)
    Err(diagnostics) => {
      println("Errors: \{diagnostics}")
      assert_true(false)
    }
  }
}

// ============================================================================
// Combined/Complex Cases
// ============================================================================

///|
test "unit/parser/class-members/combined - all literal property types together" {
  let source =
    #|class B {
    #|  "hello" = 10;
    #|  0b110 = "world";
    #|  0o23534 = "WORLD";
    #|  20 = "twenty";
    #|  "foo"() { }
    #|  0b1110() {}
    #|  11() { }
    #|  interface() { }
    #|}
  match parse_only(source) {
    Ok(_) => assert_true(true)
    Err(diagnostics) => {
      println("Errors: \{diagnostics}")
      assert_true(false)
    }
  }
}

///|
test "unit/parser/class-members/combined - static literal properties and methods" {
  let source =
    #|class B {
    #|  static "hi" = 10000;
    #|  static 22 = "twenty-two";
    #|  static 0b101 = "binary";
    #|  static 0o3235 = "octal";
    #|}
  match parse_only(source) {
    Ok(_) => assert_true(true)
    Err(diagnostics) => {
      println("Errors: \{diagnostics}")
      assert_true(false)
    }
  }
}

///|
test "unit/parser/class-members/combined - computed getters and setters" {
  let source =
    #|class C {
    #|  ["prop"]: number;
    #|  ["this is a method"]() { }
    #|  get ["this is a getter"]() { return 0; }
    #|  set ["this is a setter"](v: number) { }
    #|  static ["a static method"]() { }
    #|  static get ["a static getter"]() { return 0; }
    #|  static set ["a static setter"](v: number) { }
    #|}
  match parse_only(source) {
    Ok(_) => assert_true(true)
    Err(diagnostics) => {
      println("Errors: \{diagnostics}")
      assert_true(false)
    }
  }
}

// ============================================================================
// Static Getter/Setter Tests
// ============================================================================

///|
test "unit/parser/class-members/static-getter - multiple static getters" {
  let source =
    #|class C {
    #|  static get name1(): string {
    #|    return "BYE";
    #|  }
    #|  static get name2(): string {
    #|    return "HELLO";
    #|  }
    #|}
  match parse_only(source) {
    Ok(_) => assert_true(true)
    Err(diagnostics) => {
      println("Errors: \{diagnostics}")
      assert_true(false)
    }
  }
}

///|
test "unit/parser/class-members/static-setter - multiple static setters" {
  let source =
    #|class C {
    #|  static set name1(v: string) { }
    #|  static set name2(v: number) { }
    #|}
  match parse_only(source) {
    Ok(_) => assert_true(true)
    Err(diagnostics) => {
      println("Errors: \{diagnostics}")
      assert_true(false)
    }
  }
}

///|
test "unit/parser/class-members/static-accessor - mixed static getters and setters" {
  let source =
    #|class C {
    #|  _name: string;
    #|  get name(): string {
    #|    return this._name;
    #|  }
    #|  static get name2(): string {
    #|    return "BYE";
    #|  }
    #|  static get ["computedname"]() {
    #|    return "";
    #|  }
    #|  get ["computedname1"]() {
    #|    return "";
    #|  }
    #|  set foo(a: string) { }
    #|  static set bar(b: number) { }
    #|  static set ["computedname2"](b: string) { }
    #|}
  match parse_only(source) {
    Ok(_) => assert_true(true)
    Err(diagnostics) => {
      println("Errors: \{diagnostics}")
      assert_true(false)
    }
  }
}

///|
test "unit/parser/class-members/static-accessor - static computed getter and setter" {
  let source =
    #|class C {
    #|  static get ["computed1"]() { return 1; }
    #|  static get ["computed2"]() { return 2; }
    #|  static set ["computed3"](v: any) { }
    #|  static set ["computed4"](v: string) { }
    #|}
  match parse_only(source) {
    Ok(_) => assert_true(true)
    Err(diagnostics) => {
      println("Errors: \{diagnostics}")
      assert_true(false)
    }
  }
}
