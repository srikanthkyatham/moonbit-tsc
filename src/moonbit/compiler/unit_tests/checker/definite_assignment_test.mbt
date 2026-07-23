// Tests for definite assignment analysis:
// - TS2564: Property '{0}' has no initializer and is not definitely assigned
//   in the constructor (strictPropertyInitialization)
// - TS2454: Variable '{0}' is used before being assigned (strictNullChecks)
//
// Both diagnostics are strict-mode only. The tests enable strict mode through
// the file-level `// @strict: true` compiler directive, mirroring the
// TypeScript conformance suite.

// ============================================================================
// TS2564: strictPropertyInitialization
// ============================================================================

///|
test "TS2564 - uninitialized property reported under strict" {
  let result = parse_bind_check_errors(
    (
      #|// @strict: true
      #|class C {
      #|  a: number;
      #|}
    ),
  )
  match result {
    Ok(_) => fail("Expected TS2564")
    Err(diagnostics) => assert_true(has_diagnostic_code(diagnostics, 2564))
  }
}

///|
test "TS2564 - reported by default (conformance baselines are strict)" {
  let result = parse_bind_check_errors(
    (
      #|class C {
      #|  a: number;
      #|}
    ),
  )
  match result {
    Ok(_) => fail("Expected TS2564 - strict is the default")
    Err(diagnostics) => assert_true(has_diagnostic_code(diagnostics, 2564))
  }
}

///|
test "TS2564 - not reported with strict false" {
  let result = parse_bind_check_errors(
    (
      #|// @strict: false
      #|class C {
      #|  a: number;
      #|}
    ),
  )
  match result {
    Ok(_) => ()
    Err(diagnostics) => assert_true(!(has_diagnostic_code(diagnostics, 2564)))
  }
}

///|
test "TS2564 - initializer suppresses error" {
  let result = parse_bind_check_errors(
    (
      #|// @strict: true
      #|class C {
      #|  a: number = 1;
      #|}
    ),
  )
  match result {
    Ok(_) => ()
    Err(diagnostics) => assert_true(!(has_diagnostic_code(diagnostics, 2564)))
  }
}

///|
test "TS2564 - undefined in union type suppresses error" {
  let result = parse_bind_check_errors(
    (
      #|// @strict: true
      #|class C {
      #|  a: number | undefined;
      #|}
    ),
  )
  match result {
    Ok(_) => ()
    Err(diagnostics) => assert_true(!(has_diagnostic_code(diagnostics, 2564)))
  }
}

///|
test "TS2564 - optional property suppresses error" {
  let result = parse_bind_check_errors(
    (
      #|// @strict: true
      #|class C {
      #|  a?: number;
      #|}
    ),
  )
  match result {
    Ok(_) => ()
    Err(diagnostics) => assert_true(!(has_diagnostic_code(diagnostics, 2564)))
  }
}

///|
test "TS2564 - any type suppresses error" {
  let result = parse_bind_check_errors(
    (
      #|// @strict: true
      #|class C {
      #|  a: any;
      #|}
    ),
  )
  match result {
    Ok(_) => ()
    Err(diagnostics) => assert_true(!(has_diagnostic_code(diagnostics, 2564)))
  }
}

///|
test "TS2564 - constructor assignment suppresses error" {
  let result = parse_bind_check_errors(
    (
      #|// @strict: true
      #|class C {
      #|  a: number;
      #|  constructor() {
      #|    this.a = 1;
      #|  }
      #|}
    ),
  )
  match result {
    Ok(_) => ()
    Err(diagnostics) => assert_true(!(has_diagnostic_code(diagnostics, 2564)))
  }
}

///|
test "TS2564 - conditional constructor assignment counts (conservative)" {
  // tsc would report this (assignment only on one path); we are deliberately
  // conservative and accept ANY constructor assignment to avoid false positives
  let result = parse_bind_check_errors(
    (
      #|// @strict: true
      #|class C {
      #|  a: number;
      #|  constructor(cond: boolean) {
      #|    if (cond) {
      #|      this.a = 1;
      #|    }
      #|  }
      #|}
    ),
  )
  match result {
    Ok(_) => ()
    Err(diagnostics) => assert_true(!(has_diagnostic_code(diagnostics, 2564)))
  }
}

///|
test "TS2564 - assignment in method does NOT count" {
  let result = parse_bind_check_errors(
    (
      #|// @strict: true
      #|class C {
      #|  a: number;
      #|  init(): void {
      #|    this.a = 1;
      #|  }
      #|}
    ),
  )
  match result {
    Ok(_) => fail("Expected TS2564 - method assignments don't count")
    Err(diagnostics) => assert_true(has_diagnostic_code(diagnostics, 2564))
  }
}

