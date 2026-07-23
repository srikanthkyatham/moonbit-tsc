///| Unit tests for duplicate names in object literals
///| Plain property duplicates are TS1117 (on the duplicate occurrence only);
///| duplicate get/set accessors are TS2300 (on both occurrences) - matches tsc

///|
fn count_code(diagnostics : Array[@compiler.Diagnostic], code : Int) -> Int {
  diagnostics.iter().filter(fn(d) { d.code == code }).count()
}

///|
fn duplicate_prop_diagnostics(source : String) -> Array[@compiler.Diagnostic] {
  match parse_bind_check_errors(source) {
    Ok(_) => []
    Err(diagnostics) => diagnostics
  }
}

test "TS1117: Duplicate regular properties trigger one error on the duplicate" {
  let source =
    #|var obj = {
    #|    foo: 1,
    #|    bar: 2,
    #|    foo: 3
    #|};
  let diagnostics = duplicate_prop_diagnostics(source)
  // tsc reports TS1117 on the duplicate occurrence only (not the first)
  assert_eq(count_code(diagnostics, 1117), 1)
  assert_eq(count_code(diagnostics, 2300), 0)
}

test "TS2300: Duplicate getters should trigger error" {
  let source =
    #|var obj = {
    #|    get foo() { return 1; },
    #|    get bar() { return 2; },
    #|    get foo() { return 3; }
    #|};
  let diagnostics = duplicate_prop_diagnostics(source)
  // tsc reports TS2300 on both occurrences of the duplicated getter
  assert_eq(count_code(diagnostics, 2300), 2)
}

test "TS2300: Duplicate setters should trigger error" {
  let source =
    #|var obj = {
    #|    set foo(v: number) { },
    #|    set bar(v: number) { },
    #|    set foo(v: number) { }
    #|};
  let diagnostics = duplicate_prop_diagnostics(source)
  assert_eq(count_code(diagnostics, 2300), 2)
}

test "No error: getter/setter pair with same name" {
  let source =
    #|var obj = {
    #|    get foo() { return 1; },
    #|    set foo(v: number) { }
    #|};
  let diagnostics = duplicate_prop_diagnostics(source)
  assert_eq(count_code(diagnostics, 2300), 0)
  assert_eq(count_code(diagnostics, 1117), 0)
}

test "TS1117: Three duplicate properties trigger two errors" {
  let source =
    #|var obj = {
    #|    foo: 1,
    #|    foo: 2,
    #|    foo: 3
    #|};
  let diagnostics = duplicate_prop_diagnostics(source)
  // TS1117 on each duplicate occurrence (2nd and 3rd)
  assert_eq(count_code(diagnostics, 1117), 2)
  assert_eq(count_code(diagnostics, 2300), 0)
}

test "TS1117: Duplicate shorthand methods trigger error" {
  let source =
    #|var obj = {
    #|    m() { return 1; },
    #|    m() { return 2; }
    #|};
  let diagnostics = duplicate_prop_diagnostics(source)
  assert_eq(count_code(diagnostics, 1117), 1)
}

test "No error: Non-duplicate properties" {
  let source =
    #|var obj = {
    #|    foo: 1,
    #|    bar: 2,
    #|    baz: 3
    #|};
  let diagnostics = duplicate_prop_diagnostics(source)
  assert_eq(count_code(diagnostics, 2300), 0)
  assert_eq(count_code(diagnostics, 1117), 0)
}

test "No error: Different property types" {
  let source =
    #|var obj = {
    #|    foo: 1,
    #|    bar: "hello",
    #|    baz: true
    #|};
  let diagnostics = duplicate_prop_diagnostics(source)
  assert_eq(count_code(diagnostics, 2300), 0)
  assert_eq(count_code(diagnostics, 1117), 0)
}

