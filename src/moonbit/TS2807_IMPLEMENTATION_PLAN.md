# TS2807 Implementation Plan: Multi-File Compilation

**Status**: Phase 1-2 Complete, Phase 3 In Progress
**Date**: December 11, 2025

## Overview

This document outlines the implementation plan for TS2807 error detection in the MoonBit TypeScript compiler. The TS2807 error occurs when code requires an imported helper (like `__spreadArray`) with a specific signature, but the imported version from `tslib` has an incompatible signature.

## Background

### What is TS2807?

TS2807 is a TypeScript diagnostic that detects version mismatches in emit helpers. For example:

```typescript
// @importHelpers: true
// @filename: tslib.d.ts
export function __spreadArray(to: any[], from: any[]): any[];

// @filename: test.ts
const a = [1, 2, 3];
const b = [...a];  // Error: TS2807
```

**Error Message**:
```
This syntax requires an imported helper named '__spreadArray' with 3 parameters,
which is not compatible with the one in 'tslib'. Consider upgrading your version of 'tslib'.
```

The error occurs because the spread operator requires `__spreadArray(to, from, pack)` (3 params), but the imported tslib only provides `__spreadArray(to, from)` (2 params).

## Completed Work

### Phase 1: Directive Parsing Infrastructure ✅

**Files Modified**:
- `compiler/token.mbt` - Added `CompilerDirective` token kind
- `compiler/scanner_comments.mbt` - Added directive detection in scanner
- `compiler/ast.mbt` - Added `CompilerDirectives` struct
- `compiler/parser.mbt` - Added `parse_compiler_directives()` function
- `compiler/symbol.mbt` - Made `trim_whitespace()` public

**Functionality**:
- Scanner detects `// @importHelpers`, `// @filename`, `// @target`, etc.
- Parser extracts directive values and stores in `SourceFile.compiler_directives`
- All directive values are properly trimmed

**Tests**: 9 tests in `compiler_directives_test.mbt` - all passing

### Phase 2: Virtual File Splitting ✅

**Files Modified**:
- `compiler/ast.mbt` - Added `TestVirtualFile` and `TestVirtualFileSet` structs
- `compiler/parser.mbt` - Added `split_by_filename_directives()` function

**Functionality**:
- Splits multi-file test sources by `// @filename:` directives
- Tracks start line numbers for each virtual file
- Preserves global directives that apply to all files

**Tests**: 9 tests in `virtual_file_split_test.mbt` - all passing

## Remaining Work

### Phase 3: Multi-File Compilation Context (TODO)

**Goal**: Create a compilation context that can hold and link multiple source files.

**Required Changes**:

1. **Create CompilationContext struct** (`compiler/checker.mbt`):
```moonbit
pub struct CompilationContext {
  source_files : Map[String, SourceFile]  // filename -> SourceFile
  symbol_table : SymbolTable              // Shared symbol table
  type_cache : Map[String, Type]          // Cross-file type cache
  diagnostics : Array[Diagnostic]         // All diagnostics
}
```

2. **Implement multi-file parsing**:
```moonbit
pub fn compile_multi_file(virtual_files : TestVirtualFileSet) -> CompilationContext {
  let ctx = CompilationContext::new()

  // Parse each virtual file
  for vfile in virtual_files.files {
    let tokens = scan_all_v2(vfile.content, vfile.filename)
    match parse_source_file(tokens, vfile.filename) {
      Ok(sf) => ctx.add_source_file(vfile.filename, sf)
      Err(e) => ctx.add_diagnostic(...)
    }
  }

  // Link files together
  ctx.resolve_imports()

  ctx
}
```

3. **Update type checker to use context**:
- Pass `CompilationContext` to `check_program()`
- Allow type checker to look up types across files

**Estimated Complexity**: Medium (2-3 hours)

### Phase 4: Module Resolution System (TODO)

**Goal**: Implement module resolution to find imported symbols across files.

**Required Changes**:

1. **Implement module resolution** (`compiler/resolver.mbt` - new file):
```moonbit
pub struct ModuleResolver {
  context : CompilationContext
}

pub fn resolve_import(
  resolver : ModuleResolver,
  import_path : String,
  current_file : String
) -> SourceFile? {
  // Simple algorithm for virtual files:
  // 1. If import_path is "tslib", look for "tslib.d.ts"
  // 2. If import_path is relative, resolve from current_file
  // 3. Otherwise, look for exact match

  match resolver.context.source_files.get(import_path) {
    Some(sf) => Some(sf)
    None => {
      // Try with .d.ts extension
      let dts_path = import_path + ".d.ts"
      resolver.context.source_files.get(dts_path)
    }
  }
}

pub fn lookup_exported_symbol(
  resolver : ModuleResolver,
  module : SourceFile,
  symbol_name : String
) -> Symbol? {
  // Look through module's exported symbols
  for stmt in module.statements {
    match stmt {
      ExportDeclaration(export) => {
        // Check if export contains symbol_name
        ...
      }
      _ => ()
    }
  }
}
```

2. **Track imports in type checker**:
- When checking `import { __spreadArray } from 'tslib'`, record the import
- Store mapping: symbol name -> (module, original symbol)

**Estimated Complexity**: Medium-High (3-4 hours)

### Phase 5: TS2807 Diagnostic Implementation (TODO)

**Goal**: Implement the TS2807 diagnostic code and add it to the error system.

**Required Changes**:

1. **Add TS2807 to diagnostic enum** (`compiler/symbol.mbt`):
```moonbit
pub enum DiagnosticCode {
  // ... existing codes ...
  TS2807  // This syntax requires an imported helper named '{0}' with {1} parameters
}

pub fn get_diagnostic_message(code : DiagnosticCode) -> String {
  match code {
    // ... existing cases ...
    TS2807 => "This syntax requires an imported helper named '{0}' with {1} parameters, which is not compatible with the one in '{2}'. Consider upgrading your version of '{2}'."
  }
}
```

2. **Create diagnostic reporting function**:
```moonbit
pub fn report_emit_helper_mismatch(
  checker : Checker,
  node : Node,
  helper_name : String,
  required_params : Int,
  actual_params : Int,
  module_name : String
) {
  checker.add_diagnostic(
    Diagnostic::{
      code: TS2807,
      message: format_diagnostic(TS2807, [helper_name, required_params.to_string(), module_name]),
      location: node.location,
      severity: Error
    }
  )
}
```

**Estimated Complexity**: Low (30 minutes)

### Phase 6: Emit Helper Signature Validation (TODO)

**Goal**: Check emit helper signatures when `@importHelpers: true` is used.

**Required Changes**:

1. **Define required helpers** (`compiler/emit_helpers.mbt` - new file):
```moonbit
pub struct EmitHelperSignature {
  name : String
  required_params : Int
  required_for : Array[SyntaxKind]  // Which syntax requires this helper
}

pub fn get_required_helpers() -> Array[EmitHelperSignature] {
  [
    EmitHelperSignature::{
      name: "__spreadArray",
      required_params: 3,
      required_for: [SpreadElement]
    },
    EmitHelperSignature::{
      name: "__assign",
      required_params: 2,
      required_for: [ObjectLiteralExpression]
    },
    // ... other helpers
  ]
}
```

2. **Validate helper in type checker** (`compiler/checker.mbt`):
```moonbit
fn check_spread_element(checker : Checker, node : Node) -> Type {
  // ... existing type checking ...

  // If @importHelpers is enabled, validate helper
  if checker.source_file.compiler_directives.import_helpers {
    validate_emit_helper(checker, node, "__spreadArray", 3)
  }

  result_type
}

fn validate_emit_helper(
  checker : Checker,
  node : Node,
  helper_name : String,
  required_params : Int
) {
  // 1. Look for tslib module in compilation context
  match checker.context.source_files.get("tslib.d.ts") {
    None => return  // No tslib found, skip validation
    Some(tslib) => {
      // 2. Look up the helper function in tslib
      match lookup_exported_symbol(checker.resolver, tslib, helper_name) {
        None => return  // Helper not found, skip
        Some(symbol) => {
          // 3. Get the function signature
          let fn_type = get_type_of_symbol(symbol)
          match fn_type {
            FunctionType(sig) => {
              let actual_params = sig.parameters.length()

              // 4. Compare parameter counts
              if actual_params != required_params {
                report_emit_helper_mismatch(
                  checker,
                  node,
                  helper_name,
                  required_params,
                  actual_params,
                  "tslib"
                )
              }
            }
            _ => ()  // Not a function, skip
          }
        }
      }
    }
  }
}
```

**Estimated Complexity**: Medium (2-3 hours)

## Testing Strategy

### Unit Tests

