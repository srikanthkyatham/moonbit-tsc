# TypeScript Conformance Test Report

## Executive Summary

| Metric | Value |
|--------|-------|
| Total Tests | 5,652 |
| Passed | 3,542 |
| Failed | 2,110 |
| **Pass Rate** | **62.7%** |

*Last updated: December 2024*

## Recent Fixes

### Destructuring Pattern Improvements (December 2024)
- **100% destructuring conformance** (147/147 tests) ✅ COMPLETE
- Key fixes implemented:
  1. **TS1359 - Reserved keyword as binding target**: `{ a: while }` now correctly reports "reserved word cannot be used here"
  2. **TS1186 - Rest element with initializer**: `[...x = a]` now correctly reports "A rest element cannot have an initializer"
  3. **TS1005 - String literal property shorthand**: `{ "while" }` now correctly reports "':' expected"
  4. **Reserved keywords in object literals**: `{ while: 1, for: 2 }` now parses correctly
- Added helper functions:
  - `try_get_reserved_keyword()` - Detects reserved keywords like `while`, `for`, `if`, etc.
  - `try_get_binding_target_with_reserved()` - Returns reserved keywords with flag for TS1359
- Updated `parse_object_property` in `parser_expression.mbt` to allow reserved keywords as property names
- Added 10 new unit tests for destructuring error detection
- All 3,867 unit tests passing

### GlobalThis Property Checking (December 2024)
- **Implemented TS2339 for `this.property` access on `typeof globalThis`**
- Arrow functions at global scope have lexically-bound `this` typed as `typeof globalThis`
- Key changes:
  1. Added `get_global_this_type()` function to create special globalThis object type
  2. Added `is_global_this_type()` helper to identify globalThis type
  3. Added `is_restricted_global_this_property()` for restricted properties like `name`
  4. Modified `infer_this_type` to return globalThis only for arrow functions at global scope
  5. Regular functions have dynamic `this` (typed as `any`) - no property restrictions
  6. Fixed `type_to_string` to display `typeof globalThis` correctly
- Behavior:
  - `this.name` in arrow function at global scope → **ERROR** (TS2339)
  - `this.age` in arrow function at global scope → OK (not a restricted property)
  - `this.name` in regular function → OK (dynamic `this`)
  - `this.name` in class method → OK (class instance `this`)
- Added 6 new unit tests for globalThis property access
- Arrow function conformance: **100% (47/47 tests)**
- All 3,609 unit tests passing

### Strict Mode Support (December 2024)
- **Implemented TS1210 error for strict mode reserved identifiers**
- Class bodies are automatically in strict mode per ES6 specification
- `arguments` and `eval` cannot be used as parameter names in:
  - Class methods
  - Constructors
  - Setters
- Key changes:
  1. Added `InvalidUseOfInStrictMode(String)` to `ParserErrorCode` enum
  2. Added `bind_parameters_with_strict` function in binder
  3. Class member binding now passes `is_strict=true` to parameter binding
- **CLI strict mode options added**:
  - `--strict` - Enable all strict type-checking options
  - `--noImplicitAny` - Raise error on expressions with implied 'any' type
  - `--strictNullChecks` - Enable strict null checks
  - `--strictFunctionTypes` - Enable strict checking of function types
- Added 5 new unit tests for TS1210
- Arrow function conformance improved: 94% → **95.7% (45/47 tests)**
- All 3,585 unit tests passing

### Function Hoisting for Forward References (December 2024)
- **Implemented function declaration hoisting** enabling forward references to nested functions
- Fixed "Cannot find name" errors for nested functions called before declaration
- Key changes:
  1. **Two-pass binding in binder**: First pass hoists function names, second pass binds bodies
  2. **Proper overload merging**: Function declarations with same name now properly merge via `declare_symbol`
  3. **Nested vs top-level handling**: Only nested functions are hoisted to local scope; top-level uses global scope for overloads
  4. **Checker hoisting**: Added `get_function_declaration_type` and `hoist_var_declarations` for function types
