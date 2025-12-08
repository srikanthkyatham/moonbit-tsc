# Contextual Keyword Parser Bug - Partial Fix

**Date**: 2025-12-08
**Status**: 🚧 Partial Fix (function declarations work, function calls need more work)
**Related**: history/2025-12-08-parser-bug-contextual-keywords.md

## Summary

Successfully fixed contextual keyword handling in function **declarations**, but discovered that function **calls** require additional work in the v2 expression parser.

## What Was Fixed

### 1. Function Declarations ✅

**Problem**: Functions could not be declared with contextual keyword names like `from`, `as`, `of`, `await`, `yield`.

**Solution**: Modified `parse_function_declaration` in `parser.mbt` (lines 2308-2317) to use `try_get_identifier_name` helper:

```moonbit
// BEFORE (only handled specific keywords):
let (name, parser) = match current_token(parser) {
  Identifier(id_name, loc) => ...
  KeywordDeclare(loc) => ...
  KeywordAsync(loc) => ...
  KeywordUsing(loc) => ...
  _ => (None, parser)
}

// AFTER (handles ALL contextual keywords):
let (name, parser) = match try_get_identifier_name(current_token(parser)) {
  Some((id_name, loc)) =>
    (
      Some(Node::Identifier(Identifier::{ name: id_name, location: loc })),
      advance_parser(parser),
    )
  None => (None, parser) // Anonymous function - no error, name is optional
}
```

**Result**: Functions can now be declared with contextual keyword names:

```typescript
type A = { x: number }
function from<T>() {}  // ✅ Works now!
function as() {}       // ✅ Works now!
function of() {}       // ✅ Works now!
function await() {}    // ✅ Works now!
function yield() {}    // ✅ Works now!
```

### 2. Primary Expression Parser (v1) ✅

**Problem**: The v1 primary expression parser didn't handle contextual keywords as identifiers in expression position.

**Solution**: Modified `parse_primary_expression` in `parser_expression.mbt` (lines 1704-1716) to add a fallback case that uses `try_get_identifier_name`:

```moonbit
// Before the default error case, added:
_ =>
  match try_get_identifier_name(token) {
    Some((name, loc)) =>
      Ok(
        (
          Node::Identifier(Identifier::{ name, location: loc }),
          advance_parser(parser),
        ),
      )
    None => Err(add_error(parser, "Unexpected token", token.location()))
  }
```

**Result**: Contextual keywords can be used as identifiers in expressions when using the v1 parser.

## What Still Needs Work

### Function Calls Failing ❌

**Problem**: Even though function declarations work, calling functions with contextual keyword names still fails:

```typescript
function from() {}
from()  // ❌ Error: TS1000: Unexpected token
```

**Root Cause**: The parser uses a v2 expression parser (`parser_v2_expression.mbt`) by default, which has its own identifier/primary expression parsing logic that doesn't go through `parse_primary_expression`.

**Call Chain**:
```
parse_statement()  →  parser.mbt:1025
  parse_expression_statement()  →  parser.mbt:2845
    parse_expression()  →  parser_expression.mbt:115
      parse_expression_v2()  →  parser_v2_expression.mbt:31
        parse_assignment_expression_v2()  →  parser_v2_expression.mbt:123
          parse_conditional_expression_v2()  →  ??? (need to trace further)
            ... eventually gets to parsing identifiers/atoms ...
```

**Investigation Needed**:
1. Trace v2 expression parsing to find where identifiers are parsed
2. Apply similar fix using `try_get_identifier_name`
3. Ensure contextual keywords work in ALL expression contexts, not just primary expressions

## Files Modified

### parser.mbt
- **Lines 2308-2317**: Changed function name parsing to use `try_get_identifier_name`
- **Result**: Allows all contextual keywords as function names

### parser_expression.mbt
- **Lines 1704-1716**: Added fallback case for contextual keywords in primary expressions
- **Result**: v1 expression parser handles contextual keywords (but v2 is used by default)

## Testing Results

### What Works ✅

```bash
CLI="/path/to/cli.exe"

# Test: Function declarations with contextual keywords
for name in "from" "as" "of" "await" "yield"; do
  cat > test.ts << EOF
type A = { x: number }
function $name<T>() {}
EOF
  $CLI test.ts --noEmit  # ✅ All pass
done
```

### What Doesn't Work ❌

```bash
# Test: Function calls with contextual keywords
cat > test.ts << 'EOF'
function from() {}
from()
EOF
$CLI test.ts --noEmit  # ❌ Error: TS1000: Unexpected token

# Test: Expression statements with contextual keywords
cat > test.ts << 'EOF'
const x = from
EOF
$CLI test.ts --noEmit  # ❌ Error: TS1000: Unexpected token

# Test: symbolProperty61.ts
$CLI symbolProperty61.ts --noEmit  # ❌ Still fails on line 32: from(...)
```

## Next Steps

### Immediate TODO

1. **Find v2 primary expression/atom parsing**:
   - Search `parser_v2_expression.mbt` for where identifiers are initially parsed
   - Look for functions like `parse_atom`, `parse_unary`, or similar
   - Find where `Identifier(...)` tokens are matched in the v2 parser

2. **Apply fix in v2 parser**:
   - Use `try_get_identifier_name` to convert contextual keywords to identifiers
   - Ensure all expression contexts handle contextual keywords:
     - Call expressions: `from()`
     - Member access base: `from.property`
     - Variable references: `const x = from`
     - Tagged templates: `from\`template\``

3. **Test comprehensively**:
   - Function calls: `from()`
   - Method calls: `obj.from()`
   - Variable references: `const x = from`
   - All expression contexts where identifiers can appear

4. **Verify no regressions**:
   - Run full test suite
   - Check that contextual keywords still work as keywords in their proper contexts:
     - `import { x } from 'module'` - `from` should still be a keyword here
     - `for (const x of array)` - `of` should still be a keyword here
     - `import { x as y }` - `as` should still be a keyword here

### Long-term Considerations

**Why do contextual keywords exist?**

Contextual keywords are a language design choice to allow backwards compatibility. TypeScript/JavaScript want to add new keywords without breaking existing code that uses those words as identifiers.

- `from` - Added for ES6 modules, but can be used as identifier elsewhere
- `as` - Added for type assertions and import aliases, but can be identifier
- `of` - Added for for-of loops, but can be identifier
- `await` - Added for async/await, but can be identifier in non-async contexts
- `yield` - Added for generators, but can be identifier outside generators

The parser needs to be **context-aware**: recognize these as keywords in their specific syntactic positions, but allow them as identifiers everywhere else.

**Current Implementation**:

The `try_get_identifier_name` function in `parser.mbt:9591` already handles this correctly - it converts contextual keyword tokens to identifier strings. The fix is just about calling this function in more places.

## Testing Commands

```bash
CLI="/path/to/cli.exe"

# Test 1: Function declarations (WORKING)
echo "type A = { x: number }
function from<T>() {}" > test.ts
$CLI test.ts --noEmit

# Test 2: Function calls (NOT WORKING YET)
echo "function from() {}
from()" > test.ts
$CLI test.ts --noEmit

# Test 3: symbolProperty61.ts (NOT FULLY WORKING YET)
$CLI /path/to/symbolProperty61.ts --noEmit
```

## References

- Original bug report: `history/2025-12-08-parser-bug-contextual-keywords.md`
- Test results showing which keywords fail: See bug report
- `try_get_identifier_name` helper: `parser.mbt:9591-9628`
- v1 expression parser: `parser_expression.mbt`
- v2 expression parser: `parser_v2_expression.mbt` (needs work)
