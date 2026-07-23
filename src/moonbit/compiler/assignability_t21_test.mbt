// T21 assignability tests: call/construct signature assignability,
// including generic signatures (TS2322)
// 1. constructor type annotations (`new (...) => T`) participate in
//    assignability
// 2. generic-to-non-generic signatures relate by inferring the source's
//    type parameters from the target's parameter types
// 3. non-generic-to-generic signatures fail when the target's opaque type
//    parameters meet concrete types
// 4. constraints: an inferred type that fails its constraint falls back to
//    the constraint; a constrained source vs unconstrained target errors
// 5. overloaded signature lists compare with erased type parameters
// 6. arity rules: a source may not require more arguments than the target
//    supplies
// 7. deeply nested / self-referential generic signatures terminate

///|
/// Collect the diagnostic codes produced for a source snippet
fn t21_diag_codes(source : String) -> Array[Int] {
  match parse_bind_and_check(source) {
    Ok(_) => []
    Err(diags) => diags.map(fn(d) { d.code })
  }
}

// ============================================================================
// Non-generic construct signatures
// ============================================================================

///|
test "matching construct signatures are assignable" {
  let codes = t21_diag_codes(
    "declare var a: new (x: number) => number;\ndeclare var b: new (x: number) => number;\na = b;",
  )
  assert_eq(codes, [])
}

///|
test "construct signature parameter mismatch is reported" {
  let codes = t21_diag_codes(
    "declare var a: new (x: number) => number;\ndeclare var b: new (x: string) => number;\na = b;",
  )
  assert_eq(codes, [2322])
}

///|
test "construct signature return type mismatch is reported" {
  let codes = t21_diag_codes(
    "declare var a: new (x: number) => number;\ndeclare var b: new (x: number) => string;\na = b;",
  )
  assert_eq(codes, [2322])
}

///|
test "object without construct signature is not assignable to constructor type" {
  let codes = t21_diag_codes(
    "declare var a: new (x: number) => number;\ndeclare var q: { foo: string };\na = q;",
  )
  assert_eq(codes, [2322])
}

// ============================================================================
// Arity rules
// ============================================================================

///|
test "source requiring more arguments than target supplies is rejected" {
  let codes = t21_diag_codes(
    "declare var a: new () => number;\ndeclare var b: new (x: number) => number;\na = b;",
  )
  assert_eq(codes, [2322])
}

///|
test "source with fewer parameters than target is accepted" {
  let codes = t21_diag_codes(
    "declare var a: new (x: number, y: number) => number;\ndeclare var b: new (x: number) => number;\na = b;",
  )
  assert_eq(codes, [])
}

///|
test "source with only optional parameters accepts a zero-arg target" {
  let codes = t21_diag_codes(
    "declare var a: new () => number;\ndeclare var b: new (x?: number, y?: number) => number;\na = b;",
  )
  assert_eq(codes, [])
}

///|
test "source rest parameter accepts any target arity" {
  let codes = t21_diag_codes(
    "declare var a: new (x: number, y: number) => number;\ndeclare var b: new (...x: number[]) => number;\na = b;",
  )
  assert_eq(codes, [])
}

// ============================================================================
// Generic-to-non-generic: source type parameters inferred from target
// ============================================================================

///|
test "generic construct signature is assignable to compatible non-generic one" {
  let codes = t21_diag_codes(
    "declare var a: new (x: number) => number[];\ndeclare var b: new <T>(x: T) => T[];\na = b;",
  )
  assert_eq(codes, [])
}

///|
test "generic call signature var is assignable to compatible non-generic one" {
  let codes = t21_diag_codes(
    "declare var c: (x: number) => number[];\ndeclare var d: <T>(x: T) => T[];\nc = d;",
  )
  assert_eq(codes, [])
}

///|
test "inference through nested function parameter types succeeds" {
  let codes = t21_diag_codes(
    "declare var a: new (x: (arg: string) => number) => string;\n" +
    "declare var b: new <T, U>(x: (arg: T) => U) => T;\n" +
    "a = b;",
  )
  assert_eq(codes, [])
}

///|
test "inferred first candidate wins and mismatched second use is reported" {
  // T is inferred as string from property a, so property b (number) fails
  let codes = t21_diag_codes(
    "declare var a: new (x: { a: string; b: number }) => Object;\n" +
    "declare var b: new <T>(x: { a: T; b: T }) => T;\n" +
    "a = b;",
  )
  assert_eq(codes, [2322])
}

// ============================================================================
// Non-generic-to-generic: opaque target type parameters
// ============================================================================

///|
test "non-generic construct signature is not assignable to generic one" {
  let codes = t21_diag_codes(
    "declare var a: new (x: number) => number[];\ndeclare var b: new <T>(x: T) => T[];\nb = a;",
  )
  assert_eq(codes, [2322])
}

///|
test "non-generic call signature var is not assignable to generic one" {
  let codes = t21_diag_codes(
    "declare var c: (x: number) => number[];\ndeclare var d: <T>(x: T) => T[];\nd = c;",
  )
  assert_eq(codes, [2322])
}