- Tests now passing:
  - `emitArrowFunctionWhenUsingArguments19_ES6.ts` - Forward reference to nested function
  - All function overload tests continue to work correctly
- Added 6 new unit tests:
  - `unit/hoisting/nested-forward-reference`
  - `unit/hoisting/nested-multiple-functions`
  - `unit/hoisting/nested-recursive`
  - `unit/hoisting/nested-mutual-recursion`
  - `unit/hoisting/top-level-forward-reference`
  - `unit/hoisting/overloads-still-work`
- All 3,580 unit tests passing

### Line Terminator Before Arrow (TS1200) (December 2024)
- **Implemented TS1200 error detection** for line terminators before arrow functions
- Parser now detects newlines between `)` and `=>` and reports proper error
- Key changes:
  1. Added `check_line_terminator_before_arrow` function in parser
  2. Tracks line numbers to detect multi-line arrow function signatures
  3. Reports TS1200: "Line terminator not permitted before arrow"
- Arrow function conformance improved: Tests that should error now correctly error
- Added 3 new unit tests for TS1200 detection
- All 3,574 → 3,580 unit tests passing

### Arguments Built-in Object (December 2024)
- **Added `arguments` object to global scope** as an `IArguments` interface type
- Regular functions can now properly reference the built-in `arguments` object
- Implemented in `init_global_scope` alongside other built-ins like `Math`, `Array`, etc.
- This enables arrow function tests that reference `arguments` in outer function scope

### Mapped Type Expansion (December 2024)
- **Implemented full mapped type expansion** to concrete object types
- `keyof T` operator now correctly extracts property names as a union of string literals
- Mapped types like `{ [K in keyof T]?: T[K] }` now expand to concrete object types when `T` is known
- Key features implemented:
  1. **TypeOperator handling**: Added `keyof`, `typeof`, `readonly`, `unique` operator support in type resolution
  2. **is_keyof flag**: Added to `CheckerIndexAccessType` to distinguish keyof representations from regular index access
  3. **Type parameter substitution**: Properly substitutes type parameters in mapped type constraints
  4. **Modifier handling**: Supports `readonly`, optional (`?`), and required (`-?`) modifiers
- Tests now passing:
  - `MyPartial<T>` - Makes all properties optional
  - `MyReadonly<T>` - Makes all properties readonly (with TS2540 enforcement)
  - `MyRequired<T>` - Removes optional modifiers (with TS2322 for missing properties)
- Added 11 new unit tests for mapped type expansion

### Enum Conformance Improvements (December 2024)
- **Multiple enum test fixes** improving enum conformance:
  1. **TS2432 for namespace enum merging**: Fixed detection of duplicate enum declarations that omit initializers across merged namespaces
     - Added `(Enum, Enum) => true` case to `can_merge_symbols` for proper enum symbol merging in namespace exports
  2. **Object destructuring with default values**: Fixed parsing of `{ value = "123" }` patterns
     - Added `initializer` field to `BindingElement` struct
     - Updated parser to handle `=` in object binding patterns
  3. **TS18033 error location**: Fixed error to point to initializer expression instead of member name
  4. **Empty object type display**: Changed `type_to_string` to display empty objects as `'{}'` instead of `'object'`
- Tests fixed:
  - `enumMergingErrors.ts` - Now correctly reports 2 TS2432 errors
  - `enumErrorOnConstantBindingWithInitializer.ts` - No longer has parse error
  - `enumShadowedInfinityNaN.ts` - Now reports TS18033 with correct location and type display

### Multi-File Test Support (December 2024)
- **Added support for `@filename:` directive** in conformance tests
- Tests with multiple virtual files now properly parsed and executed
- Files written to temp directory and compiled together
- **Pass rate improved: 57.9% → 61.1%** (+3.2%)
- Tests now include 724 multi-file tests previously failing

### Class Declaration Fixes (December 2024)
- **100% classDeclaration test pass rate** (27/27 tests)
- Key fixes implemented:
  1. **Var Hoisting in Methods**: Added proper var hoisting in `infer_method_type`
  2. **TS2376 Conditions**: Only raise when class has initialized/parameter properties
  3. **TS17005**: New error for `super()` in `extends null` classes
  4. **TS17009 Arrow Functions**: Don't check `this` inside arrow functions
  5. **TS17009 Super Arguments**: Check `this` in `super()` arguments before marking super_called

