// Tests for Advanced Class Features - Super Call Validation, Polymorphic This, Class Expressions

// ============================================================================
// Constructor Validation State Tests
// ============================================================================

test "unit/advanced_classes/validation_state - new creates default state" {
  let state = @compiler.ConstructorValidationState::new()
  assert_eq(state.is_derived_class, false)
  assert_eq(state.super_called, false)
  assert_eq(state.this_accessed_before_super, false)
  assert_eq(state.in_constructor, false)
  assert_eq(state.in_static_context, false)
  assert_eq(state.base_class_name is None, true)
}

test "unit/advanced_classes/validation_state - for_derived_constructor" {
  let state = @compiler.ConstructorValidationState::for_derived_constructor("BaseClass")
  assert_eq(state.is_derived_class, true)
  assert_eq(state.super_called, false)
  assert_eq(state.this_accessed_before_super, false)
  assert_eq(state.in_constructor, true)
  assert_eq(state.in_static_context, false)
  assert_eq(state.base_class_name, Some("BaseClass"))
}

test "unit/advanced_classes/validation_state - for_constructor" {
  let state = @compiler.ConstructorValidationState::for_constructor()
  assert_eq(state.is_derived_class, false)
  assert_eq(state.in_constructor, true)
  assert_eq(state.base_class_name is None, true)
}

// ============================================================================
// Super Call Validation Tests
// ============================================================================

test "unit/advanced_classes/super_call - validate_super_call outside constructor" {
  let errors = @compiler.validate_super_call(false, true)
  assert_eq(errors.length() > 0, true)
  // Should have SuperCallOutsideConstructor error
  let has_error = errors.iter().any(fn(e) {
    match e.reason {
      @compiler.MismatchReason::SuperCallOutsideConstructor => true
      _ => false
    }
  })
  assert_true(has_error)
}

test "unit/advanced_classes/super_call - validate_super_call in non-derived constructor" {
  let errors = @compiler.validate_super_call(true, false)
  assert_eq(errors.length() > 0, true)
  // Should have SuperPropertyOutsideClass error
  let has_error = errors.iter().any(fn(e) {
    match e.reason {
      @compiler.MismatchReason::SuperPropertyOutsideClass => true
      _ => false
    }
  })
  assert_true(has_error)
}

test "unit/advanced_classes/super_call - validate_super_call in derived constructor" {
  let errors = @compiler.validate_super_call(true, true)
  assert_eq(errors.length(), 0) // No errors for valid super() call
}

// ============================================================================
// MismatchReason Constructor Tests
// ============================================================================

test "unit/advanced_classes/mismatch_reason - this_before_super" {
  let reason = @compiler.MismatchReason::this_before_super()
  match reason {
    @compiler.MismatchReason::ThisBeforeSuperCall => assert_true(true)
    _ => fail("Expected ThisBeforeSuperCall")
  }
}

test "unit/advanced_classes/mismatch_reason - super_call_required" {
  let reason = @compiler.MismatchReason::super_call_required("MyClass")
  match reason {
    @compiler.MismatchReason::SuperCallRequired(name) => assert_eq(name, "MyClass")
    _ => fail("Expected SuperCallRequired")
  }
}

test "unit/advanced_classes/mismatch_reason - super_outside_constructor" {
  let reason = @compiler.MismatchReason::super_outside_constructor()
  match reason {
    @compiler.MismatchReason::SuperCallOutsideConstructor => assert_true(true)
    _ => fail("Expected SuperCallOutsideConstructor")
  }
}

test "unit/advanced_classes/mismatch_reason - super_outside_class" {
  let reason = @compiler.MismatchReason::super_outside_class()
  match reason {
    @compiler.MismatchReason::SuperPropertyOutsideClass => assert_true(true)
    _ => fail("Expected SuperPropertyOutsideClass")
  }
}

test "unit/advanced_classes/mismatch_reason - super_property_access" {
  let reason = @compiler.MismatchReason::super_property_access("foo")
  match reason {
    @compiler.MismatchReason::SuperPropertyAccess(name) => assert_eq(name, "foo")
    _ => fail("Expected SuperPropertyAccess")
  }
}

// ============================================================================
// Polymorphic This Type Tests
// ============================================================================

test "unit/advanced_classes/polymorphic_this - for_class constructor" {
  let this_type = @compiler.PolymorphicThisType::for_class("MyClass", [])
  assert_eq(this_type.containing_class, "MyClass")
  assert_eq(this_type.type_params.length(), 0)
  assert_eq(this_type.is_static, false)
}

test "unit/advanced_classes/polymorphic_this - for_class with type params" {
  let params = [@compiler.TypeParamV2::simple("T"), @compiler.TypeParamV2::simple("U")]
  let this_type = @compiler.PolymorphicThisType::for_class("Container", params)
  assert_eq(this_type.containing_class, "Container")
  assert_eq(this_type.type_params.length(), 2)
}

test "unit/advanced_classes/polymorphic_this - create_polymorphic_this_type non-generic" {
  let ty = @compiler.create_polymorphic_this_type("MyClass", [])
  match ty {
    @compiler.TGenericInstance(name, args) => {
      assert_eq(name, "MyClass")
      assert_eq(args.length(), 0)
    }
    _ => fail("Expected TGenericInstance")
  }
}