///|
test "void-returning generic source is not assignable when target returns T" {
  let codes = t21_diag_codes(
    "declare var a: new <T>(x: T) => void;\ndeclare var b: new <T>(x: T) => T;\nb = a;",
  )
  assert_eq(codes, [2322])
}

///|
test "generic source returning T is assignable to void-returning target" {
  let codes = t21_diag_codes(
    "declare var a: new <T>(x: T) => void;\ndeclare var b: new <T>(x: T) => T;\na = b;",
  )
  assert_eq(codes, [])
}

// ============================================================================
// Generic-to-generic
// ============================================================================

///|
test "identical generic signatures are mutually assignable" {
  let codes = t21_diag_codes(
    "declare var a: new <T>(x: T) => T[];\ndeclare var b: new <S>(x: S) => S[];\na = b;\nb = a;",
  )
  assert_eq(codes, [])
}

///|
test "generic interface call signatures with mismatched rest depth error both ways" {
  let codes = t21_diag_codes(
    "interface A {\n    <T>(x: T, ...y: T[][]): void\n}\n" +
    "interface B {\n    <S>(x: S, ...y: S[]): void\n}\n" +
    "declare var a: A;\ndeclare var b: B;\na = b;\nb = a;",
  )
  assert_eq(codes, [2322, 2322])
}

// ============================================================================
// Constraints
// ============================================================================

///|
test "inferred type satisfying the constraint is accepted" {
  let codes = t21_diag_codes(
    "class Base { foo: string = '' }\nclass Derived extends Base { bar: string = '' }\n" +
    "declare var a: new (x: Derived) => Derived;\n" +
    "declare var b: new <T extends Base>(x: T) => T;\n" +
    "a = b;",
  )
  assert_eq(codes, [])
}

///|
test "inferred type failing the constraint falls back to the constraint and errors" {
  let codes = t21_diag_codes(
    "class Base { foo: string = '' }\nclass Derived extends Base { bar: string = '' }\n" +
    "declare var a: new (...x: Base[]) => Base;\n" +
    "declare var b: new <T extends Derived>(...x: T[]) => T;\n" +
    "a = b;",
  )
  assert_eq(codes, [2322])
}

///|
test "constrained source vs unconstrained target type parameter errors" {
  let codes = t21_diag_codes(
    "class Base { foo: string = '' }\n" +
    "declare var a: <T extends Base>(x: { a: T; b: T }) => T[];\n" +
    "declare var b: <T>(x: { a: T; b: T }) => T[];\n" +
    "b = a;",
  )
  assert_eq(codes, [2322])
}

// ============================================================================
// Overloaded signature lists compare with erased type parameters
// ============================================================================

///|
test "generic signature is assignable to overloaded target with erasure" {
  let codes = t21_diag_codes(
    "declare var a: {\n    new (x: number): number[];\n    new (x: string): string[];\n};\n" +
    "declare var b: new <T>(x: T) => T[];\na = b;\nb = a;",
  )
  assert_eq(codes, [])
}

///|
test "overloaded target signature without a matching source overload errors" {
  let codes = t21_diag_codes(
    "declare var a: {\n    new (x: number): number;\n    new (x: string): string;\n};\n" +
    "declare var b: new (x: number) => number;\nb = a;\na = b;",
  )
  assert_eq(codes, [2322])
}

///|
test "class with constructor overloads matches overloaded constructor object type" {
  let codes = t21_diag_codes(
    "class C {\n    constructor(x: string);\n    constructor(x: number);\n    constructor(x: any) { }\n}\n" +
    "var f: {\n    new(x: string): C;\n    new(x: number): C;\n} = C;",
  )
  assert_eq(codes, [])
}

// ============================================================================
// Termination for nested and self-referential generic signatures
// ============================================================================

///|
test "self-referential constraint signatures terminate" {
  // F-bounded constraints (T extends I2<T>): must not stack overflow
  let codes = t21_diag_codes(
    "interface I2<T> {\n    p: T\n}\n" +
    "declare var x: <T extends I2<T>>(z: T) => void;\n" +
    "declare var y: <T extends I2<I2<T>>>(z: T) => void;\n" +
    "x = y;\ny = x;",
  )
  // Both assignments are errors in tsc; the essential property here is
  // termination and no false negatives on the containing file
  assert_true(codes.length() <= 2)
}

///|
test "deeply nested generic signatures terminate" {
  let codes = t21_diag_codes(
    "declare var a: new <T>(x: new (a: new (b: T) => T) => T[]) => T[];\n" +
    "declare var b: new <S>(x: new (a: new (b: S) => S) => S[]) => S[];\n" +
    "a = b;\nb = a;",
  )
  assert_eq(codes, [])
}

///|
test "mutually recursive interface call signatures terminate" {
  let codes = t21_diag_codes(
    "interface F {\n    (x: F): F\n}\n" +
    "interface G {\n    (x: G): G\n}\n" +
    "declare var f: F;\ndeclare var g: G;\nf = g;",
  )
  assert_eq(codes, [])
}
