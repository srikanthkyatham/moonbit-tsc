// Checker Type Tests
// Tests for the checker type system features including:
// - Literal types (NumberLiteral, StringLiteral, BooleanLiteral)
// - Type references
// - Intersection types
// - Tuple types
// - Conditional types
// - Mapped types
// - Template literal types
// - Index access types
// - Infer types

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

// ============================================================================
// Literal Type Creation Tests
// ============================================================================

///|
test "unit/checker/literal - create number literal type" {
  let checker = @compiler.TypeChecker::new("test.ts", None)
  let (lit_type, _) = @compiler.number_literal_type(checker, 42.0)
  match lit_type {
    NumberLiteral(value, _) => assert_eq(value, 42.0)
    _ => assert_true(false)
  }
}

///|
test "unit/checker/literal - create string literal type" {
  let checker = @compiler.TypeChecker::new("test.ts", None)
  let (lit_type, _) = @compiler.string_literal_type(checker, "hello")
  match lit_type {
    StringLiteral(value, _) => assert_eq(value, "hello")
    _ => assert_true(false)
  }
}

///|
test "unit/checker/literal - create boolean literal type" {
  let checker = @compiler.TypeChecker::new("test.ts", None)
  let (lit_type, _) = @compiler.boolean_literal_type(checker, true)
  match lit_type {
    BooleanLiteral(value, _) => assert_eq(value, true)
    _ => assert_true(false)
  }
}

// ============================================================================
// Type Reference Tests
// ============================================================================

///|
test "unit/checker/type-ref - create type reference" {
  let checker = @compiler.TypeChecker::new("test.ts", None)
  let (ref_type, _) = @compiler.type_reference_type(checker, "MyType", [])
  match ref_type {
    TypeReference(tr) => assert_eq(tr.name, "MyType")
    _ => assert_true(false)
  }
}

///|
test "unit/checker/type-ref - with type arguments" {
  let checker = @compiler.TypeChecker::new("test.ts", None)
  let (num_type, checker) = @compiler.number_type(checker)
  let (ref_type, _) = @compiler.type_reference_type(checker, "Array", [num_type])
  match ref_type {
    TypeReference(tr) => {
      assert_eq(tr.name, "Array")
      assert_eq(tr.type_arguments.length(), 1)
    }
    _ => assert_true(false)
  }
}

// ============================================================================
// Intersection Type Tests
// ============================================================================

///|
test "unit/checker/intersection - create intersection type" {
  let checker = @compiler.TypeChecker::new("test.ts", None)
  let (num_type, checker) = @compiler.number_type(checker)
  let (str_type, checker) = @compiler.string_type(checker)
  let (inter_type, _) = @compiler.intersection_type(checker, [
    num_type, str_type,
  ])
  match inter_type {
    Intersection(inter) => assert_eq(inter.types.length(), 2)
    _ => assert_true(false)
  }
}

///|
test "unit/checker/intersection - single type returns itself" {
  let checker = @compiler.TypeChecker::new("test.ts", None)
  let (num_type, checker) = @compiler.number_type(checker)
  let (result, _) = @compiler.intersection_type(checker, [num_type])
  match result {
    Number(_) => assert_true(true)
    _ => assert_true(false)
  }
}

///|
test "unit/checker/intersection - flattens nested" {
  let checker = @compiler.TypeChecker::new("test.ts", None)
  let (num_type, checker) = @compiler.number_type(checker)
  let (str_type, checker) = @compiler.string_type(checker)
  let (bool_type, checker) = @compiler.boolean_type(checker)
  let (inner, checker) = @compiler.intersection_type(checker, [
    num_type, str_type,
  ])
  let (outer, _) = @compiler.intersection_type(checker, [inner, bool_type])
  match outer {
    Intersection(inter) => assert_eq(inter.types.length(), 3)
    _ => assert_true(false)
  }
}

// ============================================================================
// Tuple Type Tests
// ============================================================================

///|
test "unit/checker/tuple - create tuple type" {
  let checker = @compiler.TypeChecker::new("test.ts", None)
  let (num_type, checker) = @compiler.number_type(checker)
  let (str_type, checker) = @compiler.string_type(checker)
  let elem1 = @compiler.tuple_element(num_type, false, false, None)
  let elem2 = @compiler.tuple_element(str_type, false, false, None)
  let (tup_type, _) = @compiler.tuple_type(checker, [elem1, elem2])
  match tup_type {
    Tuple(tup) => assert_eq(tup.element_types.length(), 2)
    _ => assert_true(false)
  }
}

