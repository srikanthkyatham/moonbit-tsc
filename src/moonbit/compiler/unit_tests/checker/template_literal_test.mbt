// Template Literal Type Unit Tests
// Tests for template literal type evaluation and intrinsic string manipulation types

// ============================================================================
// Template Literal Type Evaluation Tests
// ============================================================================

///|
test "unit/template-literal/eval - simple literal template" {
  // `hello` -> "hello"
  let tl = @compiler.TemplateLiteralTypeV2::new(["hello"], [])
  let env = @compiler.TypeEnv::new()
  let result = @compiler.evaluate_template_literal_type_v2(env, tl)
  match result {
    @compiler.TLiteralString(s) => assert_eq(s, "hello")
    _ => assert_true(false)
  }
}

///|
test "unit/template-literal/eval - prefix suffix with string literal" {
  // `Hello, ${"World"}!` -> "Hello, World!"
  let tl = @compiler.TemplateLiteralTypeV2::new(["Hello, ", "!"], [
    @compiler.create_literal_string_type("World"),
  ])
  let env = @compiler.TypeEnv::new()
  let result = @compiler.evaluate_template_literal_type_v2(env, tl)
  match result {
    @compiler.TLiteralString(s) => assert_eq(s, "Hello, World!")
    _ => assert_true(false)
  }
}

///|
test "unit/template-literal/eval - union distribution" {
  // `on${"Click" | "Focus"}` -> "onClick" | "onFocus"
  let tl = @compiler.TemplateLiteralTypeV2::new(["on", ""], [
    @compiler.create_union_type([
      @compiler.create_literal_string_type("Click"),
      @compiler.create_literal_string_type("Focus"),
    ]),
  ])
  let env = @compiler.TypeEnv::new()
  let result = @compiler.evaluate_template_literal_type_v2(env, tl)
  match result {
    @compiler.TUnion(types) => {
      assert_eq(types.length(), 2)
      // Check both values are present
      let has_click = types
        .iter()
        .any(fn(t) {
          match t {
            @compiler.TLiteralString("onClick") => true
            _ => false
          }
        })
      let has_focus = types
        .iter()
        .any(fn(t) {
          match t {
            @compiler.TLiteralString("onFocus") => true
            _ => false
          }
        })
      assert_true(has_click)
      assert_true(has_focus)
    }
    _ => assert_true(false)
  }
}

///|
test "unit/template-literal/eval - multiple unions cartesian product" {
  // `${"a" | "b"}-${"x" | "y"}` -> "a-x" | "a-y" | "b-x" | "b-y"
  let tl = @compiler.TemplateLiteralTypeV2::new(["", "-", ""], [
    @compiler.create_union_type([
      @compiler.create_literal_string_type("a"),
      @compiler.create_literal_string_type("b"),
    ]),
    @compiler.create_union_type([
      @compiler.create_literal_string_type("x"),
      @compiler.create_literal_string_type("y"),
    ]),
  ])
  let env = @compiler.TypeEnv::new()
  let result = @compiler.evaluate_template_literal_type_v2(env, tl)
  match result {
    @compiler.TUnion(types) => {
      assert_eq(types.length(), 4)
      // Check all combinations are present
      let expected = ["a-x", "a-y", "b-x", "b-y"]
      for exp in expected {
        let found = types
          .iter()
          .any(fn(t) {
            match t {
              @compiler.TLiteralString(s) => s == exp
              _ => false
            }
          })
        assert_true(found)
      }
    }
    _ => assert_true(false)
  }
}

