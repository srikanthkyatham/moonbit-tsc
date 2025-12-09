# Destructuring Defaults Type Checking - Current Limitation

## Summary

Partial implementation of destructuring defaults type checking has been added, but it **does not yet support** the specific patterns tested in for-of46.ts and for-of47.ts.

## What Was Implemented

The following infrastructure was added to `checker.mbt`:

1. **`check_binding_pattern_initializers()`** - Entry point that checks initializers in for-of patterns
2. **`check_binding_pattern_initializers_recursive()`** - Recursively traverses binding patterns
3. **`check_binding_element_initializer()`** - Validates initializer type against declared variable type

These functions are called in `check_for_of_statement()` before pushing the loop scope, allowing them to check against pre-declared variables.

## What Works

The implementation works for **VariableStatement contexts** where variables are declared with `var`, `const`, or `let` inside the for-of loop:

```typescript
// This pattern would work (if variables were pre-declared in outer scope):
for (var [k = defaultValue, v = otherDefault] of map) {
  // k and v can be type-checked
}
```

## What Doesn't Work (for-of46.ts & for-of47.ts)

The failing tests use **assignment expression contexts** without var/const/let:

### for-of46.ts
```typescript
var k: string, v: boolean;  // Pre-declared in outer scope
var map = new Map([["", true]]);
for ([k = false, v = ""] of map) {  // ❌ Assignment context, not declaration
    k;
    v;
}
```

Expected errors:
- Line 3: Type 'boolean' is not assignable to type 'string' (for k = false)
- Line 3: Type 'string' is not assignable to type 'boolean' (for v = "")

### for-of47.ts
```typescript
var x: string, y: number;  // Pre-declared in outer scope
var array = [{ x: "", y: true }]
enum E { x }
for ({x, y: y = E.x} of array) {  // ❌ Assignment context
    x;
    y;
}
```

Expected error:
- Line 4: Type 'boolean' is not assignable to type 'number' (y property from array)

## Why It Doesn't Work

When there's no `var/const/let` in the for-of initializer, the parser creates a different AST structure:
- Instead of a `VariableStatement` with a `BindingElement`
- It creates an assignment expression structure

The current implementation in `check_binding_pattern_initializers()` only handles `VariableStatement` cases and skips other node types.

## What Would Be Needed

To support for-of46.ts and for-of47.ts patterns, we would need to:

1. **Parse Assignment Expressions with Destructuring**
   - Recognize patterns like `for ([k = 1, v = 2] of arr)`
   - Extract the destructuring pattern and default values from assignment context

2. **Handle AssignmentExpression Nodes**
   - Extend `check_binding_pattern_initializers()` to match on `AssignmentExpression`
   - Extract the left-hand side pattern and traverse it

3. **Lookup Pre-Declared Variables**
   - For each identifier in the assignment pattern, look up its declared type
   - This part is already implemented in `check_binding_element_initializer()`

4. **Check Defaults Against Declared Types**
   - Validate that default values are assignable to the pre-declared types
   - This logic exists but needs to be reachable from assignment contexts

## Impact on Conformance

- **for-of46.ts**: 2 expected errors (TS2322)
- **for-of47.ts**: 1 expected error (TS2322)
- **Total impact**: 3.4% conformance (2 tests out of 59)

## Current Status

The partial implementation has been left in place because:
1. It provides infrastructure for future work
2. It doesn't break any existing functionality
3. The helper functions are well-documented with the limitation
4. **All 4320 unit tests pass** ✅

## Recommendation

Given the complexity of supporting assignment expression contexts:
- **Priority**: LOW (3.4% conformance gain)
- **Effort**: HIGH (requires significant parser and checker changes)
- **Value**: LOW (edge case rarely encountered in practice)

**Suggested approach**: Address higher-priority issues first (Map overload resolution, enhanced type checking, etc.) before returning to this feature.

## Related Files

- `/src/moonbit/compiler/checker.mbt`: Lines 872-953 (helper functions)
- `/src/moonbit/compiler/checker.mbt`: Line 14711 (call site in check_for_of_statement)
- `/src/moonbit/FOR_OF_CONFORMANCE_ANALYSIS.md`: Documents the failing tests

## Commit History

- **Commit 2a8c3cbc**: Implemented circular reference detection (Priority 1, +6.8% conformance)
- **Current**: Partial destructuring defaults infrastructure (not yet functional for target tests)