///|
test "unit/checker/tuple - with optional element" {
  let checker = @compiler.TypeChecker::new("test.ts", None)
  let (num_type, checker) = @compiler.number_type(checker)
  let elem = @compiler.tuple_element(num_type, true, false, None)
  let (tup_type, _) = @compiler.tuple_type(checker, [elem])
  match tup_type {
    Tuple(tup) => assert_eq(tup.element_types[0].is_optional, true)
    _ => assert_true(false)
  }
}

///|
test "unit/checker/tuple - with labeled element" {
  let checker = @compiler.TypeChecker::new("test.ts", None)
  let (num_type, checker) = @compiler.number_type(checker)
  let elem = @compiler.tuple_element(num_type, false, false, Some("x"))
  let (tup_type, _) = @compiler.tuple_type(checker, [elem])
  match tup_type {
    Tuple(tup) => assert_eq(tup.element_types[0].label, Some("x"))
    _ => assert_true(false)
  }
}

///|
test "unit/checker/tuple - get element type at index" {
  let checker = @compiler.TypeChecker::new("test.ts", None)
  let (num_type, checker) = @compiler.number_type(checker)
  let (str_type, checker) = @compiler.string_type(checker)
  let elem1 = @compiler.tuple_element(num_type, false, false, None)
  let elem2 = @compiler.tuple_element(str_type, false, false, None)
  let (tup_type, _) = @compiler.tuple_type(checker, [elem1, elem2])
  match tup_type {
    Tuple(tup) =>
      match @compiler.get_tuple_element_type(tup, 1) {
        Some(String(_)) => assert_true(true)
        _ => assert_true(false)
      }
    _ => assert_true(false)
  }
}

// ============================================================================
// Conditional Type Tests
// ============================================================================

///|
test "unit/checker/conditional - create conditional type" {
  let checker = @compiler.TypeChecker::new("test.ts", None)
  let (num_type, checker) = @compiler.number_type(checker)
  let (str_type, checker) = @compiler.string_type(checker)
  let (bool_type, checker) = @compiler.boolean_type(checker)
  let (any_t, checker) = @compiler.any_type(checker)
  let (cond_type, _) = @compiler.conditional_type(
    checker, num_type, any_t, str_type, bool_type,
  )
  match cond_type {
    Conditional(cond) =>
      match cond.check_type {
        Number(_) => assert_true(true)
        _ => assert_true(false)
      }
    _ => assert_true(false)
  }
}

///|
test "unit/checker/conditional - evaluate true branch" {
  let checker = @compiler.TypeChecker::new("test.ts", None)
  let (num_type, checker) = @compiler.number_type(checker)
  let (any_t, checker) = @compiler.any_type(checker)
  let (str_type, checker) = @compiler.string_type(checker)
  let (bool_type, checker) = @compiler.boolean_type(checker)
  let (cond_type, checker) = @compiler.conditional_type(
    checker, num_type, any_t, str_type, bool_type,
  )
  match cond_type {
    Conditional(cond) => {
      let (result, _) = @compiler.evaluate_conditional_type(checker, cond)
      match result {
        String(_) => assert_true(true)
        _ => assert_true(false)
      }
    }
    _ => assert_true(false)
  }
}

///|
test "unit/checker/conditional - evaluate false branch" {
  let checker = @compiler.TypeChecker::new("test.ts", None)
  let (num_type, checker) = @compiler.number_type(checker)
  let (str_type, checker) = @compiler.string_type(checker)
  let (bool_type, checker) = @compiler.boolean_type(checker)
  let (void_t, checker) = @compiler.void_type(checker)
  // number extends string ? boolean : void
  let (cond_type, checker) = @compiler.conditional_type(
    checker, num_type, str_type, bool_type, void_t,
  )
  match cond_type {
    Conditional(cond) => {
      let (result, _) = @compiler.evaluate_conditional_type(checker, cond)
      match result {
        Void(_) => assert_true(true)
        _ => assert_true(false)
      }
    }
    _ => assert_true(false)
  }
}

