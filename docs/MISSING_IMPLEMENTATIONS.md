# Missing Implementation in MoonBit CLI

## 1. Triple-Slash Reference Directive Support (`/// <reference path="..." />`)

**Affected projects:** DeclareExportAdded, ext-int-ext, ReferenceResolution

- The compiler doesn't follow `/// <reference path="..." />` directives to include type information from other files
- Example: `consumer.ts` references `ref.d.ts` but can't find `M1` namespace

```typescript
/// <reference path="ref.d.ts" />
// Cannot find name 'M1'
```

## 2. Declaration File (.d.ts) Private Name Analysis

**Affected projects:** 11 projects (declarations_*, outputdir_module_*)

- Error: `"Exported variable 'x' has or is using private name 'd'"`
- This is a declaration emit check that shouldn't error for regular type checking
- The compiler is too strict about private name visibility when `--declaration` mode isn't even enabled

```typescript
export class d {}
export var x: d;  // Error: "using private name 'd'"
```

## 3. Node Module Resolution

**Affected projects:** NodeModulesSearch

- Error: `"Namespace 'm1' has no exported member 'f1'"`
- Not properly resolving modules from `node_modules` directories
- Missing support for `@types` packages

```typescript
import m1 from "m1";  // from node_modules - fails to resolve
```

## 4. Namespace Declaration Parsing in .d.ts

**Affected projects:** declarations_ExportNamespace, declarations_GlobalImport

- Error: `"Unexpected token"` in decl.d.ts
- Cannot parse certain declaration file syntax

## 5. Ambient Module Declarations

**Affected projects:** declarations_GlobalImport

- Issues with global/ambient module declarations (`declare module "..."`)

```typescript
declare module M1 {
    export function f1(): void;
}
// Cannot find globally declared namespaces
```

## 6. `--list-imports` JSON Output

- The CLI returns text format instead of JSON for `--list-imports`, causing fallback to Elixir parser
- Not a breaking issue but indicates incomplete feature

---

## Summary Table

| # | Feature Gap | Error Type | Projects Affected |
|---|-------------|------------|-------------------|
| 1 | Triple-slash references | Cannot find name | 3 |
| 2 | Private name analysis (too strict) | Using private name | 11 |
| 3 | Node module resolution | No exported member | 1 |
| 4 | .d.ts parsing | Unexpected token | 2 |
| 5 | Ambient namespace declarations | Cannot find name | 2 |
| 6 | JSON output for --list-imports | Warnings only | - |

---

## Priority Recommendations

1. **High Priority:** Private name analysis fix (affects 11 projects) - this is a false positive that blocks valid code
2. **Medium Priority:** Triple-slash references and ambient declarations - needed for proper .d.ts support
3. **Lower Priority:** Node module resolution and JSON output - fewer projects affected