///|
test "unit/template-literal/eval - number literal interpolation" {
  // `item-${1 | 2}` -> "item-1" | "item-2"
  let tl = @compiler.TemplateLiteralTypeV2::new(["item-", ""], [
    @compiler.create_union_type([
      @compiler.create_literal_number_type(1.0),
      @compiler.create_literal_number_type(2.0),
    ]),
  ])
  let env = @compiler.TypeEnv::new()
  let result = @compiler.evaluate_template_literal_type_v2(env, tl)
  match result {
    @compiler.TUnion(types) => {
      assert_eq(types.length(), 2)
      let has_1 = types
        .iter()
        .any(fn(t) {
          match t {
            @compiler.TLiteralString("item-1") => true
            _ => false
          }
        })
      let has_2 = types
        .iter()
        .any(fn(t) {
          match t {
            @compiler.TLiteralString("item-2") => true
            _ => false
          }
        })
      assert_true(has_1)
      assert_true(has_2)
    }
    _ => assert_true(false)
  }
}

///|
test "unit/template-literal/eval - boolean literal interpolation" {
  // `is-${true | false}` -> "is-true" | "is-false"
  let tl = @compiler.TemplateLiteralTypeV2::new(["is-", ""], [
    @compiler.create_union_type([
      @compiler.create_literal_bool_type(true),
      @compiler.create_literal_bool_type(false),
    ]),
  ])
  let env = @compiler.TypeEnv::new()
  let result = @compiler.evaluate_template_literal_type_v2(env, tl)
  match result {
    @compiler.TUnion(types) => {
      assert_eq(types.length(), 2)
      let has_true = types
        .iter()
        .any(fn(t) {
          match t {
            @compiler.TLiteralString("is-true") => true
            _ => false
          }
        })
      let has_false = types
        .iter()
        .any(fn(t) {
          match t {
            @compiler.TLiteralString("is-false") => true
            _ => false
          }
        })
      assert_true(has_true)
      assert_true(has_false)
    }
    _ => assert_true(false)
  }
}

///|
test "unit/template-literal/eval - broad type returns string" {
  // `prefix-${string}` -> string
  let tl = @compiler.TemplateLiteralTypeV2::new(["prefix-", ""], [
    @compiler.create_string_type(),
  ])
  let env = @compiler.TypeEnv::new()
  let result = @compiler.evaluate_template_literal_type_v2(env, tl)
  match result {
    @compiler.TString => assert_true(true)
    _ => assert_true(false)
  }
}

///|
test "unit/template-literal/eval - number type returns string" {
  // `count-${number}` -> string
  let tl = @compiler.TemplateLiteralTypeV2::new(["count-", ""], [
    @compiler.create_number_type(),
  ])
  let env = @compiler.TypeEnv::new()
  let result = @compiler.evaluate_template_literal_type_v2(env, tl)
  match result {
    @compiler.TString => assert_true(true)
    _ => assert_true(false)
  }
}

// ============================================================================
// Intrinsic String Manipulation Type Tests
// ============================================================================

///|
test "unit/template-literal/uppercase - literal string" {
  let ty = @compiler.create_literal_string_type("hello")
  let result = @compiler.evaluate_uppercase_type(ty)
  match result {
    @compiler.TLiteralString(s) => assert_eq(s, "HELLO")
    _ => assert_true(false)
  }
}

///|
test "unit/template-literal/uppercase - mixed case" {
  let ty = @compiler.create_literal_string_type("HeLLo WoRLd")
  let result = @compiler.evaluate_uppercase_type(ty)
  match result {
    @compiler.TLiteralString(s) => assert_eq(s, "HELLO WORLD")
    _ => assert_true(false)
  }
}

///|
test "unit/template-literal/uppercase - union" {
  let ty = @compiler.create_union_type([
    @compiler.create_literal_string_type("foo"),
    @compiler.create_literal_string_type("bar"),
  ])
  let result = @compiler.evaluate_uppercase_type(ty)
  match result {
    @compiler.TUnion(types) => {
      assert_eq(types.length(), 2)
      let has_foo = types
        .iter()
        .any(fn(t) {
          match t {
            @compiler.TLiteralString("FOO") => true
            _ => false
          }
        })
      let has_bar = types
        .iter()
        .any(fn(t) {
          match t {
            @compiler.TLiteralString("BAR") => true
            _ => false
          }
        })
      assert_true(has_foo)
      assert_true(has_bar)
    }
    _ => assert_true(false)
  }
}