///|
test "TS2564 - static, abstract and declare properties exempt" {
  let result = parse_bind_check_errors(
    (
      #|// @strict: true
      #|abstract class C {
      #|  static s: number;
      #|  abstract x: number;
      #|  declare y: number;
      #|}
    ),
  )
  match result {
    Ok(_) => ()
    Err(diagnostics) => assert_true(!(has_diagnostic_code(diagnostics, 2564)))
  }
}

///|
test "TS2564 - ambient (declare) class exempt" {
  let result = parse_bind_check_errors(
    (
      #|// @strict: true
      #|declare class C {
      #|  a: number;
      #|}
    ),
  )
  match result {
    Ok(_) => ()
    Err(diagnostics) => assert_true(!(has_diagnostic_code(diagnostics, 2564)))
  }
}

///|
test "TS2564 - class type annotation is checked" {
  let result = parse_bind_check_errors(
    (
      #|// @strict: true
      #|class Dep {
      #|  v: string = "";
      #|}
      #|class C {
      #|  dep: Dep;
      #|}
    ),
  )
  match result {
    Ok(_) => fail("Expected TS2564 for property with class type")
    Err(diagnostics) => assert_true(has_diagnostic_code(diagnostics, 2564))
  }
}

///|
test "TS2564 - type alias including undefined exempt" {
  let result = parse_bind_check_errors(
    (
      #|// @strict: true
      #|type MaybeNum = number | undefined;
      #|class C {
      #|  a: MaybeNum;
      #|}
    ),
  )
  match result {
    Ok(_) => ()
    Err(diagnostics) => assert_true(!(has_diagnostic_code(diagnostics, 2564)))
  }
}

///|
test "TS2564 - strictPropertyInitialization false disables check" {
  let result = parse_bind_check_errors(
    (
      #|// @strict: true
      #|// @strictPropertyInitialization: false
      #|class C {
      #|  a: number;
      #|}
    ),
  )
  match result {
    Ok(_) => ()
    Err(diagnostics) => assert_true(!(has_diagnostic_code(diagnostics, 2564)))
  }
}

// ============================================================================
// TS2454: Variable used before being assigned
// ============================================================================

///|
test "TS2454 - use before any assignment reported under strict" {
  let result = parse_bind_check_errors(
    (
      #|// @strict: true
      #|let x: number;
      #|console.log(x);
    ),
  )
  match result {
    Ok(_) => fail("Expected TS2454")
    Err(diagnostics) => assert_true(has_diagnostic_code(diagnostics, 2454))
  }
}

///|
test "TS2454 - reported by default (conformance baselines are strict)" {
  let result = parse_bind_check_errors(
    (
      #|let x: number;
      #|console.log(x);
    ),
  )
  match result {
    Ok(_) => fail("Expected TS2454 - strict is the default")
    Err(diagnostics) => assert_true(has_diagnostic_code(diagnostics, 2454))
  }
}

///|
test "TS2454 - not reported with strict false" {
  let result = parse_bind_check_errors(
    (
      #|// @strict: false
      #|let x: number;
      #|console.log(x);
    ),
  )
  match result {
    Ok(_) => ()
    Err(diagnostics) => assert_true(!(has_diagnostic_code(diagnostics, 2454)))
  }
}

///|
test "TS2454 - assignment before use is fine" {
  let result = parse_bind_check_errors(
    (
      #|// @strict: true
      #|let x: number;
      #|x = 1;
      #|console.log(x);
    ),
  )
  match result {
    Ok(_) => ()
    Err(diagnostics) => assert_true(!(has_diagnostic_code(diagnostics, 2454)))
  }
}

///|
test "TS2454 - assignment in only one if branch reported" {
  let result = parse_bind_check_errors(
    (
      #|// @strict: true
      #|declare const cond: boolean;
      #|let x: number;
      #|if (cond) {
      #|  x = 1;
      #|}
      #|console.log(x);
    ),
  )
  match result {
    Ok(_) => fail("Expected TS2454 - assignment only on one path")
    Err(diagnostics) => assert_true(has_diagnostic_code(diagnostics, 2454))
  }
}

///|
test "TS2454 - assignment in both if branches is fine" {
  let result = parse_bind_check_errors(
    (
      #|// @strict: true
      #|declare const cond: boolean;
      #|let x: number;
      #|if (cond) {
      #|  x = 1;
      #|} else {
      #|  x = 2;
      #|}
      #|console.log(x);
    ),
  )
  match result {
    Ok(_) => ()
    Err(diagnostics) => assert_true(!(has_diagnostic_code(diagnostics, 2454)))
  }
}