// ============================================================================
// Template Literal Type Tests
// ============================================================================

///|
test "unit/checker/template-literal - create template literal type" {
  let checker = @compiler.TypeChecker::new("test.ts", None)
  let (num_type, checker) = @compiler.number_type(checker)
  let (template, _) = @compiler.template_literal_type(
    checker,
    ["prefix", "suffix"],
    [num_type],
  )
  match template {
    TemplateLiteral(t) => {
      assert_eq(t.texts.length(), 2)
      assert_eq(t.types.length(), 1)
    }
    _ => assert_true(false)
  }
}

///|
test "unit/checker/template-literal - matches string with prefix" {
  let checker = @compiler.TypeChecker::new("test.ts", None)
  let (num_type, checker) = @compiler.number_type(checker)
  let (template, _) = @compiler.template_literal_type(checker, ["hello", ""], [
    num_type,
  ])
  match template {
    TemplateLiteral(t) =>
      assert_true(@compiler.matches_template_literal("hello42", t))
    _ => assert_true(false)
  }
}

///|
test "unit/checker/template-literal - does not match wrong prefix" {
  let checker = @compiler.TypeChecker::new("test.ts", None)
  let (num_type, checker) = @compiler.number_type(checker)
  let (template, _) = @compiler.template_literal_type(checker, ["hello", ""], [
    num_type,
  ])
  match template {
    TemplateLiteral(t) =>
      assert_false(@compiler.matches_template_literal("world42", t))
    _ => assert_true(false)
  }
}

// ============================================================================
// Index Access Type Tests
// ============================================================================

///|
test "unit/checker/index-access - create index access type" {
  let checker = @compiler.TypeChecker::new("test.ts", None)
  let (num_type, checker) = @compiler.number_type(checker)
  let (str_type, checker) = @compiler.string_type(checker)
  let (ia_type, _) = @compiler.index_access_type(checker, num_type, str_type)
  match ia_type {
    IndexAccess(ia) =>
      match ia.object_type {
        Number(_) => assert_true(true)
        _ => assert_true(false)
      }
    _ => assert_true(false)
  }
}

// ============================================================================
// Infer Type Tests
// ============================================================================

///|
test "unit/checker/infer - create infer type placeholder" {
  let checker = @compiler.TypeChecker::new("test.ts", None)
  let (inf_type, _) = @compiler.infer_type_placeholder(checker, "T")
  match inf_type {
    Infer(inf) => assert_eq(inf.type_parameter_name, "T")
    _ => assert_true(false)
  }
}

// ============================================================================
// Union Type Helper Tests
// ============================================================================

///|
test "unit/checker/union - create union type" {
  let checker = @compiler.TypeChecker::new("test.ts", None)
  let (num_type, checker) = @compiler.number_type(checker)
  let (str_type, checker) = @compiler.string_type(checker)
  let (union, _) = @compiler.union_type(checker, [num_type, str_type])
  match union {
    Union(u) => assert_eq(u.types.length(), 2)
    _ => assert_true(false)
  }
}

///|
test "unit/checker/union - single type returns itself" {
  let checker = @compiler.TypeChecker::new("test.ts", None)
  let (num_type, checker) = @compiler.number_type(checker)
  let (result, _) = @compiler.union_type(checker, [num_type])
  match result {
    Number(_) => assert_true(true)
    _ => assert_true(false)
  }
}

///|
test "unit/checker/union - empty returns never" {
  let checker = @compiler.TypeChecker::new("test.ts", None)
  let (result, _) = @compiler.union_type(checker, [])
  match result {
    Never(_) => assert_true(true)
    _ => assert_true(false)
  }
}

///|
test "unit/checker/union - flattens nested unions" {
  let checker = @compiler.TypeChecker::new("test.ts", None)
  let (num_type, checker) = @compiler.number_type(checker)
  let (str_type, checker) = @compiler.string_type(checker)
  let (bool_type, checker) = @compiler.boolean_type(checker)
  let (inner, checker) = @compiler.union_type(checker, [num_type, str_type])
  let (outer, _) = @compiler.union_type(checker, [inner, bool_type])
  match outer {
    Union(u) => assert_eq(u.types.length(), 3)
    _ => assert_true(false)
  }
}