### Template String Type Checking (December 2024)
- **100% template test pass rate** (178/178 tests)
- Template literals now correctly produce:
  - TS2351 when used with `new` operator
  - TS2358 when used as left-hand side of `instanceof`
  - TS2349 when used as a callee (not tagged template)

### Parser Improvements
1. **Generic Method Parsing** - Fixed parsing of generic methods in class declarations
   - `class C { foo<T>() {} }` - now parses correctly
   - `class C { static foo<T>(x: T) {} }` - static generic methods
   - `class C { public bar<U>(y: U) {} }` - with access modifiers

2. **Spread Operator in Function Arguments** - Fixed `...` in function calls
   - `foo(...arr)` - spread as argument
   - `foo(1, ...arr)` - mixed arguments
   - `new Class(...arr)` - in constructor calls

## 100% Pass Rate Categories

The following categories have achieved full conformance:

| Category | Tests |
|----------|-------|
| classes/indexMemberDeclarations | 4/4 |
| enums | 14/14 |
| es5 | 1/1 |
| es6/arrowFunction | 47/47 |
| es6/classDeclaration | 27/27 |
| es6/defaultParameters | 8/8 |
| es6/destructuring | 147/147 |
| es6/moduleExportsCommonjs | 3/3 |
| es6/restParameters | 9/9 |
| es6/shorthandPropertyAssignment | 13/13 |
| es6/templates | 178/178 |
| es6/unicodeExtendedEscapes | 64/64 |
| es6/variableDeclarations | 13/13 |
| es7 | 3/3 |
| expressions/operators | 1/1 |
| expressions/superCalls | 2/2 |
| expressions/valuesAndReferences | 2/2 |
| internalModules/moduleBody | 3/3 |
| pedantic | 2/2 |
| scanner | 1/1 |
| statements/ifDoWhileStatements | 1/1 |
| statements/switchStatements | 1/1 |
| statements/tryStatements | 3/3 |
| statements/withStatements | 1/1 |
| types/unknown | 3/3 |
| types/witness | 1/1 |

## High Pass Rate Categories (>= 80%)

| Category | Pass Rate | Tests |
|----------|-----------|-------|
| enums | 100% | 14/14 |
| esDecorators/classExpression | 94.4% | 17/18 |
| internalModules/exportDeclarations | 95.4% | 21/22 |
| es6/shorthandPropertyAssignment | 100% | 13/13 |
| es2021/logicalAssignment | 90.0% | 9/10 |
| statements/continueStatements | 88.8% | 8/9 |
| decorators/invalid | 85.7% | 12/14 |
| classes/staticIndexSignature | 85.7% | 6/7 |
| es7/exponentiationOperator | 85.7% | 36/42 |
| async/es2017 | 83.3% | 10/12 |
| es6/functionPropertyAssignments | 83.3% | 5/6 |
| types/never | 83.3% | 5/6 |
| statements/for-ofStatements | 83.6% | 46/55 |
| expressions/assignmentOperator | 81.8% | 9/11 |
| statements/breakStatements | 80.0% | 8/10 |
| externalModules/es6 | 80.0% | 12/15 |
| externalModules/esnext | 80.0% | 12/15 |
| es6/newTarget | 80.0% | 4/5 |
| expressions/propertyAccess | 80.0% | 4/5 |
| expressions/thisKeyword | 80.0% | 4/5 |

## ES6 Subcategory Breakdown

