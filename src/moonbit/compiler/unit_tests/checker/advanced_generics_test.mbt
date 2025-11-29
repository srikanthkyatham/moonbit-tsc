// Tests for Advanced Generics - Const Type Parameters, Variance, Recursive Types, Higher-Order Generics

// ============================================================================
// Const Type Parameter Tests
// ============================================================================

test "unit/advanced_generics/const_param - TypeParamV2 const constructor" {
  let param = @compiler.TypeParamV2::const_param("T")
  assert_eq(param.name, "T")
  assert_eq(param.is_const, true)
  assert_eq(param.constraint is None, true)
  assert_eq(param.variance is None, true)
}

test "unit/advanced_generics/const_param - TypeParamV2 const constrained" {
  let param = @compiler.TypeParamV2::const_constrained("T", @compiler.create_string_type())
  assert_eq(param.name, "T")
  assert_eq(param.is_const, true)
  assert_eq(param.constraint, Some(@compiler.create_string_type()))
}

test "unit/advanced_generics/const_param - narrow literal string" {
  let param = @compiler.TypeParamV2::const_param("T")
  let inferred = @compiler.create_literal_string_type("hello")
  let result = @compiler.narrow_to_literal_for_const(param, inferred)
  assert_eq(result, @compiler.create_literal_string_type("hello"))
}

test "unit/advanced_generics/const_param - narrow literal number" {
  let param = @compiler.TypeParamV2::const_param("T")
  let inferred = @compiler.create_literal_number_type(42.0)
  let result = @compiler.narrow_to_literal_for_const(param, inferred)
  assert_eq(result, @compiler.create_literal_number_type(42.0))
}

test "unit/advanced_generics/const_param - narrow literal bool" {
  let param = @compiler.TypeParamV2::const_param("T")
  let inferred = @compiler.create_literal_bool_type(true)
  let result = @compiler.narrow_to_literal_for_const(param, inferred)
  assert_eq(result, @compiler.create_literal_bool_type(true))
}

test "unit/advanced_generics/const_param - non-const doesnt narrow" {
  let param = @compiler.TypeParamV2::simple("T")
  let inferred = @compiler.create_string_type()
  let result = @compiler.narrow_to_literal_for_const(param, inferred)
  assert_eq(result, @compiler.create_string_type())
}

test "unit/advanced_generics/const_param - narrow tuple elements" {
  let param = @compiler.TypeParamV2::const_param("T")
  let tuple_type = @compiler.create_tuple_type([
    @compiler.TupleElementV2::required(@compiler.create_literal_number_type(1.0)),
    @compiler.TupleElementV2::required(@compiler.create_literal_number_type(2.0)),
    @compiler.TupleElementV2::required(@compiler.create_literal_number_type(3.0)),
  ])
  let result = @compiler.narrow_to_literal_for_const(param, tuple_type)
  // Result should still have literal number types
  match result {
    @compiler.TTuple(elems) => {
      assert_eq(elems.length(), 3)
      assert_eq(elems[0].ty, @compiler.create_literal_number_type(1.0))
    }
    _ => fail("Expected tuple type")
  }
}

// ============================================================================
// Variance Analysis Tests
// ============================================================================

test "unit/advanced_generics/variance - covariant in return position" {
  let return_type = @compiler.create_type_param("T", None)
  let variance = @compiler.analyze_variance("T", return_type)
  assert_eq(variance, @compiler.Variance::covariant())
}

test "unit/advanced_generics/variance - bivariant when not used" {
  let variance = @compiler.analyze_variance("T", @compiler.create_string_type())
  assert_eq(variance, @compiler.Variance::bivariant())
}

test "unit/advanced_generics/variance - covariant in array element" {
  let array_type = @compiler.create_array_type(@compiler.create_type_param("T", None))
  let variance = @compiler.analyze_variance("T", array_type)
  assert_eq(variance, @compiler.Variance::covariant())
}

test "unit/advanced_generics/variance - combine variances" {
  assert_eq(@compiler.combine_variances(@compiler.Variance::bivariant(), @compiler.Variance::covariant()), @compiler.Variance::covariant())
  assert_eq(@compiler.combine_variances(@compiler.Variance::covariant(), @compiler.Variance::covariant()), @compiler.Variance::covariant())
  assert_eq(@compiler.combine_variances(@compiler.Variance::contravariant(), @compiler.Variance::contravariant()), @compiler.Variance::contravariant())
  assert_eq(@compiler.combine_variances(@compiler.Variance::covariant(), @compiler.Variance::contravariant()), @compiler.Variance::invariant())
  assert_eq(@compiler.combine_variances(@compiler.Variance::invariant(), @compiler.Variance::covariant()), @compiler.Variance::invariant())
}

test "unit/advanced_generics/variance - is compatible" {
  assert_true(@compiler.is_variance_compatible(@compiler.Variance::covariant(), @compiler.Variance::covariant()))
  assert_true(@compiler.is_variance_compatible(@compiler.Variance::bivariant(), @compiler.Variance::covariant()))
  assert_true(@compiler.is_variance_compatible(@compiler.Variance::bivariant(), @compiler.Variance::contravariant()))
  assert_false(@compiler.is_variance_compatible(@compiler.Variance::covariant(), @compiler.Variance::contravariant()))
  assert_false(@compiler.is_variance_compatible(@compiler.Variance::invariant(), @compiler.Variance::covariant()))
}

// ============================================================================
// Higher-Order Generics Tests
// ============================================================================

test "unit/advanced_generics/hkt - create simple HKT" {
  let hkt = @compiler.HigherKindedType::new("Array", 1)
  assert_eq(hkt.name, "Array")
  assert_eq(hkt.arity, 1)
  assert_eq(hkt.params.length(), 0)
  assert_eq(hkt.body is None, true)
}