///|
test "unit/template-literal/uppercase - string returns string" {
  let ty = @compiler.create_string_type()
  let result = @compiler.evaluate_uppercase_type(ty)
  match result {
    @compiler.TString => assert_true(true)
    _ => assert_true(false)
  }
}

///|
test "unit/template-literal/lowercase - literal string" {
  let ty = @compiler.create_literal_string_type("HELLO")
  let result = @compiler.evaluate_lowercase_type(ty)
  match result {
    @compiler.TLiteralString(s) => assert_eq(s, "hello")
    _ => assert_true(false)
  }
}

///|
test "unit/template-literal/lowercase - mixed case" {
  let ty = @compiler.create_literal_string_type("HeLLo WoRLd")
  let result = @compiler.evaluate_lowercase_type(ty)
  match result {
    @compiler.TLiteralString(s) => assert_eq(s, "hello world")
    _ => assert_true(false)
  }
}

///|
test "unit/template-literal/capitalize - lowercase string" {
  let ty = @compiler.create_literal_string_type("hello")
  let result = @compiler.evaluate_capitalize_type(ty)
  match result {
    @compiler.TLiteralString(s) => assert_eq(s, "Hello")
    _ => assert_true(false)
  }
}

///|
test "unit/template-literal/capitalize - already capitalized" {
  let ty = @compiler.create_literal_string_type("Hello")
  let result = @compiler.evaluate_capitalize_type(ty)
  match result {
    @compiler.TLiteralString(s) => assert_eq(s, "Hello")
    _ => assert_true(false)
  }
}

///|
test "unit/template-literal/capitalize - empty string" {
  let ty = @compiler.create_literal_string_type("")
  let result = @compiler.evaluate_capitalize_type(ty)
  match result {
    @compiler.TLiteralString(s) => assert_eq(s, "")
    _ => assert_true(false)
  }
}

///|
test "unit/template-literal/capitalize - union" {
  let ty = @compiler.create_union_type([
    @compiler.create_literal_string_type("click"),
    @compiler.create_literal_string_type("focus"),
  ])
  let result = @compiler.evaluate_capitalize_type(ty)
  match result {
    @compiler.TUnion(types) => {
      assert_eq(types.length(), 2)
      let has_click = types
        .iter()
        .any(fn(t) {
          match t {
            @compiler.TLiteralString("Click") => true
            _ => false
          }
        })
      let has_focus = types
        .iter()
        .any(fn(t) {
          match t {
            @compiler.TLiteralString("Focus") => true
            _ => false
          }
        })
      assert_true(has_click)
      assert_true(has_focus)
    }
    _ => assert_true(false)
  }
}

///|
test "unit/template-literal/uncapitalize - uppercase start" {
  let ty = @compiler.create_literal_string_type("Hello")
  let result = @compiler.evaluate_uncapitalize_type(ty)
  match result {
    @compiler.TLiteralString(s) => assert_eq(s, "hello")
    _ => assert_true(false)
  }
}

///|
test "unit/template-literal/uncapitalize - all uppercase" {
  let ty = @compiler.create_literal_string_type("HELLO")
  let result = @compiler.evaluate_uncapitalize_type(ty)
  match result {
    @compiler.TLiteralString(s) => assert_eq(s, "hELLO")
    _ => assert_true(false)
  }
}

///|
test "unit/template-literal/uncapitalize - already lowercase" {
  let ty = @compiler.create_literal_string_type("hello")
  let result = @compiler.evaluate_uncapitalize_type(ty)
  match result {
    @compiler.TLiteralString(s) => assert_eq(s, "hello")
    _ => assert_true(false)
  }
}

// ============================================================================
// evaluate_intrinsic_string_type Tests
// ============================================================================

///|
test "unit/template-literal/intrinsic - Uppercase recognized" {
  let ty = @compiler.create_literal_string_type("hello")
  let result = @compiler.evaluate_intrinsic_string_type("Uppercase", ty)
  match result {
    Some(@compiler.TLiteralString(s)) => assert_eq(s, "HELLO")
    _ => assert_true(false)
  }
}