///|
test "TS2454 - assignment in one branch with terminating else is fine" {
  let result = parse_bind_check_errors(
    (
      #|// @strict: true
      #|declare const cond: boolean;
      #|let x: number;
      #|if (cond) {
      #|  x = 1;
      #|} else {
      #|  throw new Error("nope");
      #|}
      #|console.log(x);
    ),
  )
  match result {
    Ok(_) => ()
    Err(diagnostics) => assert_true(!(has_diagnostic_code(diagnostics, 2454)))
  }
}

///|
test "TS2454 - definite assignment assertion suppresses error" {
  let result = parse_bind_check_errors(
    (
      #|// @strict: true
      #|let x!: number;
      #|console.log(x);
    ),
  )
  match result {
    Ok(_) => ()
    Err(diagnostics) => assert_true(!(has_diagnostic_code(diagnostics, 2454)))
  }
}

///|
test "TS2454 - undefined in union type suppresses error" {
  let result = parse_bind_check_errors(
    (
      #|// @strict: true
      #|let x: number | undefined;
      #|console.log(x);
    ),
  )
  match result {
    Ok(_) => ()
    Err(diagnostics) => assert_true(!(has_diagnostic_code(diagnostics, 2454)))
  }
}

///|
test "TS2454 - type alias including undefined suppresses error" {
  let result = parse_bind_check_errors(
    (
      #|// @strict: true
      #|type MaybeNum = number | undefined;
      #|let x: MaybeNum;
      #|console.log(x);
    ),
  )
  match result {
    Ok(_) => ()
    Err(diagnostics) => assert_true(!(has_diagnostic_code(diagnostics, 2454)))
  }
}

///|
test "TS2454 - var is not reported" {
  let result = parse_bind_check_errors(
    (
      #|// @strict: true
      #|var x: number;
      #|console.log(x);
    ),
  )
  match result {
    Ok(_) => ()
    Err(diagnostics) => assert_true(!(has_diagnostic_code(diagnostics, 2454)))
  }
}

///|
test "TS2454 - use inside nested function is not reported" {
  let result = parse_bind_check_errors(
    (
      #|// @strict: true
      #|let x: number;
      #|function f(): number {
      #|  return x;
      #|}
      #|x = 1;
      #|f();
    ),
  )
  match result {
    Ok(_) => ()
    Err(diagnostics) => assert_true(!(has_diagnostic_code(diagnostics, 2454)))
  }
}

///|
test "TS2454 - variable local to function is reported" {
  let result = parse_bind_check_errors(
    (
      #|// @strict: true
      #|function f(): number {
      #|  let y: number;
      #|  return y;
      #|}
    ),
  )
  match result {
    Ok(_) => fail("Expected TS2454 inside function body")
    Err(diagnostics) => assert_true(has_diagnostic_code(diagnostics, 2454))
  }
}

///|
test "TS2454 - shadowed variable in inner block does not poison outer" {
  let result = parse_bind_check_errors(
    (
      #|// @strict: true
      #|let x: number = 1;
      #|{
      #|  let x: number;
      #|  x = 2;
      #|}
      #|console.log(x);
    ),
  )
  match result {
    Ok(_) => ()
    Err(diagnostics) => assert_true(!(has_diagnostic_code(diagnostics, 2454)))
  }
}

///|
test "TS2454 - assignment inside loop counts (conservative)" {
  // tsc reports this (loop may run zero times); we deliberately treat loop
  // body assignments as definite to avoid false positives
  let result = parse_bind_check_errors(
    (
      #|// @strict: true
      #|declare const cond: boolean;
      #|let x: number;
      #|while (cond) {
      #|  x = 1;
      #|}
      #|console.log(x);
    ),
  )
  match result {
    Ok(_) => ()
    Err(diagnostics) => assert_true(!(has_diagnostic_code(diagnostics, 2454)))
  }
}

///|
test "TS2454 - declare (ambient) variable not reported" {
  let result = parse_bind_check_errors(
    (
      #|// @strict: true
      #|declare let x: number;
      #|console.log(x);
    ),
  )
  match result {
    Ok(_) => ()
    Err(diagnostics) => assert_true(!(has_diagnostic_code(diagnostics, 2454)))
  }
}

///|
test "TS2454 - strictNullChecks false disables check" {
  let result = parse_bind_check_errors(
    (
      #|// @strict: true
      #|// @strictNullChecks: false
      #|let x: number;
      #|console.log(x);
    ),
  )
  match result {
    Ok(_) => ()
    Err(diagnostics) => assert_true(!(has_diagnostic_code(diagnostics, 2454)))
  }
}
