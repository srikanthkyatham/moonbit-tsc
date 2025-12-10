# Generic Type Parameter Inference Issue with Spread Arguments

## Problem Summary

When calling generic functions with spread arguments, type parameter inference is not working. The function's type parameters are not being preserved when the function declaration is converted to a function type.

## Example Test Case

```typescript
function foo<T>(...s: T[]) { return s[0]; }
class SymbolIterator {
  next() { return { value: Symbol(), done: false }; }
  [Symbol.iterator]() { return this; }
}
class StringIterator {
  next() { return { value: "", done: false }; }
  [Symbol.iterator]() { return this; }
}
foo(...new SymbolIterator, ...new StringIterator);  // Should error: string not assignable to symbol
```

**Expected**: TS2345 error - T should be inferred as `symbol` from first argument, second argument should fail type check

**Actual**: No error - function call passes type checking

## Root Cause

Debug investigation revealed that when `try_signature()` is called during function call type checking, the `CheckerSignature` for the function has **0 type parameters**, even though the function was declared with `<T>`.

Debug output showed:
```
[DEBUG try_signature] Has 0 type parameters
[DEBUG try_signature] Arg 0: 'symbol' vs expected 'any' = true
[DEBUG try_signature] Arg 1: 'string' vs expected 'any' = true
```

The parameters are type-checked against `any` instead of the inferred type parameter.

## Investigation Path

1. **Binder** (`binder.mbt:886-935`): `bind_function_declaration()` correctly calls `bind_type_parameters()` at line 922
2. **Type Conversion** (`type_convert.mbt:595-599`): `convert_function_sigs()` correctly copies type parameters:
   ```moonbit
   CheckerSignature::{
     parameters: params,
     return_type: ret_ty,
     type_parameters: f.type_params.map(type_param_v2_to_checker),  // ← type params ARE included
   }
   ```

3. **Issue**: The type parameters from the function declaration are not making it into the `FunctionTypeV2.type_params` array before conversion, OR the function type is being looked up/retrieved incorrectly at the call site

## Files Affected

This issue affects 3 of the 9 remaining spread test failures:
- `iteratorSpreadInCall7.ts` - Generic function with incompatible spreads
- `iteratorSpreadInCall8.ts` - Generic class constructor with spreads
- `iteratorSpreadInCall9.ts` - Nested spread in array with generic function

## What Needs To Be Fixed

1. Find where function identifiers are resolved to their types in call expressions
2. Ensure that when looking up a generic function, its type parameters are preserved
3. The issue is likely in how `FunctionTypeV2` is created from function declarations, or how function types are stored/retrieved from the symbol table

## Attempted Fixes

- Added type parameter inference logic to single-signature spread bypass (working code is already in place)
- Enhanced `infer_type_arguments()` to handle multiple spread arguments to rest parameters
- The inference logic itself works correctly when type parameters are present

**The blocker**: Type parameters never reach the call site to begin with.

## Next Steps

This requires deep investigation of:
1. How function declarations are converted to types
2. Where/how function types are stored in the symbol table
3. How function identifiers are resolved at call sites

Estimated effort: 4-8 hours of focused investigation into the type system architecture.