test "TS2300: Conformance test computedPropertyNames49_ES5" {
  let source =
    #|var x = {
    #|    p1: 10,
    #|    get [1 + 1]() {
    #|        throw 10;
    #|    },
    #|    get [1 + 1]() {
    #|        return 10;
    #|    },
    #|    set [1 + 1]() {
    #|        throw 10;
    #|    },
    #|    get foo() {
    #|        if (1 == 1) {
    #|            return 10;
    #|        }
    #|    },
    #|    get foo() {
    #|        if (2 == 2) {
    #|            return 20;
    #|        }
    #|    },
    #|    p2: 20
    #|};
  let diagnostics = duplicate_prop_diagnostics(source)
  assert_eq(count_code(diagnostics, 2300), 2)
}

test "TS2300: Conformance test computedPropertyNames50_ES5" {
  let source =
    #|var x = {
    #|    p1: 10,
    #|    get foo() {
    #|        if (1 == 1) {
    #|            return 10;
    #|        }
    #|    },
    #|    get [1 + 1]() {
    #|        throw 10;
    #|    },
    #|    set [1 + 1]() {
    #|        throw 10;
    #|    },
    #|    get [1 + 1]() {
    #|        return 10;
    #|    },
    #|    get foo() {
    #|        if (2 == 2) {
    #|            return 20;
    #|        }
    #|    },
    #|    p2: 20
    #|};
  let diagnostics = duplicate_prop_diagnostics(source)
  assert_eq(count_code(diagnostics, 2300), 2)
}

// ============================================================================
// Declaration merging: legal merges must NOT produce TS2300
// ============================================================================

///|
fn ts2300_count_for(source : String) -> Int {
  count_code(duplicate_prop_diagnostics(source), 2300)
}

test "No TS2300: class + interface merge" {
  let source =
    #|class C {}
    #|interface C { x: number; }
  assert_eq(ts2300_count_for(source), 0)
}

test "No TS2300: class + namespace merge" {
  let source =
    #|class D {}
    #|namespace D { export const x = 1; }
  assert_eq(ts2300_count_for(source), 0)
}

test "No TS2300: function + namespace merge" {
  let source =
    #|function F() { return 1; }
    #|namespace F { export const x = 1; }
  assert_eq(ts2300_count_for(source), 0)
}

test "No TS2300: enum + namespace merge" {
  let source =
    #|enum E { Red, Blue }
    #|namespace E { export class Point { } }
  assert_eq(ts2300_count_for(source), 0)
}

test "No TS2300: type alias + function (separate declaration spaces)" {
  let source =
    #|type A = string;
    #|function A() {}
  assert_eq(ts2300_count_for(source), 0)
}

test "No TS2300: type alias + var (separate declaration spaces)" {
  let source =
    #|type B = string;
    #|var B = 10;
  assert_eq(ts2300_count_for(source), 0)
}

test "No TS2300: interface + var inside namespace" {
  let source =
    #|namespace M {
    #|    export interface Point { x: number; y: number }
    #|    export var Point = 1;
    #|}
  assert_eq(ts2300_count_for(source), 0)
}

test "No TS2300: exported function + namespace inside namespace" {
  let source =
    #|namespace X {
    #|    export function Y() { return 42; }
    #|    export namespace Y {
    #|        export class Point { }
    #|    }
    #|}
  assert_eq(ts2300_count_for(source), 0)
}

test "TS2300: duplicate type aliases still error" {
  let source =
    #|type T = string;
    #|type T = number;
  assert_true(ts2300_count_for(source) > 0)
}

test "TS2300: duplicate classes still error" {
  let source =
    #|class K {}
    #|class K {}
  assert_true(ts2300_count_for(source) > 0)
}

test "TS2300: class + var still errors" {
  let source =
    #|var V = 1;
    #|class V {}
  assert_true(ts2300_count_for(source) > 0)
}

test "TS2300: type alias + interface still errors" {
  let source =
    #|type W = string;
    #|interface W { x: number; }
  assert_true(ts2300_count_for(source) > 0)
}