| Subcategory | Passed | Total | Rate |
|-------------|--------|-------|------|
| templates | 178 | 178 | 100% |
| classDeclaration | 27 | 27 | 100% |
| unicodeExtendedEscapes | 64 | 64 | 100% |
| variableDeclarations | 13 | 13 | 100% |
| defaultParameters | 8 | 8 | 100% |
| restParameters | 9 | 9 | 100% |
| shorthandPropertyAssignment | 13 | 13 | 100% |
| arrowFunction | 47 | 47 | 100% |
| destructuring | 147 | 147 | 100% |
| yieldExpressions | 61 | 100 | 61% |
| Symbols | 54 | 95 | 57% |
| for-ofStatements | 33 | 59 | 56% |
| functionDeclarations | 7 | 13 | 54% |
| modules | 20 | 39 | 51% |
| spread | 12 | 27 | 44% |
| computedProperties | 60 | 142 | 42% |

## Types Subcategory Breakdown

| Subcategory | Passed | Total | Rate |
|-------------|--------|-------|------|
| unknown | 3 | 3 | 100% |
| witness | 1 | 1 | 100% |
| never | 5 | 6 | 83% |
| tuple | 19 | 27 | 70% |
| conditional | 7 | 10 | 70% |
| nonPrimitive | 11 | 16 | 69% |
| keyof | 4 | 6 | 67% |
| import | 8 | 12 | 67% |
| spread | 16 | 25 | 64% |
| literal | 28 | 44 | 64% |
| rest | 11 | 18 | 61% |
| union | 15 | 25 | 60% |
| thisType | 17 | 30 | 57% |
| any | 5 | 9 | 56% |
| intersection | 13 | 24 | 54% |
| typeAliases | 8 | 15 | 53% |
| members | 15 | 34 | 44% |
| mapped | 11 | 25 | 44% |
| uniqueSymbol | 3 | 7 | 43% |
| stringLiteral | 14 | 33 | 42% |
| namedTypes | 2 | 6 | 33% |
| localTypes | 1 | 5 | 20% |

---

## Top Issues (Error Codes Causing Failures)

### False Positives (Unexpected Errors)
Tests that should compile clean but produce errors:

| Error Code | Count | Description |
|------------|-------|-------------|
| TS1000 | ~500 | Parse error - many are multi-file tests with `@filename:` directives |
| TS2322 | ~100 | Type not assignable |
| TS1005 | ~100 | Expected token (parse error) |
| TS2304 | ~90 | Cannot find name |
| TS1003 | ~80 | Identifier expected |
| TS2300 | ~75 | Duplicate identifier |
| TS2339 | ~65 | Property does not exist on type |
| TS2728 | ~30 | Cannot use namespace as a type |
| TS1036 | ~22 | Statements not allowed in ambient context |
| TS1108 | ~18 | Return statement in ambient context |

### Missing Error Detections
Tests that should report errors but don't:

| Error Code | Count | Description |
|------------|-------|-------------|
| TS2322 | ~70 | Type not assignable |
| TS2728 | ~28 | Cannot use namespace as a type |
| TS5107 | ~20 | Option can only be used with module syntax |
| TS2345 | ~16 | Argument not assignable to parameter |
| TS2343 | ~15 | Can only extend class or interface |
| TS2339 | ~15 | Property does not exist on type |
| TS6210 | ~13 | Import can only be used in TypeScript files |
| TS2208 | ~13 | Cannot compute this expression |
| TS2554 | ~11 | Expected arguments |
| TS2445 | ~10 | Property accessible in derived class only |

---

## Priority Targets for Improvement

### 🔴 High Priority (Parser Issues - Many Tests Affected)

1. **Multi-file test support (`@filename:` directive)**
   - ~400+ tests use `@filename:` to define multiple files
   - Parser needs to handle or skip these directives
   - Could significantly improve pass rate

2. **Spread in types/destructuring** (0% pass rate in spread category)
   - Spread types: `[...T]`, `{...T}`
   - Rest elements in tuple types

3. **Enum support** (100% pass rate - 14/14 tests) ✅ COMPLETE
   - All enum functionality working

4. **Arrow functions** (100% pass rate - 47/47 tests) ✅ COMPLETE
   - ✅ `arguments` built-in object support added
   - ✅ Line terminator before arrow (TS1200) implemented
   - ✅ Function hoisting for forward references
   - ✅ Conformance runner now parses `@target` directives (handles BOM)
   - ✅ TS1210 for strict mode reserved identifiers (arguments/eval)
   - ✅ TS2339 for `this.property` on globalThis in arrow functions