///|
test "unit/template-literal/intrinsic - Lowercase recognized" {
  let ty = @compiler.create_literal_string_type("HELLO")
  let result = @compiler.evaluate_intrinsic_string_type("Lowercase", ty)
  match result {
    Some(@compiler.TLiteralString(s)) => assert_eq(s, "hello")
    _ => assert_true(false)
  }
}

///|
test "unit/template-literal/intrinsic - Capitalize recognized" {
  let ty = @compiler.create_literal_string_type("hello")
  let result = @compiler.evaluate_intrinsic_string_type("Capitalize", ty)
  match result {
    Some(@compiler.TLiteralString(s)) => assert_eq(s, "Hello")
    _ => assert_true(false)
  }
}

///|
test "unit/template-literal/intrinsic - Uncapitalize recognized" {
  let ty = @compiler.create_literal_string_type("Hello")
  let result = @compiler.evaluate_intrinsic_string_type("Uncapitalize", ty)
  match result {
    Some(@compiler.TLiteralString(s)) => assert_eq(s, "hello")
    _ => assert_true(false)
  }
}

///|
test "unit/template-literal/intrinsic - unknown returns None" {
  let ty = @compiler.create_literal_string_type("hello")
  let result = @compiler.evaluate_intrinsic_string_type("Unknown", ty)
  match result {
    None => assert_true(true)
    Some(_) => assert_true(false)
  }
}

// ============================================================================
// Edge Cases
// ============================================================================

///|
test "unit/template-literal/eval - single literal no interpolation" {
  let tl = @compiler.TemplateLiteralTypeV2::new(["constant"], [])
  let env = @compiler.TypeEnv::new()
  let result = @compiler.evaluate_template_literal_type_v2(env, tl)
  match result {
    @compiler.TLiteralString(s) => assert_eq(s, "constant")
    _ => assert_true(false)
  }
}

///|
test "unit/template-literal/eval - empty template" {
  let tl = @compiler.TemplateLiteralTypeV2::new([""], [])
  let env = @compiler.TypeEnv::new()
  let result = @compiler.evaluate_template_literal_type_v2(env, tl)
  match result {
    @compiler.TLiteralString(s) => assert_eq(s, "")
    _ => assert_true(false)
  }
}

///|
test "unit/template-literal/eval - null and undefined" {
  // `value-${null | undefined}` -> "value-null" | "value-undefined"
  let tl = @compiler.TemplateLiteralTypeV2::new(["value-", ""], [
    @compiler.create_union_type([
      @compiler.create_null_type(),
      @compiler.create_undefined_type(),
    ]),
  ])
  let env = @compiler.TypeEnv::new()
  let result = @compiler.evaluate_template_literal_type_v2(env, tl)
  match result {
    @compiler.TUnion(types) => {
      assert_eq(types.length(), 2)
      let has_null = types
        .iter()
        .any(fn(t) {
          match t {
            @compiler.TLiteralString("value-null") => true
            _ => false
          }
        })
      let has_undef = types
        .iter()
        .any(fn(t) {
          match t {
            @compiler.TLiteralString("value-undefined") => true
            _ => false
          }
        })
      assert_true(has_null)
      assert_true(has_undef)
    }
    _ => assert_true(false)
  }
}

///|
test "unit/template-literal/eval - three interpolations" {
  // `${a | b}${1 | 2}${x | y}` should produce 8 combinations
  let tl = @compiler.TemplateLiteralTypeV2::new(["", "", "", ""], [
    @compiler.create_union_type([
      @compiler.create_literal_string_type("a"),
      @compiler.create_literal_string_type("b"),
    ]),
    @compiler.create_union_type([
      @compiler.create_literal_number_type(1.0),
      @compiler.create_literal_number_type(2.0),
    ]),
    @compiler.create_union_type([
      @compiler.create_literal_string_type("x"),
      @compiler.create_literal_string_type("y"),
    ]),
  ])
  let env = @compiler.TypeEnv::new()
  let result = @compiler.evaluate_template_literal_type_v2(env, tl)
  match result {
    @compiler.TUnion(types) =>
      // 2 * 2 * 2 = 8 combinations
      assert_eq(types.length(), 8)
    _ => assert_true(false)
  }
}

