// Unit tests for the standard-library loader (F1).

///|
test "normalize_lib_name handles aliases, prefixes and suffixes" {
  assert_eq(normalize_lib_name("ES2015"), "es2015")
  assert_eq(normalize_lib_name("es6"), "es2015")
  assert_eq(normalize_lib_name("es7"), "es2016")
  assert_eq(normalize_lib_name("lib.es2015.promise.d.ts"), "es2015.promise")
  assert_eq(normalize_lib_name("esnext"), "esnext")
}

///|
test "expand_lib_selection follows reference directives transitively" {
  let expanded = expand_lib_selection(["es2016"])
  let seen : @hashset.HashSet[String] = @hashset.HashSet([])
  for l in expanded {
    seen.add(l)
  }
  assert_true(seen.contains("es2016"))
  assert_true(seen.contains("es2015"))
  assert_true(seen.contains("es5"))
  assert_true(seen.contains("es2015.promise"))
  assert_true(seen.contains("es2015.iterable"))
  assert_true(seen.contains("es2016.array.include"))
  // es2017-only libs must not be pulled in
  assert_false(seen.contains("es2017.object"))
}

///|
test "expand_lib_selection drops unknown (non-embedded) libs" {
  let expanded = expand_lib_selection(["dom", "es5"])
  assert_eq(expanded.length(), 3) // es5 + decorators + decorators.legacy
}

///|
test "es5 lib declares core globals but no ES2015 ones" {
  let es5 = LibContext::{ libs: ["es5"], no_lib: false }
  // Types from lib.es5.d.ts
  assert_true(lib_has_type_name(es5, "Array"))
  assert_true(lib_has_type_name(es5, "Object"))
  assert_true(lib_has_type_name(es5, "String"))
  assert_true(lib_has_type_name(es5, "RegExp"))
  assert_true(lib_has_type_name(es5, "PropertyDescriptor"))
  assert_true(lib_has_type_name(es5, "IArguments"))
  assert_true(lib_has_type_name(es5, "CallableFunction"))
  // Symbol is a TYPE in es5 (interface Symbol) but not a VALUE
  assert_true(lib_has_type_name(es5, "Symbol"))
  assert_false(lib_has_value_name(es5, "Symbol"))
  // Utility types (type aliases in lib.es5.d.ts)
  assert_true(lib_has_type_name(es5, "Partial"))
  assert_true(lib_has_type_name(es5, "Record"))
  assert_true(lib_has_type_name(es5, "Awaited"))
  assert_true(lib_has_type_name(es5, "ReturnType"))
  // Values from lib.es5.d.ts
  assert_true(lib_has_value_name(es5, "JSON"))
  assert_true(lib_has_value_name(es5, "Math"))
  assert_true(lib_has_value_name(es5, "NaN"))
  assert_true(lib_has_value_name(es5, "parseInt"))
  assert_true(lib_has_value_name(es5, "encodeURIComponent"))
  assert_true(lib_has_value_name(es5, "Intl"))
  // es5 declares Promise as a TYPE (interface Promise<T> for `await`) but
  // the Promise constructor VALUE only arrives with es2015 (hence TS2585)
  assert_true(lib_has_type_name(es5, "Promise"))
  // ES2015+ globals must NOT be in es5
  assert_false(lib_has_type_name(es5, "Map"))
  assert_false(lib_has_type_name(es5, "IterableIterator"))
  assert_false(lib_has_value_name(es5, "Promise"))
  assert_false(lib_has_value_name(es5, "Map"))
  assert_false(lib_has_value_name(es5, "Proxy"))
  assert_false(lib_has_value_name(es5, "Reflect"))
}

///|
test "es2015 chain declares Promise, Map, Symbol, iterators" {
  let es2015 = LibContext::{ libs: ["es2015"], no_lib: false }
  assert_true(lib_has_type_name(es2015, "Promise"))
  assert_true(lib_has_type_name(es2015, "PromiseLike"))
  assert_true(lib_has_type_name(es2015, "Map"))
  assert_true(lib_has_type_name(es2015, "Set"))
  assert_true(lib_has_type_name(es2015, "WeakMap"))
  assert_true(lib_has_type_name(es2015, "IterableIterator"))
  assert_true(lib_has_type_name(es2015, "Iterable"))
  assert_true(lib_has_type_name(es2015, "Iterator"))
  assert_true(lib_has_type_name(es2015, "Generator"))
  assert_true(lib_has_type_name(es2015, "ProxyHandler"))
  // Values
  assert_true(lib_has_value_name(es2015, "Promise"))
  assert_true(lib_has_value_name(es2015, "Map"))
  assert_true(lib_has_value_name(es2015, "Set"))
  assert_true(lib_has_value_name(es2015, "Symbol"))
  assert_true(lib_has_value_name(es2015, "Proxy"))
  assert_true(lib_has_value_name(es2015, "Reflect"))
  // es5 base is inherited
  assert_true(lib_has_type_name(es2015, "Array"))
  assert_true(lib_has_value_name(es2015, "JSON"))
  // Later-lib globals are absent
  assert_false(lib_has_type_name(es2015, "AsyncIterableIterator")) // es2018
  assert_false(lib_has_value_name(es2015, "BigInt")) // es2020
  assert_false(lib_has_type_name(es2015, "WeakRef")) // es2021
}