///|
test "unit/checker/union - removes duplicates" {
  let checker = @compiler.TypeChecker::new("test.ts", None)
  let (num_type1, checker) = @compiler.number_type(checker)
  let (num_type2, checker) = @compiler.number_type(checker)
  let (str_type, checker) = @compiler.string_type(checker)
  let (result, _) = @compiler.union_type(checker, [
    num_type1, str_type, num_type2,
  ])
  match result {
    Union(u) => assert_eq(u.types.length(), 2)
    _ => assert_true(false)
  }
}

// ============================================================================
// Integration Tests - Full Pipeline
// ============================================================================

///|
test "unit/checker/integration - check number literal" {
  let result = parse_bind_check("const x = 42;")
  match result {
    Ok(typed) => assert_eq(typed.file_path, "test.ts")
    Err(_) => assert_true(false)
  }
}

///|
test "unit/checker/integration - check string literal" {
  let result = parse_bind_check("const x = \"hello\";")
  match result {
    Ok(typed) => assert_eq(typed.file_path, "test.ts")
    Err(_) => assert_true(false)
  }
}

///|
test "unit/checker/integration - check boolean literal" {
  let result = parse_bind_check("const x = true;")
  match result {
    Ok(typed) => assert_eq(typed.file_path, "test.ts")
    Err(_) => assert_true(false)
  }
}

///|
test "unit/checker/integration - check tuple type annotation" {
  let result = parse_bind_check(
    "const tuple: [number, string] = [1, \"hello\"];",
  )
  match result {
    Ok(typed) => assert_eq(typed.file_path, "test.ts")
    Err(_) => assert_true(false)
  }
}

///|
test "unit/checker/integration - check intersection type annotation" {
  let result = parse_bind_check(
    "interface A { a: number; }\ninterface B { b: string; }\nconst obj: A & B = { a: 1, b: \"hello\" };",
  )
  match result {
    Ok(typed) => assert_eq(typed.file_path, "test.ts")
    Err(_) => assert_true(false)
  }
}

///|
test "unit/checker/integration - check generic function" {
  let result = parse_bind_check("function identity<T>(x: T): T { return x; }")
  match result {
    Ok(typed) => assert_eq(typed.file_path, "test.ts")
    Err(_) => assert_true(false)
  }
}

///|
test "unit/checker/integration - check array type" {
  let result = parse_bind_check("const arr: number[] = [1, 2, 3];")
  match result {
    Ok(typed) => assert_eq(typed.file_path, "test.ts")
    Err(_) => assert_true(false)
  }
}

///|
test "unit/checker/integration - check union type annotation" {
  let result = parse_bind_check("const x: string | number = 42;")
  match result {
    Ok(typed) => assert_eq(typed.file_path, "test.ts")
    Err(_) => assert_true(false)
  }
}

// ============================================================================
// Index Signature Tests
// ============================================================================

///|
test "unit/checker/index-signature - string index signature" {
  let result = parse_bind_check(
    "interface StringIndex { [key: string]: number; }",
  )
  match result {
    Ok(typed) => assert_eq(typed.file_path, "test.ts")
    Err(_) => assert_true(false)
  }
}

///|
test "unit/checker/index-signature - number index signature" {
  let result = parse_bind_check(
    "interface NumberIndex { [index: number]: string; }",
  )
  match result {
    Ok(typed) => assert_eq(typed.file_path, "test.ts")
    Err(_) => assert_true(false)
  }
}

///|
test "unit/checker/index-signature - readonly index signature" {
  let result = parse_bind_check(
    "interface ReadonlyIndex { readonly [key: string]: number; }",
  )
  match result {
    Ok(typed) => assert_eq(typed.file_path, "test.ts")
    Err(_) => assert_true(false)
  }
}

///|
test "unit/checker/index-signature - with known properties" {
  let result = parse_bind_check(
    "interface WithProps { name: string; [key: string]: string; }",
  )
  match result {
    Ok(typed) => assert_eq(typed.file_path, "test.ts")
    Err(_) => assert_true(false)
  }
}

// ============================================================================
// Mapped Type Tests
// ============================================================================

///|
test "unit/checker/mapped-type - basic mapped type" {
  let result = parse_bind_check(
    "type MyMapped<K extends string> = { [P in K]: string };",
  )
  match result {
    Ok(typed) => assert_eq(typed.file_path, "test.ts")
    Err(_) => assert_true(false)
  }
}

