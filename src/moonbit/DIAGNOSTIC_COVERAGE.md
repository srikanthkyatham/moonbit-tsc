# TypeScript Diagnostic Code Coverage Analysis

## Summary (Updated 2025-12-02)

| Metric | Count |
|--------|-------|
| Error codes defined in type_errors.mbt | 150+ |
| Error codes actively detected in checker.mbt | ~105 |
| Coverage of common errors | ~97% |
| Total Tests Passing | 3194 |

---

## ✅ Currently Implemented Error Codes

These error codes are actively detected by `checker.mbt`:

### Name Resolution Errors (2304-2318)
| Code | Description | Implementation Location |
|------|-------------|------------------------|
| TS2304 | Cannot find name '{0}' | `infer_identifier_type` |
| TS2314 | Generic type requires type arguments | `validate_type_argument_count` |
| TS2552 | Cannot find name, did you mean? | `infer_identifier_type` |

### Module/Import Resolution Errors (2691, 2694, 2709, 2710)
| Code | Description | Implementation Location |
|------|-------------|------------------------|
| TS2691 | Import path cannot end with extension | `check_import_declaration` |
| TS2694 | Namespace has no exported member | `infer_property_access_type` |
| TS2709 | Cannot use namespace as a type | `get_type_from_type_node` |
| TS2710 | Cannot use namespace as a value | `infer_identifier_type` |

### Module Export Conflicts (2484, 2494, 2502, 2687)
| Code | Description | Implementation Location |
|------|-------------|------------------------|
| TS2484 | Export declaration conflicts | `declare_symbol` (binder) |
| TS2494 | Exported variable using private name | `check_exported_variable_private_type` |
| TS2502 | Class references itself in base expression | `check_class_self_reference` |
| TS2687 | All declarations must have identical modifiers | `declare_symbol` (binder) |

### Type Parameter Errors (2706-2707)
| Code | Description | Implementation Location |
|------|-------------|------------------------|
| TS2706 | Required type param after optional | `check_type_parameter_names` |
| TS2707 | Generic type requires N-M type args | `validate_type_argument_count` |

### Parameter Errors (2369-2372)
| Code | Description | Implementation Location |
|------|-------------|------------------------|
| TS2369 | Parameter property only in constructor | `check_method_parameter_properties` |
| TS2371 | Parameter initializer only in function | `check_ambient_parameter_initializers` |
| TS2372 | Parameter cannot reference itself | `check_parameter_self_reference` |

### Type Assignment & Compatibility (2320-2380)
| Code | Description | Implementation Location |
|------|-------------|------------------------|
| TS2322 | Type not assignable | `check_assignment_compatibility` |
| TS2334 | 'this' in static property initializer | `infer_this_type` |
| TS2335 | 'super' only in derived class | `infer_call_expression_type` |
| TS2337 | Super calls outside constructors | `infer_call_expression_type` |
| TS2339 | Property does not exist | `infer_property_access_type` |
| TS2341 | Property is private | `check_member_visibility` |
| TS2344 | Type does not satisfy constraint | `check_type_arguments` |
| TS2345 | Argument type not assignable | `check_function_call_args` |
| TS2349 | Expression is not callable | `infer_call_expression_type` |
| TS2351 | Expression is not constructable | `infer_new_expression_type` |
| TS2355 | Function must return a value | Method body checking |
| TS2358 | instanceof left side | `check_instanceof_operands` |
| TS2359 | instanceof right side | `check_instanceof_operands` |
| TS2363 | Arithmetic operand must be number | `check_arithmetic_operands` |
| TS2365 | Operator cannot be applied | `check_arithmetic_operands` |
| TS2368 | Type parameter name cannot be reserved | `check_type_parameter_names` |
| TS2370 | Rest parameter must be array | `check_parameters` |
| TS2376 | Super call must be first statement | `check_super_is_first_statement` |
| TS2377 | Derived class must call super | `check_super_call_in_constructor` |