### 🟡 Medium Priority (Type Checking Improvements)

5. **TS2322 - Type Assignment Compatibility** (~100 false positives + ~70 missing)
   - Many type narrowing and inference cases
   - Affects both directions: too strict and too lenient

6. **TS2304/TS2339 - Name Resolution** (~90 + ~65 false positives)
   - Cannot find name / Property does not exist
   - Often related to namespace handling, module augmentation

7. **Symbol support** (11% pass rate)
   - Well-known symbols
   - Symbol.iterator, Symbol.hasInstance, etc.

8. **keyof operator** (0% pass rate)
   - keyof type queries

### 🟢 Lower Priority (Advanced Features)

9. **Mapped Types** (44% pass rate - improved)
    - ✅ Basic mapped type expansion implemented
    - ✅ `keyof T` operator support
    - ✅ Readonly and optional modifiers
    - 🔄 Template literal types in mapped types
    - 🔄 Key remapping

10. **Conditional Types** (30% pass rate)
    - Complex conditional type evaluation
    - Distributive conditional types

---

## Recommended Action Plan

### Phase 1: Quick Wins ✅ Partially Complete
1. ✅ Fixed generic method parsing in classes
2. ✅ Fixed spread operator in function call arguments
3. ✅ Fix enum parsing/checking (0% → 86%, 12/14 tests passing)
4. 🔄 Fix arrow function issues (12% → target 60%)
5. ✅ Improve multi-file test handling

### Phase 2: Core Type Checking
1. Improve type narrowing accuracy
2. Better namespace type handling
3. Argument type checking refinements
4. keyof operator support

### Phase 3: Advanced Features
1. Symbol improvements
2. Mapped type support
3. Conditional type evaluation

---

## Test Categories Needing Most Work

| Category | Current Rate | Gap to 80% | Approx Tests to Fix |
|----------|--------------|------------|---------------------|
| arrowFunction | 100% | ✅ | COMPLETE |
| enums | 100% | ✅ | COMPLETE |
| destructuring | 100% | ✅ | COMPLETE |
| keyof | 0% | 80% | ~5 tests |
| spread (types) | 0% | 80% | ~22 tests |
| Symbols | 11% | 69% | ~65 tests |
| rest | 22% | 58% | ~10 tests |

---

## Changelog

### December 2024 (Update 17)
- **100% destructuring conformance** (147/147 tests) ✅ COMPLETE
- **TS1359 - Reserved keyword as binding target**:
  - Added `try_get_reserved_keyword()` function to detect reserved keywords
  - Added `try_get_binding_target_with_reserved()` function for binding target parsing
  - Updated `parse_object_binding_pattern` to detect and report TS1359 for `{ a: while }`
  - Applied fix to numeric, string literal, computed property, and identifier cases
- **Reserved keywords in object literals**:
  - Updated `parse_object_property` in `parser_expression.mbt` to use `try_get_property_name_with_reserved()`
  - Allows reserved keywords as property names: `{ while: 1, for: 2 }`
  - Shorthand for reserved keywords still requires a colon
- **TS1005 - String literal property shorthand**:
  - Fixed error location to point to current token (where `:` is expected)
- **TS1186 - Rest element with initializer** (parser):
  - Added detection for initializers after rest elements in array binding patterns
  - Reports TS1186 and continues parsing for error recovery
- **Unit tests added** (3,857 → 3,867):
  - 10 tests for destructuring error detection (TS1359, TS1005, TS1186)
- **Pass rate: 61.1% → 62.7%** (+1.6%)

### December 2024 (Update 14)
- **TS18004: Shorthand property scope checking**:
  - Implemented TS18004 error for shorthand properties with undefined identifiers
  - Added `lookup_local_variable` check before `lookup_symbol` for proper scope chain handling
  - Function parameters and local variables now properly resolved in shorthand properties
- **Unit tests added** (3,609 → 3,614):
  - 5 tests for TS18004 shorthand property scenarios