test "unit/advanced_generics/hkt - create HKT with params" {
  let hkt = @compiler.HigherKindedType::with_params(
    "Result",
    [@compiler.TypeParamV2::simple("T"), @compiler.TypeParamV2::simple("E")],
    @compiler.create_union_type([@compiler.create_type_param("T", None), @compiler.create_type_param("E", None)])
  )
  assert_eq(hkt.name, "Result")
  assert_eq(hkt.arity, 2)
  assert_eq(hkt.params.length(), 2)
  assert_eq(hkt.body is Some(_), true)
}

test "unit/advanced_generics/hkt - apply type args to simple HKT" {
  let hkt = @compiler.HigherKindedType::new("Array", 1)
  let result = @compiler.apply_higher_kinded_type(hkt, [@compiler.create_number_type()])
  assert_eq(result, @compiler.create_generic_instance("Array", [@compiler.create_number_type()]))
}

test "unit/advanced_generics/hkt - arity mismatch returns generic instance" {
  let hkt = @compiler.HigherKindedType::new("Map", 2)
  let result = @compiler.apply_higher_kinded_type(hkt, [@compiler.create_string_type()])
  assert_eq(result, @compiler.create_generic_instance("Map", [@compiler.create_string_type()]))
}

test "unit/advanced_generics/hkt - is_higher_kinded" {
  assert_true(@compiler.is_higher_kinded(@compiler.create_generic_instance("Array", [@compiler.create_number_type()])))
  assert_true(@compiler.is_higher_kinded(@compiler.create_type_param("T", None)))
  assert_false(@compiler.is_higher_kinded(@compiler.create_number_type()))
  assert_false(@compiler.is_higher_kinded(@compiler.create_string_type()))
}

test "unit/advanced_generics/hkt - get_type_constructor" {
  let tc = @compiler.get_type_constructor(@compiler.create_generic_instance("Array", [@compiler.create_number_type()]))
  assert_eq(tc, Some("Array"))
  let tc2 = @compiler.get_type_constructor(@compiler.create_number_type())
  assert_eq(tc2 is None, true)
}

test "unit/advanced_generics/hkt - get_type_arguments" {
  let args = @compiler.get_type_arguments(@compiler.create_generic_instance("Map", [@compiler.create_string_type(), @compiler.create_number_type()]))
  assert_eq(args.length(), 2)
  assert_eq(args[0], @compiler.create_string_type())
  assert_eq(args[1], @compiler.create_number_type())

  let args2 = @compiler.get_type_arguments(@compiler.create_number_type())
  assert_eq(args2.length(), 0)
}

// ============================================================================
// Integration Tests
// ============================================================================

test "unit/advanced_generics/integration - TypeParamV2 full constructor" {
  let param = @compiler.TypeParamV2::full(
    "T",
    Some(@compiler.create_number_type()),
    Some(@compiler.create_literal_number_type(0.0)),
    true,
    Some(@compiler.Variance::covariant())
  )
  assert_eq(param.name, "T")
  assert_eq(param.constraint, Some(@compiler.create_number_type()))
  assert_eq(param.default_type, Some(@compiler.create_literal_number_type(0.0)))
  assert_eq(param.is_const, true)
  assert_eq(param.variance, Some(@compiler.Variance::covariant()))
}

test "unit/advanced_generics/integration - TypeParamV2 with_variance constructor" {
  let param = @compiler.TypeParamV2::with_variance("T", @compiler.Variance::contravariant())
  assert_eq(param.name, "T")
  assert_eq(param.is_const, false)
  assert_eq(param.variance, Some(@compiler.Variance::contravariant()))
}

test "unit/advanced_generics/variance - variance enum constructors" {
  assert_eq(@compiler.Variance::covariant(), @compiler.Variance::covariant())
  assert_eq(@compiler.Variance::contravariant(), @compiler.Variance::contravariant())
  assert_eq(@compiler.Variance::invariant(), @compiler.Variance::invariant())
  assert_eq(@compiler.Variance::bivariant(), @compiler.Variance::bivariant())
}

test "unit/advanced_generics/variance - position constructors" {
  assert_eq(@compiler.TypePosition::output(), @compiler.TypePosition::output())
  assert_eq(@compiler.TypePosition::input(), @compiler.TypePosition::input())
}

test "unit/advanced_generics/variance - flip position" {
  assert_eq(@compiler.flip_position(@compiler.TypePosition::output()), @compiler.TypePosition::input())
  assert_eq(@compiler.flip_position(@compiler.TypePosition::input()), @compiler.TypePosition::output())
}

test "unit/advanced_generics/const_param - narrow union type" {
  let param = @compiler.TypeParamV2::const_param("T")
  let union_type = @compiler.create_union_type([@compiler.create_literal_string_type("a"), @compiler.create_literal_string_type("b")])
  let result = @compiler.narrow_to_literal_for_const(param, union_type)
  match result {
    @compiler.TUnion(types) => {
      assert_eq(types.length(), 2)
      assert_eq(types[0], @compiler.create_literal_string_type("a"))
      assert_eq(types[1], @compiler.create_literal_string_type("b"))
    }
    _ => fail("Expected union type")
  }
}

test "unit/advanced_generics/const_param - narrow array element type" {
  let param = @compiler.TypeParamV2::const_param("T")
  let array_type = @compiler.create_array_type(@compiler.create_literal_number_type(42.0))
  let result = @compiler.narrow_to_literal_for_const(param, array_type)
  match result {
    @compiler.TArray(elem) => assert_eq(elem, @compiler.create_literal_number_type(42.0))
    _ => fail("Expected array type")
  }
}