### Variable Declaration Errors (2403-2460)
| Code | Description | Implementation Location |
|------|-------------|------------------------|
| TS2406 | for-in left side must be variable | `check_for_in_left_side` |
| TS2407 | for-in right side must be object | `check_for_in_statement` |
| TS2445 | Property is protected | `check_member_visibility` |
| TS2487 | for-of left side must be variable | `check_for_of_left_side` |
| TS2448 | Block-scoped variable before declaration | `infer_identifier_type` |
| TS2454 | Variable used before assigned | `infer_identifier_type` |
| TS2460 | Type is not an array type | `check_variable_declaration` |

### Async/Generator Errors (2465-2771)
| Code | Description | Implementation Location |
|------|-------------|------------------------|
| TS2465 | await only in async function | `infer_await_expression_type` |
| TS2467 | Catch clause variable type | `check_try_statement` |
| TS2764 | yield expression implicitly any | `infer_yield_expression_type` |
| TS2770 | yield operand type in async generator | `check_yield_operand_then_member` |
| TS2771 | Type referenced in then method | `check_promise_then_circular_reference` |

### BigInt Errors (2736-2737)
| Code | Description | Implementation Location |
|------|-------------|------------------------|
| TS2736 | Unary '+' cannot apply to bigint | `infer_unary_expression_type` |
| TS2737 | BigInt literals not available for target < ES2020 | `infer_type` (BigIntLiteral) |

### Abstract Class Errors (2515-2517)
| Code | Description | Implementation Location |
|------|-------------|------------------------|
| TS2515 | Non-abstract class must implement abstract member | `check_abstract_member_implementation` |
| TS2516 | Abstract methods only in abstract class | `check_abstract_members_in_non_abstract_class` |

### Overload Errors (2383-2394)
| Code | Description | Implementation Location |
|------|-------------|------------------------|
| TS2383 | Overload signatures must all be ambient or non-ambient | `check_ambient_consistency` |
| TS2388 | Function overload must not be static | `validate_method_overloads` |
| TS2389 | Implementation signature not assignable | `check_impl_param_type_compatibility` |
| TS2390 | Constructor implementation is missing | `check_class_constructor_overloads` |
| TS2391 | Function implementation is missing | `validate_overloads` |
| TS2394 | Overload signature not compatible with implementation | `check_overload_compatibility` |

### Control Flow Analysis Errors
| Code | Description | Implementation Location |
|------|-------------|------------------------|
| TS2367 | Condition will always return same value | `check_equality_type_overlap` |
| TS2773 | Condition always true (function) | `check_condition_always_true` |
| TS2774 | Condition will always return true | `check_condition_always_true` |

### Enum Errors
| Code | Description | Implementation Location |
|------|-------------|------------------------|
| TS2474 | const enum member initializers | `check_enum_member_value` |
| TS2651 | Member initializer forward reference | `check_enum_initializer_forward_reference` |

### Private Field Errors
| Code | Description | Implementation Location |
|------|-------------|------------------------|
| TS2810 | Property can only be assigned with 'this' | `check_private_field_this_access` |

### Comment Directive Errors
| Code | Description | Implementation Location |
|------|-------------|------------------------|
| TS2578 | Unused '@ts-expect-error' directive | `check_unused_ts_expect_error_directives` |