- Shorthand property conformance: **100% (13/13 tests)** ✅ COMPLETE
  - All shorthand property conformance tests now passing
- Enums conformance: **100% (14/14 tests)** ✅ COMPLETE
  - All enum conformance tests now passing

### December 2024 (Update 16)
- **Binding pattern variable registration fixes**:
  - Fixed **catch clause destructuring**: Variables from catch clause binding patterns (e.g., `catch ([a, b])`) now properly registered in scope
    - Added `add_binding_pattern_variables` helper function in checker
    - Modified `check_try_statement` to use `add_binding_pattern_variables` for catch variable registration
  - Fixed **function parameter destructuring**: Variables from function parameter binding patterns now properly registered
    - Modified `bind_parameters_aux` in binder to call `bind_binding_pattern` for ArrayBindingPattern/ObjectBindingPattern
    - Modified `add_parameter_to_scope` in checker to call `add_binding_pattern_variables`
  - Fixed **arrow function parameter destructuring**: Arrow function parameters with binding patterns now work
    - Updated `infer_arrow_function_type` to handle ArrayBindingPattern/ObjectBindingPattern
  - Fixed **function expression parameter destructuring**: Function expression parameters with binding patterns now work
    - Updated `infer_function_expression_type` to iterate original parameters for binding pattern handling
  - Added `add_binding_pattern_variables` helper to recursively register all identifiers from:
    - ArrayBindingPattern (including nested patterns)
    - ObjectBindingPattern (including property renaming)
    - BindingElement (with initializers)
    - SpreadExpression (rest elements)
- **Binder improvements**:
  - Modified `bind_binding_pattern` to handle BindingElement and SpreadExpression nodes
  - This fixes cases like `[a = 1]` (with default) and `[...rest]` (rest element)
- **Unit tests added** (3,694 → 3,706):
  - 5 new binder tests for catch/function parameter destructuring
  - 8 new checker tests for destructuring pattern scenarios
- Destructuring conformance: **79.6% (117/147 tests)**
  - Note: Some tests that were coincidentally passing now correctly show as "should error but passed" because TS1187 is not yet implemented

### December 2024 (Update 15)
- **Destructuring pattern improvements**:
  - Implemented **rest element with nested binding pattern** (`[...[a, b]]`)
    - Array patterns can now have rest elements that destructure into arrays or objects
    - Modified `parse_array_binding_pattern` to handle `OpenBracket` and `OpenBrace` after `...`
  - Implemented **numeric property in object binding** (`{1: x}`)
    - Object binding patterns now support numeric literal property names
    - Added `NumericLiteral` case in `parse_object_binding_pattern`
  - Implemented **string property in object binding** (`{"prop": x}`)
    - Object binding patterns now support string literal property names
    - Added `StringLiteral` case in `parse_object_binding_pattern`
  - Implemented **computed property in object binding** (`{[expr]: x}`)
    - Object binding patterns now support computed property names
    - Added `OpenBracket` case for computed properties in `parse_object_binding_pattern`
  - Implemented **default values for nested patterns** (`[{x} = {x: 0}]`)
    - Nested array/object patterns in array binding can now have default values
    - Modified `parse_array_binding_pattern` to check for `Equals` after nested patterns
  - Implemented **contextual keywords as identifiers** (`{ as }`, `{ as: as }`)
    - Added `try_get_identifier_name` helper function to extract identifier names from tokens
    - Contextual keywords (`as`, `from`, `of`, `type`, `async`, `await`, etc.) can now be used as:
      - Property names in object binding patterns
      - Property names in object literals
      - General identifiers in expressions
    - Updated `parse_identifier` to use `try_get_identifier_name`
    - Restructured `parse_object_binding_pattern` to use the helper for all property types
- **Unit tests added** (359 parser tests, 3683 total tests passing):
  - 57 new tests for destructuring pattern scenarios
- Destructuring conformance: **80.3% (118/147 tests)** (up from 67%)
  - 19 more tests now passing
  - Parse errors reduced from 9 to 0
  - Remaining failures: 10 type errors (iterator types, Map), 2 other, 17 missing errors