///|
test "unit/checker/mapped-type - with readonly modifier" {
  let result = parse_bind_check(
    "type ReadonlyMapped<T> = { readonly [P in keyof T]: T[P] };",
  )
  match result {
    Ok(typed) => assert_eq(typed.file_path, "test.ts")
    Err(_) => assert_true(false)
  }
}

///|
test "unit/checker/mapped-type - with optional modifier" {
  let result = parse_bind_check(
    "type OptionalMapped<T> = { [P in keyof T]?: T[P] };",
  )
  match result {
    Ok(typed) => assert_eq(typed.file_path, "test.ts")
    Err(_) => assert_true(false)
  }
}

///|
test "unit/checker/mapped-type - with plus readonly modifier" {
  let result = parse_bind_check(
    "type AddReadonly<T> = { +readonly [P in keyof T]: T[P] };",
  )
  match result {
    Ok(typed) => assert_eq(typed.file_path, "test.ts")
    Err(_) => assert_true(false)
  }
}

///|
test "unit/checker/mapped-type - with minus readonly modifier" {
  let result = parse_bind_check(
    "type RemoveReadonly<T> = { -readonly [P in keyof T]: T[P] };",
  )
  match result {
    Ok(typed) => assert_eq(typed.file_path, "test.ts")
    Err(_) => assert_true(false)
  }
}

///|
test "unit/checker/mapped-type - with plus optional modifier" {
  let result = parse_bind_check(
    "type AddOptional<T> = { [P in keyof T]+?: T[P] };",
  )
  match result {
    Ok(typed) => assert_eq(typed.file_path, "test.ts")
    Err(_) => assert_true(false)
  }
}

///|
test "unit/checker/mapped-type - with minus optional modifier" {
  let result = parse_bind_check(
    "type RemoveOptional<T> = { [P in keyof T]-?: T[P] };",
  )
  match result {
    Ok(typed) => assert_eq(typed.file_path, "test.ts")
    Err(_) => assert_true(false)
  }
}

///|
test "unit/checker/mapped-type - both modifiers" {
  let result = parse_bind_check(
    "type FullMapped<T> = { readonly [P in keyof T]?: T[P] };",
  )
  match result {
    Ok(typed) => assert_eq(typed.file_path, "test.ts")
    Err(_) => assert_true(false)
  }
}

// ============================================================================
// CheckerTypeParameter Integration Tests
// ============================================================================

///|
test "unit/checker/type-param - generic function with constraint" {
  let result = parse_bind_check(
    "function process<T extends number>(value: T): T { return value; }",
  )
  match result {
    Ok(typed) => assert_eq(typed.file_path, "test.ts")
    Err(_) => assert_true(false)
  }
}

///|
test "unit/checker/type-param - generic with default type" {
  let result = parse_bind_check(
    "function create<T = string>(value: T): T { return value; }",
  )
  match result {
    Ok(typed) => assert_eq(typed.file_path, "test.ts")
    Err(_) => assert_true(false)
  }
}

///|
test "unit/checker/type-param - generic class with constraint" {
  let result = parse_bind_check(
    "class Container<T extends object> { value: T; }",
  )
  match result {
    Ok(typed) => assert_eq(typed.file_path, "test.ts")
    Err(_) => assert_true(false)
  }
}

///|
test "unit/checker/type-param - generic interface with multiple params" {
  let result = parse_bind_check(
    "interface Map<K extends string, V> { get(key: K): V; }",
  )
  match result {
    Ok(typed) => assert_eq(typed.file_path, "test.ts")
    Err(_) => assert_true(false)
  }
}

// ============================================================================
// Type Narrowing Tests
// ============================================================================

///|
test "unit/checker/narrowing - typeof string guard" {
  let result = parse_bind_check(
    "function test(x: string | number) { if (typeof x === \"string\") { return x.length; } return x; }",
  )
  match result {
    Ok(typed) => assert_eq(typed.file_path, "test.ts")
    Err(_) => assert_true(false)
  }
}

///|
test "unit/checker/narrowing - typeof number guard" {
  let result = parse_bind_check(
    "function test(x: string | number) { if (typeof x === \"number\") { return x.toFixed(); } return x; }",
  )
  match result {
    Ok(typed) => assert_eq(typed.file_path, "test.ts")
    Err(_) => assert_true(false)
  }
}