1. **Multi-file compilation tests** (`compiler/unit_tests/checker/multi_file_test.mbt`):
```moonbit
test "Compile two files with import" {
  let source = #|// @filename: lib.ts
    #|export const x = 42;
    #|// @filename: main.ts
    #|import { x } from './lib';
    #|const y = x + 1;

  match split_by_filename_directives(source) {
    Some(files) => {
      let ctx = compile_multi_file(files)
      assert_eq(ctx.diagnostics.length(), 0)
    }
    None => fail("Expected virtual files")
  }
}
```

2. **Module resolution tests** (`compiler/unit_tests/resolver/module_resolution_test.mbt`):
```moonbit
test "Resolve tslib.d.ts import" {
  let source = #|// @filename: tslib.d.ts
    #|export function __spreadArray(a: any[], b: any[]): any[];
    #|// @filename: test.ts
    #|import { __spreadArray } from 'tslib';

  // Test that tslib.d.ts is correctly resolved
}
```

3. **TS2807 diagnostic tests** (`compiler/unit_tests/checker/emit_helper_test.mbt`):
```moonbit
test "TS2807 - __spreadArray signature mismatch" {
  let source = #|// @importHelpers: true
    #|// @filename: tslib.d.ts
    #|export function __spreadArray(to: any[], from: any[]): any[];
    #|// @filename: test.ts
    #|const a = [1, 2];
    #|const b = [...a];

  match compile_and_check(source) {
    Ok(ctx) => {
      assert_eq(ctx.diagnostics.length(), 1)
      assert_eq(ctx.diagnostics[0].code, TS2807)
    }
    Err(_) => fail("Compilation failed")
  }
}
```

### Integration Tests

1. **Run arraySpreadImportHelpers.ts conformance test**:
```bash
$CLI /Users/.../typescript-repo/tests/cases/conformance/es6/spread/arraySpreadImportHelpers.ts --noEmit --reportDiagnostics
```

Expected output:
```
arraySpreadImportHelpers.ts(5,11): error TS2807: This syntax requires an imported helper named '__spreadArray' with 3 parameters, which is not compatible with the one in 'tslib'. Consider upgrading your version of 'tslib'.
```

## Implementation Order

### Recommended Sequence:

1. **Phase 3** - Multi-file compilation context (Foundation)
2. **Phase 4** - Module resolution (Required for Phase 6)
3. **Phase 5** - TS2807 diagnostic (Simple addition)
4. **Phase 6** - Emit helper validation (Brings it all together)

### Alternative: Incremental Approach

If time is limited, implement in smaller chunks:

1. **Chunk 1**: Basic multi-file parsing (no imports yet)
   - Parse virtual files into separate SourceFiles
   - Test that each file parses correctly

2. **Chunk 2**: Simple import resolution (name-based only)
   - Resolve imports by exact filename match
   - No path resolution yet

3. **Chunk 3**: Symbol lookup across files
   - Find exported symbols in other files
   - Basic cross-file type checking

4. **Chunk 4**: TS2807 implementation
   - Add diagnostic code
   - Implement emit helper validation
   - Test with arraySpreadImportHelpers.ts

## Estimated Total Time

- **Phase 3**: 2-3 hours
- **Phase 4**: 3-4 hours
- **Phase 5**: 30 minutes
- **Phase 6**: 2-3 hours
- **Testing & Debug**: 2-3 hours

**Total**: 10-14 hours of development time

## Risk Assessment

### Low Risk:
- ✅ Directive parsing (COMPLETE)
- ✅ Virtual file splitting (COMPLETE)
- Phase 5 (diagnostic code addition)

### Medium Risk:
- Phase 3 (multi-file context - well-defined scope)
- Phase 6 (emit helper validation - straightforward logic)

### High Risk:
- Phase 4 (module resolution - many edge cases possible)
  - Mitigation: Start with simple exact-match resolution
  - Defer complex path resolution for later

## Success Criteria

### Minimum Viable:
1. ✅ Parse `@importHelpers` directive
2. ✅ Split multi-file test sources
3. TODO Parse multiple virtual files
4. TODO Resolve tslib.d.ts import
5. TODO Detect TS2807 error in arraySpreadImportHelpers.ts

### Complete:
- All of the above PLUS
- Cross-file type checking working
- Module resolution handles relative paths
- All emit helpers validated (not just __spreadArray)

## Next Steps

**Immediate**: Begin Phase 3 - Multi-file compilation context
- Create `CompilationContext` struct
- Implement `compile_multi_file()` function
- Write unit tests for multi-file parsing

**After Phase 3**: Proceed to Phase 4 - Module resolution
