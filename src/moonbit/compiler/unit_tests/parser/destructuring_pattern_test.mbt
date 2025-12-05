// Destructuring Pattern Tests
// Tests for various destructuring patterns:
// - Rest with nested binding patterns [...[a, b]]
// - Numeric properties in object binding {1: x}
// - String properties in object binding {"prop": x}
// - Computed properties in object binding {[expr]: x}
// - Default values in nested patterns [{x} = {x: 0}]

///|
/// Helper function to parse, bind, and check source code
fn destructuring_parse_bind_check(source : String) -> @compiler.CheckResult {
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

// ============================================================================
// Rest Element with Nested Binding Pattern Tests
// ============================================================================

///|
test "unit/parser/destructuring - rest with nested array binding [...[a, b]]" {
  let source = "var [...[a, b]] = [0, 1];"
  let result = destructuring_parse_bind_check(source)
  match result {
    Ok(_) => assert_true(true)
    Err(diagnostics) => {
      // Should parse and check successfully
      assert_true(false, msg="Expected success but got errors: " + diagnostics.length().to_string())
    }
  }
}

///|
test "unit/parser/destructuring - rest with nested object binding [...{x, y}]" {
  let source = "var [...{x, y}] = [{x: 1, y: 2}];"
  let result = destructuring_parse_bind_check(source)
  match result {
    Ok(_) => assert_true(true)
    Err(diagnostics) => {
      assert_true(false, msg="Expected success but got errors: " + diagnostics.length().to_string())
    }
  }
}

// ============================================================================
// Numeric Property in Object Binding Tests
// ============================================================================

///|
test "unit/parser/destructuring - numeric property in object binding {1: x}" {
  let source = "var {1: b3} = { 1: \"string\" };"
  let result = destructuring_parse_bind_check(source)
  match result {
    Ok(_) => assert_true(true)
    Err(diagnostics) => {
      assert_true(false, msg="Expected success but got errors: " + diagnostics.length().to_string())
    }
  }
}

///|
test "unit/parser/destructuring - numeric property with nested pattern {0: [a, b]}" {
  let source = "var {0: [a, b]} = { 0: [1, 2] };"
  let result = destructuring_parse_bind_check(source)
  match result {
    Ok(_) => assert_true(true)
    Err(diagnostics) => {
      assert_true(false, msg="Expected success but got errors: " + diagnostics.length().to_string())
    }
  }
}

// ============================================================================
// String Property in Object Binding Tests
// ============================================================================

///|
test "unit/parser/destructuring - string property in object binding {\"prop\": x}" {
  let source = "var {\"prop\": x} = { prop: 1 };"
  let result = destructuring_parse_bind_check(source)
  match result {
    Ok(_) => assert_true(true)
    Err(diagnostics) => {
      assert_true(false, msg="Expected success but got errors: " + diagnostics.length().to_string())
    }
  }
}

// ============================================================================
// Computed Property in Object Binding Tests
// ============================================================================

///|
test "unit/parser/destructuring - computed property in object binding {[\"prop\"]: x}" {
  let source = "let { [\"prop\"]: x } = { prop: 1 };"
  let result = destructuring_parse_bind_check(source)
  match result {
    Ok(_) => assert_true(true)
    Err(diagnostics) => {
      assert_true(false, msg="Expected success but got errors: " + diagnostics.length().to_string())
    }
  }
}

///|
test "unit/parser/destructuring - computed property with number {[1]: x}" {
  let source = "let [{ [1]: x }] = [{ 1: \"test\" }];"
  let result = destructuring_parse_bind_check(source)
  match result {
    Ok(_) => assert_true(true)
    Err(diagnostics) => {
      assert_true(false, msg="Expected success but got errors: " + diagnostics.length().to_string())
    }
  }
}

///|
test "unit/parser/destructuring - computed property with function call {[fn()]: x}" {
  let source =
    #|function order(n: number): string { return String(n); }
    #|let [{ [order(1)]: x } = order(0)] = [];
  let result = destructuring_parse_bind_check(source)
  match result {
    Ok(_) => assert_true(true)
    Err(diagnostics) => {
      assert_true(false, msg="Expected success but got errors: " + diagnostics.length().to_string())
    }
  }
}

// ============================================================================
// Default Values in Nested Patterns Tests
// ============================================================================

///|
test "unit/parser/destructuring - nested object with default in array [{x} = {x: 0}]" {
  let source = "let [{ x } = { x: 0 }] = [];"
  let result = destructuring_parse_bind_check(source)
  match result {
    Ok(_) => assert_true(true)
    Err(diagnostics) => {
      assert_true(false, msg="Expected success but got errors: " + diagnostics.length().to_string())
    }
  }
}

///|
test "unit/parser/destructuring - nested array with default in array [[a] = [0]]" {
  let source = "let [[a] = [0]] = [];"
  let result = destructuring_parse_bind_check(source)
  match result {
    Ok(_) => assert_true(true)
    Err(diagnostics) => {
      assert_true(false, msg="Expected success but got errors: " + diagnostics.length().to_string())
    }
  }
}

///|
test "unit/parser/destructuring - complex nested pattern with defaults" {
  let source = "let [{ a, b } = { a: 1, b: 2 }, [c, d] = [3, 4]] = [];"
  let result = destructuring_parse_bind_check(source)
  match result {
    Ok(_) => assert_true(true)
    Err(diagnostics) => {
      assert_true(false, msg="Expected success but got errors: " + diagnostics.length().to_string())
    }
  }
}

// ============================================================================
// Combined Complex Destructuring Tests
// ============================================================================

///|
test "unit/parser/destructuring - mixed binding patterns" {
  let source =
    #|var { a, b: { c }, d: [e, f], 1: g } = {
    #|  a: 1,
    #|  b: { c: 2 },
    #|  d: [3, 4],
    #|  1: 5
    #|};
  let result = destructuring_parse_bind_check(source)
  match result {
    Ok(_) => assert_true(true)
    Err(diagnostics) => {
      assert_true(false, msg="Expected success but got errors: " + diagnostics.length().to_string())
    }
  }
}

// ============================================================================
// Parser-Only Tests (verify parsing without type checking)
// ============================================================================

///|
/// Helper function to parse source code only (no binding/checking)
fn destructuring_parse_only(source : String) -> Result[@compiler.SourceFile, Array[@compiler.Diagnostic]] {
  let tokens = @compiler.scan_all_v2(source, "test.ts")
  @compiler.parse_source_file(tokens, "test.ts")
}

///|
test "unit/parser/destructuring/parse-only - basic array destructuring" {
  let source = "const [a, b, c] = [1, 2, 3];"
  match destructuring_parse_only(source) {
    Ok(_) => assert_true(true)
    Err(_) => assert_true(false, msg="Parse failed")
  }
}

///|
test "unit/parser/destructuring/parse-only - basic object destructuring" {
  let source = "const { x, y, z } = obj;"
  match destructuring_parse_only(source) {
    Ok(_) => assert_true(true)
    Err(_) => assert_true(false, msg="Parse failed")
  }
}

///|
test "unit/parser/destructuring/parse-only - array with holes" {
  let source = "const [a, , , b] = arr;"
  match destructuring_parse_only(source) {
    Ok(_) => assert_true(true)
    Err(_) => assert_true(false, msg="Parse failed")
  }
}

///|
test "unit/parser/destructuring/parse-only - object with renaming" {
  let source = "const { foo: bar, baz: qux } = obj;"
  match destructuring_parse_only(source) {
    Ok(_) => assert_true(true)
    Err(_) => assert_true(false, msg="Parse failed")
  }
}

///|
test "unit/parser/destructuring/parse-only - nested array in array" {
  let source = "const [[a, b], [c, d]] = matrix;"
  match destructuring_parse_only(source) {
    Ok(_) => assert_true(true)
    Err(_) => assert_true(false, msg="Parse failed")
  }
}

///|
test "unit/parser/destructuring/parse-only - nested object in object" {
  let source = "const { outer: { inner } } = obj;"
  match destructuring_parse_only(source) {
    Ok(_) => assert_true(true)
    Err(_) => assert_true(false, msg="Parse failed")
  }
}

///|
test "unit/parser/destructuring/parse-only - array in object" {
  let source = "const { items: [first, second] } = obj;"
  match destructuring_parse_only(source) {
    Ok(_) => assert_true(true)
    Err(_) => assert_true(false, msg="Parse failed")
  }
}

///|
test "unit/parser/destructuring/parse-only - object in array" {
  let source = "const [{ name }, { age }] = people;"
  match destructuring_parse_only(source) {
    Ok(_) => assert_true(true)
    Err(_) => assert_true(false, msg="Parse failed")
  }
}

///|
test "unit/parser/destructuring/parse-only - rest element simple" {
  let source = "const [first, ...rest] = arr;"
  match destructuring_parse_only(source) {
    Ok(_) => assert_true(true)
    Err(_) => assert_true(false, msg="Parse failed")
  }
}

///|
test "unit/parser/destructuring/parse-only - rest with array pattern" {
  let source = "const [...[x, y]] = arr;"
  match destructuring_parse_only(source) {
    Ok(_) => assert_true(true)
    Err(_) => assert_true(false, msg="Parse failed")
  }
}

///|
test "unit/parser/destructuring/parse-only - rest with object pattern" {
  let source = "const [...{ length }] = arr;"
  match destructuring_parse_only(source) {
    Ok(_) => assert_true(true)
    Err(_) => assert_true(false, msg="Parse failed")
  }
}

///|
test "unit/parser/destructuring/parse-only - default value in array" {
  let source = "const [a = 1, b = 2] = arr;"
  match destructuring_parse_only(source) {
    Ok(_) => assert_true(true)
    Err(_) => assert_true(false, msg="Parse failed")
  }
}

///|
test "unit/parser/destructuring/parse-only - default value in object" {
  let source = "const { x = 10, y = 20 } = obj;"
  match destructuring_parse_only(source) {
    Ok(_) => assert_true(true)
    Err(_) => assert_true(false, msg="Parse failed")
  }
}

///|
test "unit/parser/destructuring/parse-only - default with renaming" {
  let source = "const { foo: bar = 'default' } = obj;"
  match destructuring_parse_only(source) {
    Ok(_) => assert_true(true)
    Err(_) => assert_true(false, msg="Parse failed")
  }
}

///|
test "unit/parser/destructuring/parse-only - numeric property 0" {
  let source = "const { 0: first } = arr;"
  match destructuring_parse_only(source) {
    Ok(_) => assert_true(true)
    Err(_) => assert_true(false, msg="Parse failed")
  }
}

///|
test "unit/parser/destructuring/parse-only - numeric property multiple" {
  let source = "const { 0: a, 1: b, 2: c } = arr;"
  match destructuring_parse_only(source) {
    Ok(_) => assert_true(true)
    Err(_) => assert_true(false, msg="Parse failed")
  }
}

///|
test "unit/parser/destructuring/parse-only - numeric with default" {
  let source = "const { 0: first = 'none' } = arr;"
  match destructuring_parse_only(source) {
    Ok(_) => assert_true(true)
    Err(_) => assert_true(false, msg="Parse failed")
  }
}

///|
test "unit/parser/destructuring/parse-only - numeric with nested array" {
  let source = "const { 0: [x, y] } = obj;"
  match destructuring_parse_only(source) {
    Ok(_) => assert_true(true)
    Err(_) => assert_true(false, msg="Parse failed")
  }
}

///|
test "unit/parser/destructuring/parse-only - numeric with nested object" {
  let source = "const { 0: { name } } = obj;"
  match destructuring_parse_only(source) {
    Ok(_) => assert_true(true)
    Err(_) => assert_true(false, msg="Parse failed")
  }
}

///|
test "unit/parser/destructuring/parse-only - string property simple" {
  let source = "const { \"hello-world\": hw } = obj;"
  match destructuring_parse_only(source) {
    Ok(_) => assert_true(true)
    Err(_) => assert_true(false, msg="Parse failed")
  }
}

///|
test "unit/parser/destructuring/parse-only - string property with spaces" {
  let source = "const { \"my property\": prop } = obj;"
  match destructuring_parse_only(source) {
    Ok(_) => assert_true(true)
    Err(_) => assert_true(false, msg="Parse failed")
  }
}

///|
test "unit/parser/destructuring/parse-only - string property with default" {
  let source = "const { \"key\": value = 42 } = obj;"
  match destructuring_parse_only(source) {
    Ok(_) => assert_true(true)
    Err(_) => assert_true(false, msg="Parse failed")
  }
}

///|
test "unit/parser/destructuring/parse-only - string property with nested" {
  let source = "const { \"data\": [a, b] } = obj;"
  match destructuring_parse_only(source) {
    Ok(_) => assert_true(true)
    Err(_) => assert_true(false, msg="Parse failed")
  }
}

///|
test "unit/parser/destructuring/parse-only - computed property simple" {
  let source = "const { [key]: value } = obj;"
  match destructuring_parse_only(source) {
    Ok(_) => assert_true(true)
    Err(_) => assert_true(false, msg="Parse failed")
  }
}

///|
test "unit/parser/destructuring/parse-only - computed property with expression" {
  let source = "const { [a + b]: sum } = obj;"
  match destructuring_parse_only(source) {
    Ok(_) => assert_true(true)
    Err(_) => assert_true(false, msg="Parse failed")
  }
}

///|
test "unit/parser/destructuring/parse-only - computed property with template" {
  let source = "const { [`key${n}`]: val } = obj;"
  match destructuring_parse_only(source) {
    Ok(_) => assert_true(true)
    Err(_) => assert_true(false, msg="Parse failed")
  }
}

///|
test "unit/parser/destructuring/parse-only - computed with default" {
  let source = "const { [prop]: x = 0 } = obj;"
  match destructuring_parse_only(source) {
    Ok(_) => assert_true(true)
    Err(_) => assert_true(false, msg="Parse failed")
  }
}

///|
test "unit/parser/destructuring/parse-only - computed with nested array" {
  let source = "const { [key]: [a, b, c] } = obj;"
  match destructuring_parse_only(source) {
    Ok(_) => assert_true(true)
    Err(_) => assert_true(false, msg="Parse failed")
  }
}

///|
test "unit/parser/destructuring/parse-only - computed with nested object" {
  let source = "const { [key]: { inner } } = obj;"
  match destructuring_parse_only(source) {
    Ok(_) => assert_true(true)
    Err(_) => assert_true(false, msg="Parse failed")
  }
}

///|
test "unit/parser/destructuring/parse-only - nested default object in array" {
  let source = "const [{ x, y } = { x: 0, y: 0 }] = arr;"
  match destructuring_parse_only(source) {
    Ok(_) => assert_true(true)
    Err(_) => assert_true(false, msg="Parse failed")
  }
}

///|
test "unit/parser/destructuring/parse-only - nested default array in array" {
  let source = "const [[a, b] = [1, 2]] = arr;"
  match destructuring_parse_only(source) {
    Ok(_) => assert_true(true)
    Err(_) => assert_true(false, msg="Parse failed")
  }
}

///|
test "unit/parser/destructuring/parse-only - multiple nested defaults" {
  let source = "const [{ a } = { a: 1 }, [b] = [2], c = 3] = arr;"
  match destructuring_parse_only(source) {
    Ok(_) => assert_true(true)
    Err(_) => assert_true(false, msg="Parse failed")
  }
}

///|
test "unit/parser/destructuring/parse-only - deeply nested patterns" {
  let source = "const { a: { b: { c: { d } } } } = obj;"
  match destructuring_parse_only(source) {
    Ok(_) => assert_true(true)
    Err(_) => assert_true(false, msg="Parse failed")
  }
}

///|
test "unit/parser/destructuring/parse-only - mixed complex pattern" {
  let source = "const { 0: [{ x }], \"key\": y, [computed]: z = 0 } = obj;"
  match destructuring_parse_only(source) {
    Ok(_) => assert_true(true)
    Err(_) => assert_true(false, msg="Parse failed")
  }
}

///|
test "unit/parser/destructuring/parse-only - let declaration" {
  let source = "let [a, b] = [1, 2];"
  match destructuring_parse_only(source) {
    Ok(_) => assert_true(true)
    Err(_) => assert_true(false, msg="Parse failed")
  }
}

///|
test "unit/parser/destructuring/parse-only - var declaration" {
  let source = "var { x, y } = point;"
  match destructuring_parse_only(source) {
    Ok(_) => assert_true(true)
    Err(_) => assert_true(false, msg="Parse failed")
  }
}

///|
test "unit/parser/destructuring/parse-only - for-of with array destructuring" {
  let source = "for (const [key, value] of entries) {}"
  match destructuring_parse_only(source) {
    Ok(_) => assert_true(true)
    Err(_) => assert_true(false, msg="Parse failed")
  }
}

///|
test "unit/parser/destructuring/parse-only - for-of with object destructuring" {
  let source = "for (const { name, age } of people) {}"
  match destructuring_parse_only(source) {
    Ok(_) => assert_true(true)
    Err(_) => assert_true(false, msg="Parse failed")
  }
}

///|
test "unit/parser/destructuring/parse-only - assignment expression array" {
  let source = "let a, b; [a, b] = [1, 2];"
  match destructuring_parse_only(source) {
    Ok(_) => assert_true(true)
    Err(_) => assert_true(false, msg="Parse failed")
  }
}

///|
test "unit/parser/destructuring/parse-only - assignment expression object" {
  let source = "let x, y; ({ x, y } = point);"
  match destructuring_parse_only(source) {
    Ok(_) => assert_true(true)
    Err(_) => assert_true(false, msg="Parse failed")
  }
}

///|
test "unit/parser/destructuring/parse-only - empty array pattern" {
  let source = "const [] = arr;"
  match destructuring_parse_only(source) {
    Ok(_) => assert_true(true)
    Err(_) => assert_true(false, msg="Parse failed")
  }
}

///|
test "unit/parser/destructuring/parse-only - empty object pattern" {
  let source = "const {} = obj;"
  match destructuring_parse_only(source) {
    Ok(_) => assert_true(true)
    Err(_) => assert_true(false, msg="Parse failed")
  }
}

///|
test "unit/parser/destructuring/parse-only - rest only in array" {
  let source = "const [...all] = arr;"
  match destructuring_parse_only(source) {
    Ok(_) => assert_true(true)
    Err(_) => assert_true(false, msg="Parse failed")
  }
}

///|
test "unit/parser/destructuring/parse-only - rest in object" {
  let source = "const { a, ...rest } = obj;"
  match destructuring_parse_only(source) {
    Ok(_) => assert_true(true)
    Err(_) => assert_true(false, msg="Parse failed")
  }
}

///|
test "unit/parser/destructuring/parse-only - type annotation array" {
  let source = "const [a, b]: [number, string] = [1, 'two'];"
  match destructuring_parse_only(source) {
    Ok(_) => assert_true(true)
    Err(_) => assert_true(false, msg="Parse failed")
  }
}

///|
test "unit/parser/destructuring/parse-only - type annotation object" {
  let source = "const { x, y }: { x: number, y: number } = point;"
  match destructuring_parse_only(source) {
    Ok(_) => assert_true(true)
    Err(_) => assert_true(false, msg="Parse failed")
  }
}

///|
test "unit/parser/destructuring/parse-only - function return destructuring" {
  let source = "const [first, second] = getValues();"
  match destructuring_parse_only(source) {
    Ok(_) => assert_true(true)
    Err(_) => assert_true(false, msg="Parse failed")
  }
}

///|
test "unit/parser/destructuring/parse-only - await with destructuring" {
  let source = "async function f() { const { data } = await fetch(); }"
  match destructuring_parse_only(source) {
    Ok(_) => assert_true(true)
    Err(_) => assert_true(false, msg="Parse failed")
  }
}

///|
test "unit/parser/destructuring/parse-only - trailing comma in array" {
  let source = "const [a, b, c,] = arr;"
  match destructuring_parse_only(source) {
    Ok(_) => assert_true(true)
    Err(_) => assert_true(false, msg="Parse failed")
  }
}

///|
test "unit/parser/destructuring/parse-only - trailing comma in object" {
  let source = "const { x, y, } = obj;"
  match destructuring_parse_only(source) {
    Ok(_) => assert_true(true)
    Err(_) => assert_true(false, msg="Parse failed")
  }
}

// ============================================================================
// Edge Cases and Special Scenarios
// ============================================================================

///|
test "unit/parser/destructuring/parse-only - numeric float property" {
  let source = "const { 1.5: val } = obj;"
  match destructuring_parse_only(source) {
    Ok(_) => assert_true(true)
    Err(_) => assert_true(false, msg="Parse failed")
  }
}

///|
test "unit/parser/destructuring/parse-only - negative numeric property" {
  // Note: Negative numeric properties are parsed as unary minus + number
  let source = "const { [-1]: val } = obj;"
  match destructuring_parse_only(source) {
    Ok(_) => assert_true(true)
    Err(_) => assert_true(false, msg="Parse failed")
  }
}

///|
test "unit/parser/destructuring/parse-only - string with escape" {
  let source = "const { \"hello\\nworld\": val } = obj;"
  match destructuring_parse_only(source) {
    Ok(_) => assert_true(true)
    Err(_) => assert_true(false, msg="Parse failed")
  }
}

///|
test "unit/parser/destructuring/parse-only - computed with method call" {
  let source = "const { [obj.getKey()]: val } = data;"
  match destructuring_parse_only(source) {
    Ok(_) => assert_true(true)
    Err(_) => assert_true(false, msg="Parse failed")
  }
}

///|
test "unit/parser/destructuring/parse-only - computed with ternary" {
  let source = "const { [cond ? 'a' : 'b']: val } = obj;"
  match destructuring_parse_only(source) {
    Ok(_) => assert_true(true)
    Err(_) => assert_true(false, msg="Parse failed")
  }
}

///|
test "unit/parser/destructuring/parse-only - very deep nesting" {
  let source = "const [[[[[[a]]]]]] = arr;"
  match destructuring_parse_only(source) {
    Ok(_) => assert_true(true)
    Err(_) => assert_true(false, msg="Parse failed")
  }
}

///|
test "unit/parser/destructuring/parse-only - mixed all features" {
  let source =
    #|const {
    #|  a,
    #|  b: renamed,
    #|  c = 'default',
    #|  0: first,
    #|  "special-key": special,
    #|  [computed]: dynamic,
    #|  nested: { inner },
    #|  arr: [x, y, ...rest],
    #|  ...remaining
    #|} = bigObject;
  match destructuring_parse_only(source) {
    Ok(_) => assert_true(true)
    Err(_) => assert_true(false, msg="Parse failed")
  }
}

// ============================================================================
// Contextual Keywords as Identifiers Tests
// ============================================================================

///|
test "unit/parser/destructuring/parse-only - contextual keyword 'as' in binding" {
  let source = "var { as } = { as: 1 };"
  match destructuring_parse_only(source) {
    Ok(_) => assert_true(true)
    Err(_) => assert_true(false, msg="Parse failed")
  }
}

///|
test "unit/parser/destructuring/parse-only - contextual keyword 'as' with renaming" {
  let source = "var { as: as } = { as: 1 };"
  match destructuring_parse_only(source) {
    Ok(_) => assert_true(true)
    Err(_) => assert_true(false, msg="Parse failed")
  }
}

///|
test "unit/parser/destructuring/parse-only - contextual keyword 'from' in binding" {
  let source = "var { from } = { from: 'value' };"
  match destructuring_parse_only(source) {
    Ok(_) => assert_true(true)
    Err(_) => assert_true(false, msg="Parse failed")
  }
}

///|
test "unit/parser/destructuring/parse-only - contextual keyword 'of' in binding" {
  let source = "var { of } = { of: true };"
  match destructuring_parse_only(source) {
    Ok(_) => assert_true(true)
    Err(_) => assert_true(false, msg="Parse failed")
  }
}

///|
test "unit/parser/destructuring/parse-only - contextual keyword 'type' in binding" {
  let source = "var { type } = { type: 'string' };"
  match destructuring_parse_only(source) {
    Ok(_) => assert_true(true)
    Err(_) => assert_true(false, msg="Parse failed")
  }
}

///|
test "unit/parser/destructuring/parse-only - contextual keyword 'async' in binding" {
  let source = "var { async } = { async: true };"
  match destructuring_parse_only(source) {
    Ok(_) => assert_true(true)
    Err(_) => assert_true(false, msg="Parse failed")
  }
}

///|
test "unit/parser/destructuring/parse-only - contextual keyword 'declare' in binding" {
  let source = "var { declare } = { declare: 'value' };"
  match destructuring_parse_only(source) {
    Ok(_) => assert_true(true)
    Err(_) => assert_true(false, msg="Parse failed")
  }
}

///|
test "unit/parser/destructuring/parse-only - multiple contextual keywords" {
  let source = "var { as, from, of, type } = obj;"
  match destructuring_parse_only(source) {
    Ok(_) => assert_true(true)
    Err(_) => assert_true(false, msg="Parse failed")
  }
}

///|
test "unit/parser/destructuring/parse-only - contextual keyword with default" {
  let source = "var { as = 'default' } = obj;"
  match destructuring_parse_only(source) {
    Ok(_) => assert_true(true)
    Err(_) => assert_true(false, msg="Parse failed")
  }
}

///|
test "unit/parser/destructuring/parse-only - contextual keyword with nested pattern" {
  let source = "var { as: [a, b] } = obj;"
  match destructuring_parse_only(source) {
    Ok(_) => assert_true(true)
    Err(_) => assert_true(false, msg="Parse failed")
  }
}