// ============================================================================
// Template Literal Pattern Matching Tests
// ============================================================================

///|
test "unit/template-literal/match - simple prefix pattern" {
  // Match "onClick" against `on${string}`
  let pattern = @compiler.TemplateLiteralTypeV2::new(["on", ""], [
    @compiler.create_string_type(),
  ])
  let result = @compiler.matches_template_literal_pattern("onClick", pattern)
  assert_true(result)
}

///|
test "unit/template-literal/match - simple prefix no match" {
  // "handleClick" doesn't match `on${string}`
  let pattern = @compiler.TemplateLiteralTypeV2::new(["on", ""], [
    @compiler.create_string_type(),
  ])
  let result = @compiler.matches_template_literal_pattern(
    "handleClick", pattern,
  )
  assert_false(result)
}

///|
test "unit/template-literal/match - prefix and suffix pattern" {
  // Match "onClick_handler" against `on${string}_handler`
  let pattern = @compiler.TemplateLiteralTypeV2::new(["on", "_handler"], [
    @compiler.create_string_type(),
  ])
  let result = @compiler.matches_template_literal_pattern(
    "onClick_handler", pattern,
  )
  assert_true(result)
}

///|
test "unit/template-literal/match - exact literal match" {
  // Match "hello" against `hello`
  let pattern = @compiler.TemplateLiteralTypeV2::new(["hello"], [])
  let result = @compiler.matches_template_literal_pattern("hello", pattern)
  assert_true(result)
}

///|
test "unit/template-literal/match - exact literal no match" {
  // "world" doesn't match `hello`
  let pattern = @compiler.TemplateLiteralTypeV2::new(["hello"], [])
  let result = @compiler.matches_template_literal_pattern("world", pattern)
  assert_false(result)
}

///|
test "unit/template-literal/match - multiple interpolations" {
  // Match "user_123_admin" against `user_${string}_admin`
  let pattern = @compiler.TemplateLiteralTypeV2::new(["user_", "_admin"], [
    @compiler.create_string_type(),
  ])
  let result = @compiler.matches_template_literal_pattern(
    "user_123_admin", pattern,
  )
  assert_true(result)
}

///|
test "unit/template-literal/match - number interpolation" {
  // Match "item-42" against `item-${number}` (number pattern)
  let pattern = @compiler.TemplateLiteralTypeV2::new(["item-", ""], [
    @compiler.create_number_type(),
  ])
  let result = @compiler.matches_template_literal_pattern("item-42", pattern)
  assert_true(result)
}

///|
test "unit/template-literal/match - number interpolation negative" {
  // Match "item--5" against `item-${number}` (negative number)
  let pattern = @compiler.TemplateLiteralTypeV2::new(["item-", ""], [
    @compiler.create_number_type(),
  ])
  let result = @compiler.matches_template_literal_pattern("item--5", pattern)
  assert_true(result)
}

///|
test "unit/template-literal/match - number interpolation non-numeric fails" {
  // "item-abc" doesn't match `item-${number}`
  let pattern = @compiler.TemplateLiteralTypeV2::new(["item-", ""], [
    @compiler.create_number_type(),
  ])
  let result = @compiler.matches_template_literal_pattern("item-abc", pattern)
  assert_false(result)
}

// ============================================================================
// Template Literal Assignment Compatibility Tests
// ============================================================================

///|
test "unit/template-literal/assign - literal to template with string" {
  // "onClick" is assignable to `on${string}`
  let pattern = @compiler.TemplateLiteralTypeV2::new(["on", ""], [
    @compiler.create_string_type(),
  ])
  let source = @compiler.create_literal_string_type("onClick")
  let result = @compiler.is_assignable_to_template_literal(source, pattern)
  assert_true(result)
}

