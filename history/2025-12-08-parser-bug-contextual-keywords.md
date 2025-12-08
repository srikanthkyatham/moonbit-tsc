# Parser Bug: Type Alias + Function with Contextual Keyword Name

**Date**: 2025-12-08
**Severity**: High - Blocks valid TypeScript code from parsing
**Status**: 🐛 Bug Identified

## Summary

The parser fails when a type alias with a type literal body is followed by a function declaration that uses a **contextual keyword** as the function name (e.g., `from`, `as`, `of`, `await`, `yield`).

## Reproduction

### Failing Cases

All of these valid TypeScript programs fail to parse:

```typescript
type A = { x: number }
function from<T>() {}
// Error: TS1005: '(' expected.
// Error: TS1000: Unexpected token
```

```typescript
type A = { x: number }
function as() {}
// Error: TS1005: '(' expected.
// Error: TS1000: Unexpected token
```

```typescript
type A = { x: number }
function of() {}
// Error: TS1005: '(' expected.
// Error: TS1000: Unexpected token
```

```typescript
type A = { x: number }
function await() {}
// Error: TS1005: '(' expected.
// Error: TS1000: Unexpected token
```

```typescript
type A = { x: number }
function yield() {}
// Error: TS1005: '(' expected.
// Error: TS1000: Unexpected token
```

### Working Cases

These parse successfully:

```typescript
type A = { x: number }
function f<T>() {}
// ✅ Works
```

```typescript
type A = { x: number }
function test() {}
// ✅ Works
```

```typescript
type A = { x: number }
function foo() {}
// ✅ Works
```

```typescript
type A = { x: number }
function get() {}
// ✅ Works (even though 'get' is used in getters)
```

```typescript
type A = { x: number }
function set() {}
// ✅ Works (even though 'set' is used in setters)
```

```typescript
type A = { x: number }
function async() {}
// ✅ Works (even though 'async' is a keyword modifier)
```

## Detailed Analysis

### Contextual Keywords That Fail

Tested function names and their results:

| Function Name | Result | Context Where Used as Keyword |
|---------------|--------|-------------------------------|
| `from` | ❌ FAIL | `import { x } from 'module'` |
| `as` | ❌ FAIL | `import { x as y }`, `expr as Type` |
| `of` | ❌ FAIL | `for (const x of array)` |
| `await` | ❌ FAIL | `await promise` |
| `yield` | ❌ FAIL | `yield value` |
| `to` | ✅ OK | Not a keyword |
| `get` | ✅ OK | Used in property getters, but allowed |
| `set` | ✅ OK | Used in property setters, but allowed |
| `async` | ✅ OK | Keyword modifier, but allowed |
| `test` | ✅ OK | Not a keyword |
| `foo` | ✅ OK | Not a keyword |

### Pattern Requirements

The bug ONLY occurs when ALL of these conditions are met:

1. **Type alias declaration** (not interface)
2. **Type alias has a type literal body** (`{ ... }`)
3. **Followed by function declaration**
4. **Function uses contextual keyword as name**

If any condition is missing, the code parses successfully:

```typescript
// ✅ Works - Type alias with simple type (not type literal)
type A = number
function from() {}

// ✅ Works - Interface instead of type alias
interface A { x: number }
function from() {}

// ✅ Works - Type alias with type literal + variable (not function)
type A = { x: number }
const from = 5

// ✅ Works - Type alias with type literal + normal function name
type A = { x: number }
function test() {}
```

## Root Cause Hypothesis

The parser appears to have a lookahead or context issue when:
1. It finishes parsing a type literal body (`}`)
2. It encounters a contextual keyword that could be part of:
   - An import/export statement continuation
   - A type operation (like `as` in type assertions)
   - An expression context

The parser seems to incorrectly interpret the contextual keyword based on the preceding type literal context, rather than recognizing it as starting a new function declaration.

### Parser State Confusion

Likely scenario:
1. Parser successfully parses `type A = { x: number }`
2. Parser sees `function` keyword → enters function declaration parsing
3. Parser sees contextual keyword (e.g., `from`) → gets confused
4. Instead of treating `from` as an identifier (function name), it treats it as a keyword
5. Parser expects different tokens based on keyword interpretation
6. Error: `TS1005: '(' expected` because parser is in wrong state

## Impact

### Affected Code Patterns

Real-world code that fails to parse:

1. **Import-related utilities**:
   ```typescript
   type Options = { strict: boolean }
   function from(source: string) { /* convert from source */ }
   ```