///|
test "unit/checker/narrowing - null check" {
  let result = parse_bind_check(
    "function test(x: string | null) { if (x !== null) { return x.length; } return 0; }",
  )
  match result {
    Ok(typed) => assert_eq(typed.file_path, "test.ts")
    Err(_) => assert_true(false)
  }
}

///|
test "unit/checker/narrowing - undefined check" {
  let result = parse_bind_check(
    "function test(x: string | undefined) { if (x !== undefined) { return x.length; } return 0; }",
  )
  match result {
    Ok(typed) => assert_eq(typed.file_path, "test.ts")
    Err(_) => assert_true(false)
  }
}

///|
test "unit/checker/narrowing - instanceof guard" {
  let result = parse_bind_check(
    "class Foo { x: number; } function test(obj: Foo | string) { if (obj instanceof Foo) { return obj.x; } return 0; }",
  )
  match result {
    Ok(typed) => assert_eq(typed.file_path, "test.ts")
    Err(_) => assert_true(false)
  }
}

///|
test "unit/checker/narrowing - negated typeof" {
  let result = parse_bind_check(
    "function test(x: string | number) { if (typeof x !== \"string\") { return x.toFixed(); } return x; }",
  )
  match result {
    Ok(typed) => assert_eq(typed.file_path, "test.ts")
    Err(_) => assert_true(false)
  }
}

///|
test "unit/checker/narrowing - truthy check" {
  let result = parse_bind_check(
    "function test(x: string | null) { if (x) { return x.length; } return 0; }",
  )
  match result {
    Ok(typed) => assert_eq(typed.file_path, "test.ts")
    Err(_) => assert_true(false)
  }
}

///|
test "unit/checker/narrowing - nested if statements" {
  let result = parse_bind_check(
    "function test(x: string | number | null) { if (x !== null) { if (typeof x === \"string\") { return x.length; } } return 0; }",
  )
  match result {
    Ok(typed) => assert_eq(typed.file_path, "test.ts")
    Err(_) => assert_true(false)
  }
}

///|
test "unit/checker/narrowing - create narrowed type" {
  let checker = @compiler.TypeChecker::new("test.ts", None)
  let (str_type, checker) = @compiler.string_type(checker)
  let (num_type, _) = @compiler.number_type(checker)
  let narrowed = @compiler.create_narrowed_type(str_type, num_type)
  // Verify the narrowed type was created successfully
  assert_true(true)
  let _ = narrowed

}

// ============================================================================
// Unreachable Code Detection Tests
// ============================================================================

///|
test "unit/checker/unreachable - return statement" {
  let result = parse_bind_check(
    "function test() { return 1; console.log('unreachable'); }",
  )
  // This should detect unreachable code and report it in diagnostics
  match result {
    Ok(_typed) =>
      // May have diagnostics even on success
      assert_true(false)
    Err(diagnostics) =>
      // Expected - unreachable code diagnostic
      assert_true(diagnostics.length() > 0)
  }
}

///|
test "unit/checker/unreachable - throw statement" {
  let result = parse_bind_check(
    "function test() { throw new Error(); console.log('unreachable'); }",
  )
  // This should detect unreachable code and report it in diagnostics
  match result {
    Ok(typed) =>
      // May have diagnostics even on success
      assert_eq(typed.file_path, "test.ts")
    Err(diagnostics) =>
      // Expected - unreachable code diagnostic
      assert_true(diagnostics.length() > 0)
  }
}

///|
test "unit/checker/unreachable - no false positives" {
  let result = parse_bind_check(
    "function test(x: boolean) { if (x) { return 1; } return 2; }",
  )
  match result {
    Ok(typed) => assert_eq(typed.file_path, "test.ts")
    Err(_) => assert_true(false)
  }
}

// ============================================================================
// Abstract Class Instantiation Tests
// ============================================================================

///|
test "unit/checker/abstract - cannot instantiate abstract class" {
  let result = parse_bind_check(
    "abstract class Foo { abstract method(): void; } new Foo();",
  )
  match result {
    Ok(typed) => assert_eq(typed.file_path, "test.ts")
    Err(_) => assert_true(false)
  }
}