///|
test "target-gated globals appear per target chain" {
  let es2017 = LibContext::{ libs: ["es2017"], no_lib: false }
  assert_true(lib_has_value_name(es2017, "SharedArrayBuffer"))
  assert_true(lib_has_value_name(es2017, "Atomics"))
  assert_false(lib_has_type_name(es2017, "AsyncGenerator")) // es2018
  let es2018 = LibContext::{ libs: ["es2018"], no_lib: false }
  assert_true(lib_has_type_name(es2018, "AsyncGenerator"))
  assert_true(lib_has_type_name(es2018, "AsyncIterableIterator"))
  let es2020 = LibContext::{ libs: ["es2020"], no_lib: false }
  assert_true(lib_has_value_name(es2020, "BigInt"))
  assert_true(lib_has_type_name(es2020, "BigInt64Array"))
  let es2021 = LibContext::{ libs: ["es2021"], no_lib: false }
  assert_true(lib_has_value_name(es2021, "WeakRef"))
  assert_true(lib_has_value_name(es2021, "FinalizationRegistry"))
  let esnext = LibContext::{ libs: ["esnext"], no_lib: false }
  assert_true(lib_has_type_name(esnext, "Float16Array"))
  assert_true(lib_has_type_name(esnext, "Disposable"))
  assert_true(lib_has_type_name(esnext, "DisposableStack"))
}

///|
test "explicit lib list resolves like tsc's --lib" {
  let ctx = LibContext::from_libs(["ES5", "es2015.promise"])
  assert_true(lib_has_type_name(ctx, "Promise"))
  assert_true(lib_has_value_name(ctx, "Promise"))
  assert_true(lib_has_type_name(ctx, "Array"))
  // Not part of the selection
  assert_false(lib_has_type_name(ctx, "Map"))
  assert_false(lib_has_value_name(ctx, "Symbol"))
}

///|
test "noLib context resolves nothing" {
  let ctx = LibContext::without_lib()
  assert_false(lib_has_type_name(ctx, "Array"))
  assert_false(lib_has_value_name(ctx, "JSON"))
}

///|
test "universe covers all embedded libs but not dom" {
  assert_true(lib_universe_has_type_name("Promise"))
  assert_true(lib_universe_has_value_name("Reflect"))
  assert_true(lib_universe_has_value_name("Proxy"))
  assert_true(lib_universe_has_type_name("Float16Array"))
  assert_false(lib_universe_has_type_name("HTMLElement"))
  assert_false(lib_universe_has_value_name("document"))
  assert_false(lib_universe_has_type_name("NotARealGlobalType"))
}

///|
test "earliest lib version for suggestion messages" {
  assert_eq(earliest_lib_version_for_name("Promise", true), Some("es2015"))
  assert_eq(earliest_lib_version_for_name("Promise", false), Some("es5"))
  assert_eq(earliest_lib_version_for_name("Symbol", true), Some("es2015"))
  assert_eq(earliest_lib_version_for_name("Symbol", false), Some("es5"))
  assert_eq(
    earliest_lib_version_for_name("AsyncIterableIterator", false),
    Some("es2018"),
  )
  assert_eq(earliest_lib_version_for_name("WeakRef", true), Some("es2021"))
  assert_eq(earliest_lib_version_for_name("document", true), None)
}

///|
test "tsc's TS2583 suggestion-name list" {
  assert_true(is_lib_change_suggestion_name("Map"))
  assert_true(is_lib_change_suggestion_name("Promise"))
  assert_true(is_lib_change_suggestion_name("Symbol"))
  assert_true(is_lib_change_suggestion_name("Reflect"))
  assert_false(is_lib_change_suggestion_name("Proxy")) // tsc: plain TS2304
  assert_false(is_lib_change_suggestion_name("WeakRef"))
}

///|
test "default lib for target string follows tsc" {
  assert_eq(default_lib_name_for_target_string(None), "es2025")
  assert_eq(default_lib_name_for_target_string(Some("ES5")), "es5")
  assert_eq(default_lib_name_for_target_string(Some("es6")), "es2015")
  assert_eq(default_lib_name_for_target_string(Some("es2022")), "es2022")
  assert_eq(default_lib_name_for_target_string(Some("esnext")), "esnext")
}

///|
test "default lib context derives from target when CLI set nothing" {
  set_default_lib_selection(None)
  let ctx = resolve_default_lib_context(Target::ES5)
  assert_eq(ctx.libs.length(), 1)
  assert_eq(ctx.libs[0], "es5")
  // CLI override wins
  set_default_lib_selection(Some(LibContext::from_libs(["es2015"])))
  let ctx2 = resolve_default_lib_context(Target::ES5)
  assert_eq(ctx2.libs[0], "es2015")
  set_default_lib_selection(None)
}