### Other Errors
| Code | Description | Implementation Location |
|------|-------------|------------------------|
| TS2496 | arguments in arrow function | `infer_identifier_type` |
| TS2511 | Cannot create instance of abstract class | `infer_new_expression_type` |
| TS2538 | Type cannot be used as index | `infer_element_access_type` |
| TS2540 | Cannot assign to readonly property | `check_readonly_assignment` |
| TS2542 | Index signature only permits reading | Binary expression checking |
| TS2548 | Type is not array or string | Array iteration checking |
| TS2551 | Property does not exist, did you mean? | `infer_property_access_type` |
| TS2554 | Expected N arguments but got M | `check_function_call_args` |
| TS2558 | Cannot infer type parameter | Type argument inference |
| TS2565 | Property used before assigned | `check_property_use_before_assignment` |
| TS2576 | Property is static member | `infer_property_access_type` |
| TS2588 | Readonly mutation | Readonly checking |
| TS2695 | Left side of comma operator unused | `infer_binary_expression_type` |
| TS2729 | Property used before initialization | `check_property_forward_reference` |
| TS2748 | Cannot access before initialization | `check_variable_self_reference` |
| TS2700 | Rest types from object types | `check_type_alias_declaration` |
| TS2701 | Object rest assignment must be variable | Binary expression checking |
| TS2716 | Index signature param type | `check_interface_declaration` |
| TS2745 | Property incompatible with index signature | `check_interface_declaration` |
| TS2746 | Property has conflicting declarations | `check_interface_declaration` |
| TS2747 | new expression lacks construct signature | `infer_new_expression_type` |
| TS2762 | Spread types from object types | `infer_object_literal_type` |
| TS2769 | No overload matches this call | `infer_call_expression_type` |
| TS17009 | super must be called before this | `infer_this_type` |

### Type Complexity Errors
| Code | Description | Implementation Location |
|------|-------------|------------------------|
| TS2590 | Expression produces union too complex | `union_type` |
| TS2742 | Inferred type cannot be named | `check_inferred_type_accessibility` |

### Name Resolution (Specialized)
| Code | Description | Implementation Location |
|------|-------------|------------------------|
| TS2579 | Cannot find name (test runner) | `infer_identifier_type` |
| TS2580 | Cannot find name (DOM/browser) | `infer_identifier_type` |
| TS2584 | Cannot find name (ES library) | `infer_identifier_type` |
| TS2591 | Cannot import type declaration files | `check_import_declaration` |

---

## ❌ NOT IMPLEMENTED - Prioritized List

### 🟢 LOW PRIORITY - Rare/Edge Cases

#### Module/Import Resolution (Requires cross-file compilation)
| Code | Description | MismatchReason Variant |
|------|-------------|----------------------|
| TS2305 | Module has no exported member | `ModuleHasNoExportedMember` |
| TS2306 | File is not a module | `FileIsNotModule` |
| TS2307 | Cannot find module | `CannotFindModule` |
| TS2318 | Cannot find global type | `CannotFindGlobalType` |
| TS2692 | Cannot find module or type declarations | `CannotFindModuleOrTypeDeclarations` |


#### Module Export Conflicts (Partially implemented, remaining require cross-file)
| Code | Description | MismatchReason Variant |
|------|-------------|----------------------|
| TS2497 | Module can only be referenced with ES import | `ModuleCanOnlyBeReferencedWithESImport` |
| TS2527 | Inferred type references inaccessible type | `InferredTypeReferencesInaccessible` |
| TS2649 | Cannot augment module | `CannotAugmentModule` |
| TS2686 | Refers to UMD global | `RefersToUMDGlobal` |
| TS2688 | Cannot find type definition file | `CannotFindTypeDefinitionFile` |

---

## Implementation Roadmap

### ✅ Phase 1: High-Impact Quick Wins (COMPLETED)
1. ~~**TS2376** - Super call must be first statement~~ ✅
2. ~~**TS2736** - Unary plus on bigint~~ ✅
3. ~~**TS2406/TS2487** - for-in/for-of left side validation~~ ✅
4. ~~**TS2368** - Reserved type parameter names~~ ✅

### ✅ Phase 2: Abstract Class Support (COMPLETED)
1. ~~**TS2515** - Abstract member not implemented~~ ✅
2. ~~**TS2516** - Abstract method in non-abstract class~~ ✅
3. ~~**TS2517** - Non-abstract member declared abstract~~ ✅ (covered by TS2516)

### ✅ Phase 3: Overload System Improvements (COMPLETED)
1. ~~**TS2391** - Function implementation missing~~ ✅
2. ~~**TS2394** - Overload compatibility~~ ✅
3. ~~**TS2383** - Ambient/non-ambient mismatch~~ ✅
4. ~~**TS2390** - Constructor implementation missing~~ ✅