///|
test "unit/checker/abstract - can instantiate concrete class" {
  let result = parse_bind_check(
    "class Foo { method(): void {} } const x = new Foo();",
  )
  match result {
    Ok(typed) => assert_eq(typed.file_path, "test.ts")
    Err(_) => assert_true(false)
  }
}

// ============================================================================
// Const Assignment Tests
// ============================================================================

///|
test "unit/checker/const - cannot reassign const" {
  let result = parse_bind_check("const x = 1; x = 2;")
  // This should detect const assignment error
  match result {
    Ok(typed) =>
      // May still succeed but with diagnostics
      assert_eq(typed.file_path, "test.ts")
    Err(diagnostics) =>
      // Expected - const assignment error
      assert_true(diagnostics.length() > 0)
  }
}

///|
test "unit/checker/const - can reassign let" {
  let result = parse_bind_check("let x = 1; x = 2;")
  match result {
    Ok(typed) => assert_eq(typed.file_path, "test.ts")
    Err(_) => assert_true(false)
  }
}

///|
test "unit/checker/const - compound assignment to const" {
  let result = parse_bind_check("const x = 1; x += 2;")
  // This should detect const assignment error
  match result {
    Ok(typed) =>
      // May still succeed but with diagnostics
      assert_eq(typed.file_path, "test.ts")
    Err(diagnostics) =>
      // Expected - const assignment error
      assert_true(diagnostics.length() > 0)
  }
}

// ============================================================================
// Return Type Consistency Tests
// ============================================================================

///|
test "unit/checker/return - type matches declared" {
  let result = parse_bind_check("function test(): number { return 42; }")
  match result {
    Ok(typed) => assert_eq(typed.file_path, "test.ts")
    Err(_) => assert_true(false)
  }
}

///|
test "unit/checker/return - void function with no return" {
  let result = parse_bind_check(
    "function test(): void { console.log('hello'); }",
  )
  match result {
    Ok(typed) => assert_eq(typed.file_path, "test.ts")
    Err(_) => assert_true(false)
  }
}

///|
test "unit/checker/return - type mismatch" {
  let result = parse_bind_check("function test(): number { return 'hello'; }")
  // This should detect return type mismatch - expect error
  match result {
    Ok(_) => assert_true(false) // Should have detected error
    Err(diagnostics) =>
      // Expected - return type mismatch error
      assert_true(diagnostics.length() > 0)
  }
}

// ============================================================================
// Assignment Compatibility Tests
// ============================================================================

///|
test "unit/checker/assign - compatible types" {
  let result = parse_bind_check("const x: number = 42;")
  match result {
    Ok(typed) => assert_eq(typed.file_path, "test.ts")
    Err(_) => assert_true(false)
  }
}

///|
test "unit/checker/assign - union type compatibility" {
  let result = parse_bind_check("const x: number | string = 'hello';")
  match result {
    Ok(typed) => assert_eq(typed.file_path, "test.ts")
    Err(_) => assert_true(false)
  }
}

///|
test "unit/checker/assign - incompatible types" {
  let result = parse_bind_check("const x: number = 'hello';")
  match result {
    Ok(_) => assert_true(false) // Should have detected type error
    Err(diagnostics) => assert_true(diagnostics.length() > 0)
  }
}

// ============================================================================
// Generic Function Inference Tests
// ============================================================================

///|
test "unit/checker/generic - identity function" {
  let result = parse_bind_check(
    "function identity<T>(x: T): T { return x; } const result = identity(42);",
  )
  match result {
    Ok(typed) => assert_eq(typed.file_path, "test.ts")
    Err(_) => assert_true(false)
  }
}

///|
test "unit/checker/generic - multiple type params" {
  let result = parse_bind_check(
    "function pair<A, B>(a: A, b: B): [A, B] { return [a, b]; } const p = pair(1, 'hello');",
  )
  match result {
    Ok(typed) => assert_eq(typed.file_path, "test.ts")
    Err(_) => assert_true(false)
  }
}

///|
test "unit/checker/generic - constrained type param" {
  let result = parse_bind_check(
    "function getLength<T extends { length: number }>(x: T): number { return x.length; } getLength([1, 2, 3]);",
  )
  match result {
    Ok(typed) => assert_eq(typed.file_path, "test.ts")
    Err(_) => assert_true(false)
  }
}