### December 2024 (Update 13)
- **GlobalThis property checking (TS2339)**:
  - Implemented `this.property` access checking on `typeof globalThis`
  - Arrow functions at global scope have lexically-bound `this` typed as `typeof globalThis`
  - Regular functions have dynamic `this` (typed as `any`) - no property restrictions
  - Added `get_global_this_type()`, `is_global_this_type()`, `is_restricted_global_this_property()` helpers
  - Fixed `type_to_string` to display `typeof globalThis` correctly
- **Unit tests added** (3,585 → 3,609):
  - 6 tests for globalThis property access scenarios
- Arrow function conformance: **100% (47/47 tests)** ✅ COMPLETE
  - All arrow function conformance tests now passing

### December 2024 (Update 12)
- **Strict mode support (TS1210)**:
  - Implemented TS1210 error for reserved identifiers in strict mode
  - Class bodies are automatically in strict mode per ES6 spec
  - `arguments` and `eval` cannot be used as parameter names in class methods, constructors, setters
  - Added `bind_parameters_with_strict` function in binder
- **CLI strict mode options**:
  - Added `--strict`, `--noImplicitAny`, `--strictNullChecks`, `--strictFunctionTypes` flags
  - `--strict` enables all strict type-checking options
- **Unit tests added** (3,580 → 3,585):
  - 5 tests for TS1210 strict mode reserved identifier checking
- Arrow function conformance: **96% (45/47 tests)**
  - Remaining 2 tests require `this.property` checking on globalThis

### December 2024 (Update 11)
- **Function hoisting for forward references**:
  - Implemented two-pass binding: first hoists function names, then binds bodies
  - Fixed `declare_symbol` to properly merge function overloads
  - Nested functions now hoisted to local scope for forward references
  - Top-level functions use global scope (preserving overload resolution)
  - Added `get_function_declaration_type` helper in checker
- **Line terminator before arrow (TS1200)**:
  - Added `check_line_terminator_before_arrow` function in parser
  - Parser now tracks line numbers and reports TS1200 for newlines before `=>`
- **Arguments built-in object**:
  - Added `arguments` object to global scope as `IArguments` interface type
- **Conformance test runner improvements**:
  - Added `@target` directive parsing (now passes `--target` flag to CLI)
  - Added `@module`, `@strict`, `@noImplicitAny` directive support
  - Fixed BOM (byte order mark) handling in test file parsing
- **Unit tests added** (3,574 → 3,580):
  - 6 tests for function hoisting scenarios
  - 3 tests for TS1200 line terminator detection
- Arrow function conformance: **94% (44/47 tests)**, 0 failures
  - All "Should PASS but failed" tests now passing
  - 3 remaining tests require globalThis property checking (TS2339) and strict mode checking (TS1210)

### December 2024 (Update 10)
- **Inner local scope check for TS2496**:
  - Added `is_in_innermost_scope` function to check if variable exists in innermost local scope only
  - Fixed TS2496 (`arguments` in arrow function) to only trigger when `arguments` is NOT a parameter
  - TS2496 now correctly skips when `arguments` is used as a parameter name in the arrow function
- **Unit tests added**:
  - `TS2496 not triggered when arguments is parameter name`
  - `TS2496 triggered in nested arrow without parameter`
  - `TS2496 no error in ES2015+ target`
- Arrow function conformance: 72% (34/47 tests passing)
- Remaining arrow function failures: Need `arguments` built-in object in regular functions
- All 3,565 unit tests passing

### December 2024 (Update 9)
- **Array destructuring parsing improvements**:
  - Added support for rest elements in array binding patterns: `[...rest]`, `[a, ...rest]`
  - Added support for default values in array binding patterns: `[a = 1]`, `[a, b = 2]`
  - Added `BindingElement` variant to Node enum for elements with initializers
  - Updated parser, emitter, and transformer to handle new node type
- Arrow function conformance improved: 59% → 61%
- Tests now passing:
  - `emitArrowFunctionES6.ts` - Complex destructuring patterns in arrow parameters
- All 3,554 unit tests passing