///|
test "unit/template-literal/assign - literal not matching template" {
  // "handleClick" is not assignable to `on${string}`
  let pattern = @compiler.TemplateLiteralTypeV2::new(["on", ""], [
    @compiler.create_string_type(),
  ])
  let source = @compiler.create_literal_string_type("handleClick")
  let result = @compiler.is_assignable_to_template_literal(source, pattern)
  assert_false(result)
}

///|
test "unit/template-literal/assign - string to broad template" {
  // string is assignable to `${string}` (broad template)
  let pattern = @compiler.TemplateLiteralTypeV2::new(["", ""], [
    @compiler.create_string_type(),
  ])
  let source = @compiler.create_string_type()
  let result = @compiler.is_assignable_to_template_literal(source, pattern)
  assert_true(result)
}

///|
test "unit/template-literal/assign - union all matching" {
  // "onClick" | "onFocus" is assignable to `on${string}`
  let pattern = @compiler.TemplateLiteralTypeV2::new(["on", ""], [
    @compiler.create_string_type(),
  ])
  let source = @compiler.create_union_type([
    @compiler.create_literal_string_type("onClick"),
    @compiler.create_literal_string_type("onFocus"),
  ])
  let result = @compiler.is_assignable_to_template_literal(source, pattern)
  assert_true(result)
}

///|
test "unit/template-literal/assign - union partial matching fails" {
  // "onClick" | "handleFocus" is NOT assignable to `on${string}`
  let pattern = @compiler.TemplateLiteralTypeV2::new(["on", ""], [
    @compiler.create_string_type(),
  ])
  let source = @compiler.create_union_type([
    @compiler.create_literal_string_type("onClick"),
    @compiler.create_literal_string_type("handleFocus"),
  ])
  let result = @compiler.is_assignable_to_template_literal(source, pattern)
  assert_false(result)
}

// ============================================================================
// Template Literal Type Compatibility Tests
// ============================================================================

///|
test "unit/template-literal/compat - same templates are compatible" {
  let tl1 = @compiler.TemplateLiteralTypeV2::new(["prefix-", "-suffix"], [
    @compiler.create_string_type(),
  ])
  let tl2 = @compiler.TemplateLiteralTypeV2::new(["prefix-", "-suffix"], [
    @compiler.create_string_type(),
  ])
  let result = @compiler.are_template_literals_compatible(tl1, tl2)
  assert_true(result)
}

///|
test "unit/template-literal/compat - different texts not compatible" {
  let tl1 = @compiler.TemplateLiteralTypeV2::new(["prefix-", "-suffix"], [
    @compiler.create_string_type(),
  ])
  let tl2 = @compiler.TemplateLiteralTypeV2::new(["other-", "-suffix"], [
    @compiler.create_string_type(),
  ])
  let result = @compiler.are_template_literals_compatible(tl1, tl2)
  assert_false(result)
}

///|
test "unit/template-literal/compat - literal assignable to string position" {
  // `prefix-${"value"}-suffix` compatible with `prefix-${string}-suffix`
  let tl1 = @compiler.TemplateLiteralTypeV2::new(["prefix-", "-suffix"], [
    @compiler.create_literal_string_type("value"),
  ])
  let tl2 = @compiler.TemplateLiteralTypeV2::new(["prefix-", "-suffix"], [
    @compiler.create_string_type(),
  ])
  let result = @compiler.are_template_literals_compatible(tl1, tl2)
  assert_true(result)
}

///|
test "unit/template-literal/compat - different interpolation count not compatible" {
  let tl1 = @compiler.TemplateLiteralTypeV2::new(["a", "b"], [
    @compiler.create_string_type(),
  ])
  let tl2 = @compiler.TemplateLiteralTypeV2::new(["a", "b", "c"], [
    @compiler.create_string_type(),
    @compiler.create_string_type(),
  ])
  let result = @compiler.are_template_literals_compatible(tl1, tl2)
  assert_false(result)
}