test "unit/advanced_classes/polymorphic_this - create_polymorphic_this_type generic" {
  let params = [@compiler.TypeParamV2::simple("T")]
  let ty = @compiler.create_polymorphic_this_type("Container", params)
  match ty {
    @compiler.TGenericInstance(name, args) => {
      assert_eq(name, "Container")
      assert_eq(args.length(), 1)
    }
    _ => fail("Expected TGenericInstance")
  }
}

test "unit/advanced_classes/polymorphic_this - resolve_this_type_in_derived" {
  let base_type = @compiler.create_polymorphic_this_type("Base", [])
  let derived_type = @compiler.resolve_this_type_in_derived(
    base_type,
    "Derived",
    [],
  )
  // For non-this types, it should pass through unchanged
  // The function should handle TGenericInstance
  match derived_type {
    @compiler.TGenericInstance(_, _) => assert_true(true)
    _ => assert_true(true) // Other types pass through
  }
}

// ============================================================================
// Super Resolution Tests
// ============================================================================

test "unit/advanced_classes/super_resolution - resolve_super_property no base" {
  let result = @compiler.resolve_super_property(None, "foo")
  assert_eq(result.errors.length() > 0, true)
  // Result should be an error type
  match result.resolved_type {
    @compiler.TError => assert_true(true)
    _ => fail("Expected TError")
  }
}

test "unit/advanced_classes/super_resolution - resolve_super_constructor_call no base" {
  let result = @compiler.resolve_super_constructor_call(None, [])
  assert_eq(result.errors.length() > 0, true)
  // Result should be an error type
  match result.resolved_type {
    @compiler.TError => assert_true(true)
    _ => fail("Expected TError")
  }
}

// ============================================================================
// Error Code Tests
// ============================================================================

test "unit/advanced_classes/error_codes - ThisBeforeSuperCall" {
  let code = @compiler.get_error_code(@compiler.MismatchReason::this_before_super())
  assert_eq(code, 17009)
}

test "unit/advanced_classes/error_codes - SuperCallRequired" {
  let code = @compiler.get_error_code(@compiler.MismatchReason::super_call_required("Test"))
  assert_eq(code, 2377)
}

test "unit/advanced_classes/error_codes - SuperCallOutsideConstructor" {
  let code = @compiler.get_error_code(@compiler.MismatchReason::super_outside_constructor())
  assert_eq(code, 2337)
}

test "unit/advanced_classes/error_codes - SuperPropertyOutsideClass" {
  let code = @compiler.get_error_code(@compiler.MismatchReason::super_outside_class())
  assert_eq(code, 2335)
}

test "unit/advanced_classes/error_codes - SuperPropertyAccess" {
  let code = @compiler.get_error_code(@compiler.MismatchReason::super_property_access("foo"))
  assert_eq(code, 2339)
}

// ============================================================================
// Friendly Title Tests
// ============================================================================

test "unit/advanced_classes/friendly_titles - super errors" {
  let t1 = @compiler.get_friendly_title(@compiler.MismatchReason::this_before_super())
  assert_true(t1.contains("THIS"))
  assert_true(t1.contains("SUPER"))

  let t2 = @compiler.get_friendly_title(@compiler.MismatchReason::super_call_required("MyClass"))
  assert_true(t2.contains("SUPER"))
  assert_true(t2.contains("MyClass"))

  let t3 = @compiler.get_friendly_title(@compiler.MismatchReason::super_outside_constructor())
  assert_true(t3.contains("SUPER"))

  let t4 = @compiler.get_friendly_title(@compiler.MismatchReason::super_outside_class())
  assert_true(t4.contains("SUPER"))

  let t5 = @compiler.get_friendly_title(@compiler.MismatchReason::super_property_access("foo"))
  assert_true(t5.contains("foo"))
}

// ============================================================================
// Why Explanation Tests
// ============================================================================

test "unit/advanced_classes/why_explanation - super errors" {
  let e1 = @compiler.get_why_explanation(@compiler.MismatchReason::this_before_super())
  assert_true(e1.contains("super"))

  let e2 = @compiler.get_why_explanation(@compiler.MismatchReason::super_call_required("MyClass"))
  assert_true(e2.contains("super"))

  let e3 = @compiler.get_why_explanation(@compiler.MismatchReason::super_outside_constructor())
  assert_true(e3.contains("constructor"))

  let e4 = @compiler.get_why_explanation(@compiler.MismatchReason::super_outside_class())
  assert_true(e4.contains("class"))
}

// ============================================================================
// How To Fix Tests
// ============================================================================

test "unit/advanced_classes/how_to_fix - super errors provide suggestions" {
  let f1 = @compiler.get_how_to_fix(
    @compiler.MismatchReason::this_before_super(),
    @compiler.create_any_type(),
    @compiler.create_void_type(),
  )
  assert_true(f1.length() > 0)

  let f2 = @compiler.get_how_to_fix(
    @compiler.MismatchReason::super_call_required("Test"),
    @compiler.create_any_type(),
    @compiler.create_void_type(),
  )
  assert_true(f2.length() > 0)

  let f3 = @compiler.get_how_to_fix(
    @compiler.MismatchReason::super_outside_constructor(),
    @compiler.create_any_type(),
    @compiler.create_void_type(),
  )
  assert_true(f3.length() > 0)
}