### ✅ Phase 4: Control Flow Analysis (COMPLETED)
1. ~~**TS2367** - Condition always same value~~ ✅
2. ~~**TS2773** - Condition always true (function)~~ ✅
3. ~~**TS2774** - Condition always true (truthy value)~~ ✅

### ✅ Phase 5: Remaining Overload Errors (COMPLETED)
1. ~~**TS2388** - Function overload must not be static~~ ✅
2. ~~**TS2389** - Implementation signature type mismatch~~ ✅

### ✅ Phase 6: Type Parameter Errors (COMPLETED)
1. ~~**TS2706** - Required type param after optional~~ ✅
2. ~~**TS2707** - Generic type requires N-M type args~~ ✅

### ✅ Phase 7: Parameter Errors (COMPLETED)
1. ~~**TS2369** - Parameter property only in constructor~~ ✅
2. ~~**TS2371** - Parameter initializer only in function~~ ✅
3. ~~**TS2372** - Parameter cannot reference itself~~ ✅

### ✅ Phase 8: BigInt Errors (COMPLETED)
1. ~~**TS2737** - BigInt literals not available when targeting < ES2020~~ ✅

### ✅ Phase 9: Comma Operator Errors (COMPLETED)
1. ~~**TS2695** - Left side of comma operator unused~~ ✅

### ✅ Phase 10: Property/Index Edge Cases (COMPLETED)
1. ~~**TS2729** - Property used before initialization~~ ✅
2. ~~**TS2748** - Cannot access before initialization~~ ✅
3. ~~**TS2459** - Type has no property and no string index~~ ✅ (uses TS2339 for property access)
4. ~~**TS2460** - Type is not an array type~~ ✅

### ✅ Phase 11: Rest/Spread Edge Cases (COMPLETED)
1. ~~**TS2566** - Rest element cannot contain binding pattern~~ ✅ (parser)
2. ~~**TS2574** - Rest element type must be array~~ ✅
3. ~~**TS2702** - Object rest assignment may not be optional~~ ✅ (parser)

### ✅ Phase 12: Const Enum Errors (COMPLETED)
1. ~~**TS2475** - const enum usage restriction~~ ✅
2. ~~**TS2476** - const enum member access restriction~~ ✅

### ✅ Phase 13: Yield/Async Generator (COMPLETED)
1. ~~**TS2764** - yield expression implicitly any~~ ✅
2. ~~**TS2770** - yield operand type in async generator~~ ✅
3. ~~**TS2771** - Type referenced in then method~~ ✅

### ✅ Phase 14: Module/Import Resolution (PARTIAL)
1. ~~**TS2691** - Import path cannot end with extension~~ ✅
2. ~~**TS2709** - Cannot use namespace as type~~ ✅
3. **TS2305, TS2306, TS2307, TS2318, TS2692, TS2694, TS2710** - Require cross-file compilation support

### ✅ Phase 15: Module Export Conflicts (PARTIAL)
1. ~~**TS2484** - Export declaration conflicts~~ ✅
2. ~~**TS2502** - Class references itself in base expression~~ ✅
3. ~~**TS2651** - Member initializer forward reference~~ ✅
4. ~~**TS2687** - All declarations must have identical modifiers~~ ✅
5. **TS2494, TS2497, TS2527, TS2649, TS2686, TS2688** - Require cross-file compilation or complex tracking

---

## File References

- **Error Code Definitions**: `compiler/symbol.mbt` (DiagnosticCode enum)
- **Mismatch Reasons**: `compiler/type_errors.mbt` (MismatchReason enum)
- **Main Type Checker**: `compiler/checker.mbt` (detection logic)
- **Overload Checker**: `compiler/overload_checker.mbt` (overload validation)

---

*Last Updated: 2025-12-02*
*Total Tests: 3191 passing*
