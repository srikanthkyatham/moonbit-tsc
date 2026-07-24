// F1: standard-library global resolution through real lib.d.ts loading.
// Verifies that globals resolve from the loaded libs (not the old name
// whitelist), that unknown names still error, and that target/lib gating
// produces the same diagnostic codes as tsc (TS2583/TS2585/TS2304/TS2318).

///|
fn lib_check(
  source : String,
  target : @compiler.Target,
  lib_context? : @compiler.LibContext? = None,
) -> Array[@compiler.Diagnostic] {
  let tokens = @compiler.scan_all_v2(source, "libres_test.ts")
  match @compiler.parse_source_file(tokens, "libres_test.ts") {
    Ok(source_file) => {
      if source_file.parse_diagnostics.length() > 0 {
        return source_file.parse_diagnostics
      }
      match @compiler.bind_source_file(source_file) {
        Ok(bound) =>
          match
            @compiler.check_source_file_with_options(
              bound, false, target,
              lib_context~,
            ) {
            Ok(_) => []
            Err(diagnostics) => diagnostics
          }
        Err(diagnostics) => diagnostics
      }
    }
    Err(diagnostics) => diagnostics
  }
}

///|
fn lib_has_code(diags : Array[@compiler.Diagnostic], code : Int) -> Bool {
  for d in diags {
    if d.code == code {
      return true
    }
  }
  false
}

///|
fn lib_count_code(diags : Array[@compiler.Diagnostic], code : Int) -> Int {
  let mut n = 0
  for d in diags {
    if d.code == code {
      n = n + 1
    }
  }
  n
}

///|
test "lib globals resolve as values without the whitelist" {
  let source =
    #|const a = parseFloat("1.5");
    #|const b = encodeURIComponent("x");
    #|const c = Reflect.ownKeys({});
    #|const d = new Proxy({}, {});
    #|const e = Atomics;
    #|const f = BigInt(1);
  let diags = lib_check(source, @compiler.Target::ESNext)
  assert_false(lib_has_code(diags, 2304))
  assert_false(lib_has_code(diags, 2552))
  assert_false(lib_has_code(diags, 2583))
  assert_false(lib_has_code(diags, 2584))
}

///|
test "lib globals resolve as types without the whitelist" {
  let source =
    #|let a : Float16Array | null = null;
    #|let b : DisposableStack | null = null;
    #|let c : AsyncGenerator<number> | null = null;
    #|let d : WeakRef<object> | null = null;
  let diags = lib_check(source, @compiler.Target::ESNext)
  assert_false(lib_has_code(diags, 2304))
  assert_false(lib_has_code(diags, 2583))
}

///|
test "unknown global value still reports TS2304" {
  let source =
    #|const x = totallyUnknownGlobal;
  let diags = lib_check(source, @compiler.Target::ESNext)
  assert_true(lib_has_code(diags, 2304) || lib_has_code(diags, 2552))
}

///|
test "unknown global type still reports TS2304" {
  let source =
    #|let x : TotallyUnknownType | null = null;
  let diags = lib_check(source, @compiler.Target::ESNext)
  assert_true(lib_has_code(diags, 2304))
}

///|
test "target-gated globals: es5 gives tsc's codes" {
  // Matches modularizeLibrary_ErrorFromUsingES6FeaturesWithOnlyES5Lib:
  // Map -> TS2583, Symbol -> TS2585, Proxy -> TS2304, Reflect -> TS2583
  let source =
    #|var m = new Map<string, number>();
    #|var s = Symbol();
    #|var p = new Proxy({}, {});
    #|var r = Reflect;
  let diags = lib_check(source, @compiler.Target::ES5)
  assert_eq(lib_count_code(diags, 2583), 2) // Map, Reflect
  assert_eq(lib_count_code(diags, 2585), 1) // Symbol
  assert_true(lib_has_code(diags, 2304)) // Proxy
}

///|
test "target-gated globals disappear at es2015" {
  let source =
    #|var m = new Map<string, number>();
    #|var s = Symbol();
    #|var p = new Proxy({}, {});
    #|var r = Reflect;
  let diags = lib_check(source, @compiler.Target::ES2015)
  assert_false(lib_has_code(diags, 2304))
  assert_false(lib_has_code(diags, 2583))
  assert_false(lib_has_code(diags, 2585))
}

///|
test "es5 keeps Promise as a type but not as a value" {
  // es5.d.ts declares `interface Promise<T>`; the constructor value only
  // arrives with es2015
  let type_only =
    #|let p : Promise<number> | null = null;
  let diags = lib_check(type_only, @compiler.Target::ES5)
  assert_false(lib_has_code(diags, 2304))
  assert_false(lib_has_code(diags, 2583))
  let value_use =
    #|var p = Promise;
  let diags2 = lib_check(value_use, @compiler.Target::ES5)
  assert_true(lib_has_code(diags2, 2585))
}

///|
test "explicit lib context overrides the target default" {
  // ESNext target but only es5 libs selected (like `--lib es5`)
  let source =
    #|var m = new Map<string, number>();
  let diags = lib_check(
    source,
    @compiler.Target::ESNext,
    lib_context=Some(@compiler.LibContext::from_libs(["es5"])),
  )
  assert_true(lib_has_code(diags, 2583))
  // ES5 target but es2015.collection selected: Map resolves
  let diags2 = lib_check(
    source,
    @compiler.Target::ES5,
    lib_context=Some(
      @compiler.LibContext::from_libs(["es5", "es2015.collection"]),
    ),
  )
  assert_false(lib_has_code(diags2, 2583))
  assert_false(lib_has_code(diags2, 2304))
}

///|
test "noLib reports TS2318 for each missing fundamental global type" {
  let source =
    #|export function f() {}
  let diags = lib_check(
    source,
    @compiler.Target::ESNext,
    lib_context=Some(@compiler.LibContext::without_lib()),
  )
  // Array, Boolean, CallableFunction, Function, IArguments, NewableFunction,
  // Number, Object, RegExp, String
  assert_eq(lib_count_code(diags, 2318), 10)
}

///|
test "noLib respects globals the file declares itself" {
  let source =
    #|interface Array<T> {}
    #|interface Boolean {}
    #|interface Function {}
    #|export function f() {}
  let diags = lib_check(
    source,
    @compiler.Target::ESNext,
    lib_context=Some(@compiler.LibContext::without_lib()),
  )
  assert_eq(lib_count_code(diags, 2318), 7)
}