2. **Generator utilities**:
   ```typescript
   type Config = { mode: string }
   function yield(value: any) { /* yield helper */ }
   ```

3. **Async utilities**:
   ```typescript
   type AsyncConfig = { timeout: number }
   function await(promise: Promise<any>) { /* await wrapper */ }
   ```

4. **Collection utilities**:
   ```typescript
   type Collection<T> = { items: T[] }
   function of<T>(...items: T[]) { /* create collection */ }
   ```

### Workarounds

Until fixed, developers must:
1. Rename functions to avoid contextual keywords
2. Reorder declarations (put function before type alias)
3. Use interface instead of type alias
4. Add extra statements between type alias and function

## Test Cases

### Minimal Reproduction

```bash
CLI="/path/to/cli.exe"

# Failing case
cat > test_fail.ts << 'EOF'
type A = { x: number }
function from() {}
EOF
$CLI test_fail.ts --noEmit --reportDiagnostics
# Expected: Success
# Actual: TS1005 and TS1000 errors

# Working case
cat > test_work.ts << 'EOF'
type A = { x: number }
function foo() {}
EOF
$CLI test_work.ts --noEmit --reportDiagnostics
# Expected: Success
# Actual: Success ✅
```

### Comprehensive Test Suite

```bash
#!/bin/bash
CLI="/path/to/cli.exe"

echo "Testing contextual keyword function names after type alias:"
for name in "from" "as" "of" "await" "yield" "to" "get" "set" "async" "test" "foo"; do
  cat > /tmp/test_$name.ts << EOF
type A = { x: number }
function $name<T>() {}
EOF
  result=$($CLI /tmp/test_$name.ts --noEmit --reportDiagnostics 2>&1)
  if echo "$result" | grep -q "error"; then
    echo "  $name: ❌ FAIL (BUG)"
  else
    echo "  $name: ✅ OK"
  fi
done
```

Expected output:
```
Testing contextual keyword function names after type alias:
  from: ❌ FAIL (BUG)
  as: ❌ FAIL (BUG)
  of: ❌ FAIL (BUG)
  await: ❌ FAIL (BUG)
  yield: ❌ FAIL (BUG)
  to: ✅ OK
  get: ✅ OK
  set: ✅ OK
  async: ✅ OK
  test: ✅ OK
  foo: ✅ OK
```

## Discovery Context

This bug was discovered while investigating parse errors in `symbolProperty61.ts`:

```typescript
type InteropObservable<T> = {
    [Symbol.obs]: () => { subscribe(next: (val: T) => void): void }
}

function from<T>(obs: InteropObservable<T>) {  // ← Fails here
    return obs[Symbol.obs]()
}
```

Initially thought to be related to:
- Symbol computed properties
- Nested type literals
- Generic type parameters

But systematic testing revealed it was specifically the function name `from` causing the issue.

## Recommended Fix

The parser needs to:
1. Properly reset context after completing a type alias declaration
2. Allow contextual keywords as function names in statement position
3. Distinguish between contextual keywords used as:
   - Keywords (in their specific syntactic context)
   - Identifiers (as function/variable names)

### Files to Investigate

- `src/moonbit/compiler/parser.mbt` - Main parser, function declaration parsing
- `src/moonbit/compiler/parser_type.mbt` - Type alias parsing
- `src/moonbit/compiler/lexer.mbt` - Token classification and contextual keyword handling

### Specific Areas

1. **Type Alias Completion**: Ensure parser fully exits type parsing mode after `}`
2. **Function Declaration Start**: Verify that `function` keyword properly starts a new parsing context
3. **Identifier vs Keyword**: Check how contextual keywords are distinguished in different contexts
4. **Lookahead Logic**: Review lookahead that might be mis-classifying tokens after type literals

## Priority

**High** - This blocks valid TypeScript code that uses common function names like `from`, `of`, `as`, etc. These are popular names for utility functions (e.g., `Array.from()`, `Observable.from()`, RxJS operators).

## Related Issues

- symbolProperty61.ts parse errors (lines 28-30) - caused by this bug
- Any code using factory functions named after contextual keywords
- Libraries mimicking standard library APIs (Array.from, etc.)

## Next Steps

1. ✅ Document bug with comprehensive test cases
2. ⏳ Investigate parser state machine in parser.mbt
3. ⏳ Implement fix for contextual keyword handling
4. ⏳ Add regression tests for all contextual keywords
5. ⏳ Verify fix doesn't break existing keyword usage in their proper contexts