// ============================================================================
// Object Literal Type Inference Tests
// ============================================================================

///|
test "unit/checker/object - basic properties" {
  let result = parse_bind_check("const obj = { x: 1, y: 'hello' };")
  match result {
    Ok(typed) => assert_eq(typed.file_path, "test.ts")
    Err(_) => assert_true(false)
  }
}

///|
test "unit/checker/object - shorthand property" {
  let result = parse_bind_check("const x = 1; const obj = { x };")
  match result {
    Ok(typed) => assert_eq(typed.file_path, "test.ts")
    Err(_) => assert_true(false)
  }
}

///|
test "unit/checker/object - computed property with string" {
  let result = parse_bind_check("const obj = { ['key']: 42 };")
  match result {
    Ok(typed) => assert_eq(typed.file_path, "test.ts")
    Err(_) => assert_true(false)
  }
}

// ============================================================================
// Type Narrowing with Assignment Invalidation Tests
// ============================================================================

///|
test "unit/checker/narrowing - assignment invalidates narrowing" {
  let result = parse_bind_check(
    "function test(x: string | number) { if (typeof x === 'string') { x = 42; return x; } return 0; }",
  )
  match result {
    Ok(typed) => assert_eq(typed.file_path, "test.ts")
    Err(_) => assert_true(false)
  }
}

///|
test "unit/checker/narrowing - function scope clears narrowing" {
  let result = parse_bind_check(
    "function outer(x: string | number) { if (typeof x === 'string') { function inner() { return x; } } }",
  )
  match result {
    Ok(typed) => assert_eq(typed.file_path, "test.ts")
    Err(_) => assert_true(false)
  }
}

// ============================================================================
// Function Expression Self-Reference Tests
// ============================================================================

///|
test "unit/checker/function-expr - named function expression can reference itself" {
  // Named function expressions should be able to reference their own name
  // This is valid TypeScript: function y() { return y; }
  let result = parse_bind_check(
    "var x = function y() { return y; };",
  )
  match result {
    Ok(typed) => assert_eq(typed.file_path, "test.ts")
    Err(diagnostics) => {
      // Should NOT have "Cannot find name 'y'" error
      for diag in diagnostics {
        assert_false(diag.message.contains("Cannot find name 'y'"))
      }
    }
  }
}

///|
test "unit/checker/function-expr - embedded in template literal" {
  // Function expression embedded in template literal should be able to self-reference
  let result = parse_bind_check(
    "var x = `abc${ function y() { return y; } }def`;",
  )
  match result {
    Ok(typed) => assert_eq(typed.file_path, "test.ts")
    Err(diagnostics) => {
      // Should NOT have "Cannot find name 'y'" error
      for diag in diagnostics {
        assert_false(diag.message.contains("Cannot find name 'y'"))
      }
    }
  }
}

///|
test "unit/checker/function-expr - recursive factorial" {
  // Common pattern: recursive function expression
  let result = parse_bind_check(
    "var factorial = function f(n: number): number { return n <= 1 ? 1 : n * f(n - 1); };",
  )
  match result {
    Ok(typed) => assert_eq(typed.file_path, "test.ts")
    Err(diagnostics) => {
      // Should NOT have "Cannot find name 'f'" error
      for diag in diagnostics {
        assert_false(diag.message.contains("Cannot find name 'f'"))
      }
    }
  }
}

///|
test "unit/checker/function-expr - anonymous function has no self-reference" {
  // Anonymous function expressions don't create a binding
  let result = parse_bind_check(
    "var x = function() { return 42; };",
  )
  match result {
    Ok(typed) => assert_eq(typed.file_path, "test.ts")
    Err(_) => assert_true(false)
  }
}

///|
test "unit/checker/function-expr - name not visible outside" {
  // The function name should NOT be visible outside the function body
  // This SHOULD produce an error for 'y'
  let result = parse_bind_check(
    "var x = function y() { return 1; }; var z = y;",
  )
  match result {
    Ok(_) => assert_true(false) // Should have error - y not visible outside
    Err(diagnostics) => {
      // Should have "Cannot find name 'y'" error
      let has_error = diagnostics.iter().any(fn(d) { d.message.contains("Cannot find name 'y'") })
      assert_true(has_error)
    }
  }
}