### December 2024 (Update 8)
- **TS2496 arguments check improvements**:
  - Fixed to only trigger when `arguments` is NOT a parameter of the current arrow function
  - Added `is_in_innermost_scope` helper to check if variable is in the current arrow function's scope
  - Fixed to only trigger for ES3/ES5 targets (not ES2015+) per TypeScript spec
  - Fixed `compile_source` in `ffi.mbt` to pass `options.target` to type checker (was defaulting to ESNext)
- Unit tests updated:
  - TS2496 test now uses `check_source_with_target(source, @compiler.ES5)` for proper target
- All 3,554 unit tests passing

### December 2024 (Update 7)
- **Arrow function return type inference**:
  - Added `infer_return_type_from_block` function to collect return types from block bodies
  - Added `collect_return_types_from_statement` to recursively analyze if/switch/try statements
  - Arrow functions with block bodies now correctly infer return type from return statements
  - `() => { return true; }` now correctly infers as `() => boolean` instead of `() => void`
- Tests improved:
  - Arrow function tests that should pass: 24/24 (100%)
  - Callback matching with block body arrow functions now works
- Total unit tests: 3,554 (all passing)

### December 2024 (Update 6)
- **Mapped type expansion to concrete object types**:
  - Added `TypeOperator` handling in `get_type_from_type_node` for `keyof`, `typeof`, `readonly`, `unique`
  - Added `is_keyof` flag to `CheckerIndexAccessType` struct
  - Implemented `resolve_type_alias_type_with_args` for type argument substitution
  - Implemented `expand_mapped_type_with_subst` for mapped type expansion
  - Updated `get_keyof_target` to recognize keyof representations
- Tests now passing:
  - `MyPartial<T>` correctly makes properties optional
  - `MyReadonly<T>` enforces readonly with TS2540 errors
  - `MyRequired<T>` enforces required properties with TS2322 errors
- Added 11 new unit tests for mapped types
- Total unit tests: 3,554 (all passing)

### December 2024 (Update 5)
- **Enum conformance improvements**:
  - Fixed TS2432 detection for merged enums in namespaces (added Enum+Enum merge support)
  - Fixed object destructuring with default values (`{ value = "123" }`)
  - Fixed TS18033 error location to point to initializer expression
  - Fixed empty object type display (`'{}'` instead of `'object'`)
- Tests fixed: `enumMergingErrors.ts`, `enumErrorOnConstantBindingWithInitializer.ts`, `enumShadowedInfinityNaN.ts`
- Added 11 new unit tests for these fixes

### December 2024 (Update 4)
- **Multi-file test support** via `@filename:` directive parsing
- Conformance test runner now properly handles tests with multiple virtual files
- Tests count increased from 3,706 → 5,652 (now includes all multi-file tests)
- **Pass rate: 61.1%** (3,451/5,652 tests)
- Failure breakdown:
  - Should PASS but failed: 1,302 (716 parse errors, 239 type errors, 347 other)
  - Should ERROR but passed: 899

### December 2024 (Update 3)
- **100% classDeclaration pass rate** (27/27 tests)
- Fixed var hoisting in class methods (`infer_method_type`)
- Fixed TS2376 to only trigger for classes with initialized/parameter properties
- Added TS17005 error for `super()` calls in `extends null` classes
- Fixed TS17009 to not check `this` inside arrow functions
- Fixed TS17009 to check `this` in `super()` arguments before marking super_called
- **Pass rate: 57.9%** (2,148/3,706 tests)

### December 2024 (Update 2)
- Fixed template string type checking - now at 100% pass rate (178/178)
- Template literals correctly produce TS2351, TS2358, TS2349 errors
- **Pass rate improved: 39% → 58.3%** (2,232 → 3,320 tests)
- Note: Pass rate now correctly accounts for tests that SHOULD produce errors

### December 2024 (Initial)
- Fixed generic method parsing (`foo<T>()`) in class declarations
- Fixed spread operator (`...`) parsing in function call arguments
- Updated test count to 5,688 (full conformance suite)
- Pass rate: 39% (2,232 tests)
- Added detailed category and subcategory breakdowns
