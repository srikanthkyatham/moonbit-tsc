// Whitebox unit tests for extract_iterable_element_type cycle detection.
//
// Regression tests for an infinite loop: type parameters are stored in
// type_cache as self-referential TypeReference entries (e.g.
// type_cache["U"] = TypeReference("U")), which used to make
// extract_iterable_element_type (tail-)recurse forever - e.g. when spreading
// a value typed by a generic type parameter (genericRestParameters1.ts,
// restTuplesFromContextualTypes.ts, variadicTuples1/2.ts all hung).

///|
test "extract_iterable_element_type terminates on self-referential type parameter" {
  let checker = TypeChecker::new("test.ts", None)
  let (info, checker) = create_type_info(checker)
  // Simulate how type parameters are registered: type_cache["U"] = TypeReference("U")
  let type_ref = Type::TypeReference({ name: "U", type_arguments: [], info })
  checker.type_cache.set("U", type_ref)
  // Before the cycle guard this call never returned.
  let (result, _) = extract_iterable_element_type(checker, type_ref, None)
  match result {
    None => ()
    Some(_) => assert_true(false)
  }
}

///|
test "extract_iterable_element_type falls back to type parameter constraint" {
  let checker = TypeChecker::new("test.ts", None)
  let (info, checker) = create_type_info(checker)
  let type_ref = Type::TypeReference({ name: "U", type_arguments: [], info })
  checker.type_cache.set("U", type_ref)
  // U extends string[] - the element type of a spread of U is string
  let (str_t, checker) = string_type(checker)
  let (arr_info, checker) = create_type_info(checker)
  let constraint = Type::Array({ element_type: str_t, info: arr_info })
  checker.type_parameter_constraints.set("U", Some(constraint))
  let (result, _) = extract_iterable_element_type(checker, type_ref, None)
  match result {
    Some(String(_)) => ()
    _ => assert_true(false)
  }
}

///|
test "extract_iterable_element_type terminates on mutually recursive type references" {
  let checker = TypeChecker::new("test.ts", None)
  let (info_a, checker) = create_type_info(checker)
  let (info_b, checker) = create_type_info(checker)
  let ref_a = Type::TypeReference({
    name: "A",
    type_arguments: [],
    info: info_a,
  })
  let ref_b = Type::TypeReference({
    name: "B",
    type_arguments: [],
    info: info_b,
  })
  // A -> B -> A cycle in the type cache
  checker.type_cache.set("A", ref_b)
  checker.type_cache.set("B", ref_a)
  let (result, _) = extract_iterable_element_type(checker, ref_a, None)
  match result {
    None => ()
    Some(_) => assert_true(false)
  }
}
