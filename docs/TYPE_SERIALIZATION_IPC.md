# Type Serialization Format for Go ↔ MoonBit IPC

## Overview

This document defines the JSON serialization format for TypeScript types exchanged between the Go coordinator and MoonBit workers. The format is designed to:

1. **Be compact** - Minimize IPC payload size
2. **Be complete** - Represent all TypeScript type constructs
3. **Be efficient to parse** - Simple structure for fast deserialization
4. **Support incremental checking** - Pass only necessary type information

---

## Type System JSON Schema

### Base Type Structure

All types share a common structure with a `kind` discriminator:

```typescript
interface SerializedType {
  kind: TypeKind;
  flags?: TypeFlags;
  // Additional properties based on kind
}

type TypeKind =
  | "number" | "string" | "boolean" | "void" | "undefined"
  | "null" | "symbol" | "any" | "unknown" | "never"
  | "object" | "function" | "union" | "intersection" | "array"
  | "tuple" | "literal" | "reference" | "conditional" | "mapped"
  | "template" | "indexAccess" | "infer" | "error";

interface TypeFlags {
  readonly?: boolean;
  optional?: boolean;
}
```

### Primitive Types

Primitives only need kind (and optional flags):

```json
{ "kind": "number" }
{ "kind": "string" }
{ "kind": "boolean" }
{ "kind": "void" }
{ "kind": "undefined" }
{ "kind": "null" }
{ "kind": "any" }
{ "kind": "unknown" }
{ "kind": "never" }
```

### Literal Types

```json
{ "kind": "literal", "literalKind": "number", "value": 42 }
{ "kind": "literal", "literalKind": "string", "value": "hello" }
{ "kind": "literal", "literalKind": "boolean", "value": true }
```

### Object Types (Interfaces, Classes)

```json
{
  "kind": "object",
  "properties": {
    "name": {
      "type": { "kind": "string" },
      "optional": false,
      "readonly": false
    },
    "age": {
      "type": { "kind": "number" },
      "optional": true,
      "readonly": false
    }
  },
  "callSignatures": [...],
  "constructSignatures": [...],
  "indexSignatures": [...]
}
```

**Property Signature:**
```json
{
  "type": SerializedType,
  "optional": boolean,
  "readonly": boolean
}
```

**Call/Construct Signature:**
```json
{
  "typeParameters": [...],
  "parameters": [
    { "name": "x", "type": { "kind": "number" }, "optional": false, "rest": false }
  ],
  "returnType": { "kind": "string" }
}
```

**Index Signature:**
```json
{
  "parameterName": "key",
  "parameterType": { "kind": "string" },
  "returnType": { "kind": "any" },
  "readonly": false
}
```

### Function Types

```json
{
  "kind": "function",
  "typeParameters": [
    { "name": "T", "constraint": { "kind": "object", ... }, "default": null }
  ],
  "parameters": [
    { "name": "items", "type": { "kind": "array", "elementType": { "kind": "reference", "name": "T" } }, "optional": false, "rest": false }
  ],
  "returnType": { "kind": "reference", "name": "T" }
}
```

### Array Types

```json
{
  "kind": "array",
  "elementType": { "kind": "string" }
}
```

### Tuple Types

```json
{
  "kind": "tuple",
  "elements": [
    { "type": { "kind": "string" }, "optional": false, "rest": false, "label": "name" },
    { "type": { "kind": "number" }, "optional": false, "rest": false, "label": "age" },
    { "type": { "kind": "string" }, "optional": true, "rest": false, "label": null }
  ]
}
```

### Union Types

```json
{
  "kind": "union",
  "types": [
    { "kind": "string" },
    { "kind": "number" },
    { "kind": "null" }
  ]
}
```

### Intersection Types

```json
{
  "kind": "intersection",
  "types": [
    { "kind": "reference", "name": "A" },
    { "kind": "reference", "name": "B" }
  ]
}
```

### Type References

For referencing other types (generics, type aliases, interfaces):

```json
{
  "kind": "reference",
  "name": "Promise",
  "typeArguments": [
    { "kind": "string" }
  ]
}
```

### Conditional Types

```typescript
T extends U ? X : Y
```

```json
{
  "kind": "conditional",
  "checkType": { "kind": "reference", "name": "T" },
  "extendsType": { "kind": "reference", "name": "U" },
  "trueType": { "kind": "reference", "name": "X" },
  "falseType": { "kind": "reference", "name": "Y" }
}
```

### Mapped Types

```typescript
{ [K in keyof T]: T[K] }
{ readonly [K in keyof T]+?: T[K] }
```

```json
{
  "kind": "mapped",
  "typeParameter": { "name": "K", "constraint": { "kind": "keyof", "type": { "kind": "reference", "name": "T" } } },
  "nameType": null,
  "templateType": { "kind": "indexAccess", "objectType": { "kind": "reference", "name": "T" }, "indexType": { "kind": "reference", "name": "K" } },
  "readonlyModifier": "add",
  "optionalModifier": "add"
}
```

Modifier values: `"unchanged"`, `"add"`, `"remove"`

### Template Literal Types

```typescript
`${string}-${number}`
```

```json
{
  "kind": "template",
  "texts": ["", "-", ""],
  "types": [
    { "kind": "string" },
    { "kind": "number" }
  ]
}
```

### Index Access Types

```typescript
T[K]
```

```json
{
  "kind": "indexAccess",
  "objectType": { "kind": "reference", "name": "T" },
  "indexType": { "kind": "reference", "name": "K" }
}
```

### Infer Types

```typescript
T extends (...args: infer P) => any ? P : never
```

```json
{
  "kind": "infer",
  "typeParameterName": "P"
}
```

---

## Export Declarations Schema

When a worker finishes type-checking, it returns exported types/values:

### ExportedTypes Response

```json
{
  "exports": {
    "User": {
      "symbolKind": "interface",
      "type": {
        "kind": "object",
        "properties": {
          "id": { "type": { "kind": "number" }, "optional": false, "readonly": true },
          "name": { "type": { "kind": "string" }, "optional": false, "readonly": false }
        }
      },
      "typeParameters": []
    },
    "createUser": {
      "symbolKind": "function",
      "type": {
        "kind": "function",
        "parameters": [
          { "name": "name", "type": { "kind": "string" }, "optional": false, "rest": false }
        ],
        "returnType": { "kind": "reference", "name": "User" }
      }
    },
    "DEFAULT_USER": {
      "symbolKind": "variable",
      "type": { "kind": "reference", "name": "User" },
      "isConst": true
    }
  },
  "reExports": {
    "./utils": ["*"],
    "./types": ["UserType", "Config"]
  }
}
```

### Symbol Kinds

```typescript
type SymbolKind =
  | "variable" | "function" | "class" | "interface"
  | "enum" | "enumMember" | "type" | "module";
```

---

## IPC Request/Response Protocol

### Check Request (Go → MoonBit)

```json
{
  "id": "check-001",
  "command": "check",
  "file": "/src/components/Button.tsx",
  "source": "import { Theme } from './theme';\n\nexport interface ButtonProps {...}",
  "options": {
    "strict": true,
    "noImplicitAny": true,
    "target": "ES2020"
  },
  "importedTypes": {
    "./theme": {
      "exports": {
        "Theme": {
          "symbolKind": "interface",
          "type": {
            "kind": "object",
            "properties": {
              "primaryColor": { "type": { "kind": "string" }, "optional": false, "readonly": false },
              "fontSize": { "type": { "kind": "number" }, "optional": false, "readonly": false }
            }
          }
        },
        "defaultTheme": {
          "symbolKind": "variable",
          "type": { "kind": "reference", "name": "Theme" },
          "isConst": true
        }
      }
    },
    "react": {
      "exports": {
        "FC": {
          "symbolKind": "type",
          "type": {
            "kind": "object",
            "properties": {},
            "callSignatures": [{
              "typeParameters": [{ "name": "P", "constraint": null, "default": { "kind": "object", "properties": {} } }],
              "parameters": [{ "name": "props", "type": { "kind": "reference", "name": "P" }, "optional": false, "rest": false }],
              "returnType": { "kind": "union", "types": [{ "kind": "reference", "name": "ReactElement" }, { "kind": "null" }] }
            }]
          }
        }
      }
    }
  }
}
```

### Check Response (MoonBit → Go)

```json
{
  "id": "check-001",
  "success": true,
  "diagnostics": [
    {
      "file": "/src/components/Button.tsx",
      "line": 15,
      "column": 8,
      "endLine": 15,
      "endColumn": 20,
      "code": 2322,
      "category": "error",
      "message": "Type 'string' is not assignable to type 'number'."
    }
  ],
  "exportedTypes": {
    "exports": {
      "ButtonProps": {
        "symbolKind": "interface",
        "type": {
          "kind": "object",
          "properties": {
            "label": { "type": { "kind": "string" }, "optional": false, "readonly": false },
            "onClick": {
              "type": {
                "kind": "function",
                "parameters": [],
                "returnType": { "kind": "void" }
              },
              "optional": true,
              "readonly": false
            },
            "theme": { "type": { "kind": "reference", "name": "Theme" }, "optional": true, "readonly": false }
          }
        }
      },
      "Button": {
        "symbolKind": "variable",
        "type": {
          "kind": "reference",
          "name": "FC",
          "typeArguments": [{ "kind": "reference", "name": "ButtonProps" }]
        },
        "isConst": true
      }
    }
  }
}
```

---

## MoonBit TypeChecker Modifications

### New Types for Import Resolution

```moonbit
// compiler/imported_types.mbt

///|
/// Serialized type from JSON (for imported types)
pub enum SerializedType {
  Primitive(String)  // "number", "string", etc.
  Literal(LiteralValue)
  Object(SerializedObjectType)
  Function(SerializedFunctionType)
  Array(SerializedType)
  Tuple(Array[SerializedTupleElement])
  Union(Array[SerializedType])
  Intersection(Array[SerializedType])
  Reference(String, Array[SerializedType])  // name, type args
  Conditional(SerializedConditionalType)
  Mapped(SerializedMappedType)
  Template(Array[String], Array[SerializedType])
  IndexAccess(SerializedType, SerializedType)
  Infer(String)
  Error
} derive(Show)

///|
/// Literal value
pub enum LiteralValue {
  NumberLit(Double)
  StringLit(String)
  BooleanLit(Bool)
} derive(Show)

///|
/// Serialized object type
pub struct SerializedObjectType {
  properties : Map[String, SerializedPropertySignature]
  call_signatures : Array[SerializedSignature]
  construct_signatures : Array[SerializedSignature]
  index_signatures : Array[SerializedIndexSignature]
} derive(Show)

///|
/// Serialized property signature
pub struct SerializedPropertySignature {
  prop_type : SerializedType
  is_optional : Bool
  is_readonly : Bool
} derive(Show)

///|
/// Serialized function signature
pub struct SerializedSignature {
  type_parameters : Array[SerializedTypeParameter]
  parameters : Array[SerializedParameter]
  return_type : SerializedType
} derive(Show)

///|
/// Serialized parameter
pub struct SerializedParameter {
  name : String
  param_type : SerializedType
  is_optional : Bool
  is_rest : Bool
} derive(Show)

///|
/// Serialized type parameter
pub struct SerializedTypeParameter {
  name : String
  constraint : SerializedType?
  default_type : SerializedType?
} derive(Show)

///|
/// Exported symbol from a module
pub struct ExportedSymbol {
  symbol_kind : String  // "variable", "function", "class", "interface", "enum", "type"
  exported_type : SerializedType
  type_parameters : Array[SerializedTypeParameter]
  is_const : Bool
} derive(Show)

///|
/// Module exports (what a file exports)
pub struct ModuleExports {
  exports : Map[String, ExportedSymbol]
  re_exports : Map[String, Array[String]]  // module path -> exported names (or ["*"])
} derive(Show)

///|
/// Imported types for a file (from coordinator)
pub struct ImportedTypes {
  modules : Map[String, ModuleExports]  // module specifier -> exports
} derive(Show)
```

### Modified TypeChecker

```moonbit
// compiler/checker.mbt (modifications)

///|
/// Type checker state - MODIFIED
pub struct TypeChecker {
  next_type_id : Int
  type_cache : Map[String, Type]
  symbol_types : Map[Int, Type]
  node_types : Map[String, Type]
  narrowed_types : Map[String, NarrowedType]
  diagnostics : Array[Diagnostic]
  file_path : String
  global_scope : Scope?
  local_scopes : Array[LocalScope]
  current_this_type : Type?
  no_unchecked_indexed_access : Bool
  resolving_symbols : Map[Int, Bool]

  // NEW: Pre-resolved imported types from coordinator
  imported_types : ImportedTypes?
  // NEW: Cache of deserialized imported types
  imported_type_cache : Map[String, Type]
} derive(Show)

///|
/// Create type checker with imported types - NEW
pub fn TypeChecker::new_with_imports(
  file_path : String,
  global_scope : Scope?,
  imported_types : ImportedTypes
) -> TypeChecker {
  {
    next_type_id: 0,
    type_cache: Map::new(),
    symbol_types: Map::new(),
    node_types: Map::new(),
    narrowed_types: Map::new(),
    diagnostics: [],
    file_path,
    global_scope,
    local_scopes: [],
    current_this_type: None,
    no_unchecked_indexed_access: false,
    resolving_symbols: Map::new(),
    imported_types: Some(imported_types),
    imported_type_cache: Map::new(),
  }
}

///|
/// Resolve an import specifier to exported types - NEW
pub fn resolve_import(
  checker : TypeChecker,
  module_specifier : String,
  imported_name : String
) -> (Type?, TypeChecker) {
  // Check cache first
  let cache_key = "\{module_specifier}::\{imported_name}"
  match checker.imported_type_cache.get(cache_key) {
    Some(t) => (Some(t), checker)
    None => {
      // Look up in imported_types
      match checker.imported_types {
        Some(imports) => {
          match imports.modules.get(module_specifier) {
            Some(module_exports) => {
              match module_exports.exports.get(imported_name) {
                Some(exported_symbol) => {
                  // Deserialize the type
                  let (resolved_type, checker) = deserialize_type(checker, exported_symbol.exported_type)
                  // Cache it
                  let cache = checker.imported_type_cache
                  cache.set(cache_key, resolved_type)
                  (Some(resolved_type), { ..checker, imported_type_cache: cache })
                }
                None => (None, checker)
              }
            }
            None => (None, checker)
          }
        }
        None => (None, checker)
      }
    }
  }
}

///|
/// Deserialize a SerializedType to a Type - NEW
fn deserialize_type(
  checker : TypeChecker,
  serialized : SerializedType
) -> (Type, TypeChecker) {
  match serialized {
    Primitive(kind) => {
      match kind {
        "number" => number_type(checker)
        "string" => string_type(checker)
        "boolean" => boolean_type(checker)
        "void" => void_type(checker)
        "undefined" => undefined_type(checker)
        "null" => null_type(checker)
        "any" => any_type(checker)
        "unknown" => unknown_type(checker)
        "never" => never_type(checker)
        "symbol" => symbol_type(checker)
        _ => error_type(checker)
      }
    }
    Literal(lit) => {
      match lit {
        NumberLit(n) => number_literal_type(checker, n)
        StringLit(s) => string_literal_type(checker, s)
        BooleanLit(b) => boolean_literal_type(checker, b)
      }
    }
    Object(obj) => deserialize_object_type(checker, obj)
    Function(func) => deserialize_function_type(checker, func)
    Array(elem) => {
      let (elem_type, checker) = deserialize_type(checker, elem)
      create_array_type(checker, elem_type)
    }
    Union(types) => {
      let (deserialized_types, checker) = deserialize_types(checker, types)
      create_union_type(checker, deserialized_types)
    }
    Intersection(types) => {
      let (deserialized_types, checker) = deserialize_types(checker, types)
      create_intersection_type(checker, deserialized_types)
    }
    Reference(name, type_args) => {
      let (args, checker) = deserialize_types(checker, type_args)
      create_type_reference(checker, name, args)
    }
    // ... handle other cases
    _ => error_type(checker)
  }
}

///|
/// Deserialize multiple types
fn deserialize_types(
  checker : TypeChecker,
  types : Array[SerializedType]
) -> (Array[Type], TypeChecker) {
  let result = []
  let mut current_checker = checker
  for i = 0; i < types.length(); i = i + 1 {
    let (t, c) = deserialize_type(current_checker, types[i])
    result.push(t)
    current_checker = c
  }
  (result, current_checker)
}
```

### Worker Entry Point

```moonbit
// worker/main.mbt

///|
/// Worker request from coordinator
pub struct WorkerRequest {
  id : String
  command : String
  file : String
  source : String
  options : CompilerOptions
  imported_types : ImportedTypes?
} derive(Show)

///|
/// Worker response to coordinator
pub struct WorkerResponse {
  id : String
  success : Bool
  diagnostics : Array[SerializedDiagnostic]
  exported_types : ModuleExports?
  js : String?
  source_map : String?
  declaration : String?
} derive(Show)

///|
/// Main worker loop
fn main {
  // Read JSON requests from stdin, write responses to stdout
  loop {
    let line = read_line()
    if line.is_empty() {
      break
    }

    let request = parse_request(line)
    let response = handle_request(request)
    let json = serialize_response(response)
    println(json)
  }
}

///|
/// Handle a worker request
fn handle_request(request : WorkerRequest) -> WorkerResponse {
  match request.command {
    "check" => handle_check(request)
    "parse" => handle_parse(request)
    "emit" => handle_emit(request)
    "ping" => WorkerResponse {
      id: request.id,
      success: true,
      diagnostics: [],
      exported_types: None,
      js: None,
      source_map: None,
      declaration: None,
    }
    "shutdown" => {
      // Clean exit
      exit(0)
    }
    _ => WorkerResponse {
      id: request.id,
      success: false,
      diagnostics: [{ message: "Unknown command: \{request.command}", ... }],
      exported_types: None,
      js: None,
      source_map: None,
      declaration: None,
    }
  }
}

///|
/// Handle check command
fn handle_check(request : WorkerRequest) -> WorkerResponse {
  // 1. Parse
  let source_file = parse_source_file(request.file, request.source)

  // 2. Bind
  let bound_file = match bind_source_file(source_file) {
    Ok(bf) => bf
    Err(diagnostics) => return WorkerResponse {
      id: request.id,
      success: false,
      diagnostics: serialize_diagnostics(diagnostics),
      exported_types: None,
      js: None,
      source_map: None,
      declaration: None,
    }
  }

  // 3. Type check with imported types
  let checker = match request.imported_types {
    Some(imports) => TypeChecker::new_with_imports(
      request.file,
      Some(bound_file.global_scope),
      imports
    )
    None => TypeChecker::new(request.file, Some(bound_file.global_scope))
  }

  let (typed_file, checker) = check_source_file(checker, bound_file)

  // 4. Extract exported types
  let exported_types = extract_exports(checker, bound_file)

  // 5. Return response
  WorkerResponse {
    id: request.id,
    success: checker.diagnostics.is_empty() || !has_errors(checker.diagnostics),
    diagnostics: serialize_diagnostics(checker.diagnostics),
    exported_types: Some(exported_types),
    js: None,  // Emit is separate command
    source_map: None,
    declaration: None,
  }
}

///|
/// Extract exported types from a type-checked file
fn extract_exports(checker : TypeChecker, bound_file : BoundSourceFile) -> ModuleExports {
  let exports = Map::new()

  // Iterate over exported symbols in global scope
  for name, symbol in bound_file.global_scope.symbols {
    if symbol.flags.is_export {
      // Get the type for this symbol
      let symbol_type = match checker.symbol_types.get(symbol.id) {
        Some(t) => t
        None => Type::Any(create_type_info_default())
      }

      exports.set(name, ExportedSymbol {
        symbol_kind: symbol_kind_to_string(symbol.kind),
        exported_type: serialize_type(symbol_type),
        type_parameters: [],  // Extract from declarations if needed
        is_const: symbol.flags.is_const,
      })
    }
  }

  ModuleExports {
    exports: exports,
    re_exports: Map::new(),  // TODO: Handle re-exports
  }
}
```

---

## Go Coordinator Integration

### Type Cache

```go
// internal/typecache/cache.go
package typecache

import (
    "sync"
)

// ModuleExports represents exported types from a module
type ModuleExports struct {
    Exports   map[string]*ExportedSymbol `json:"exports"`
    ReExports map[string][]string        `json:"reExports"`
}

// ExportedSymbol represents a single exported symbol
type ExportedSymbol struct {
    SymbolKind     string          `json:"symbolKind"`
    Type           json.RawMessage `json:"type"`
    TypeParameters []TypeParameter `json:"typeParameters,omitempty"`
    IsConst        bool            `json:"isConst,omitempty"`
}

// TypeCache stores resolved types for all modules
type TypeCache struct {
    modules map[string]*ModuleExports
    mu      sync.RWMutex
}

// NewTypeCache creates a new type cache
func NewTypeCache() *TypeCache {
    return &TypeCache{
        modules: make(map[string]*ModuleExports),
    }
}

// Get retrieves exports for a module
func (c *TypeCache) Get(modulePath string) (*ModuleExports, bool) {
    c.mu.RLock()
    defer c.mu.RUnlock()
    exports, ok := c.modules[modulePath]
    return exports, ok
}

// Set stores exports for a module
func (c *TypeCache) Set(modulePath string, exports *ModuleExports) {
    c.mu.Lock()
    defer c.mu.Unlock()
    c.modules[modulePath] = exports
}

// ResolveImports builds the importedTypes payload for a file
func (c *TypeCache) ResolveImports(imports []ImportSpecifier) map[string]*ModuleExports {
    c.mu.RLock()
    defer c.mu.RUnlock()

    result := make(map[string]*ModuleExports)
    for _, imp := range imports {
        if exports, ok := c.modules[imp.ResolvedPath]; ok {
            result[imp.Specifier] = exports
        }
    }
    return result
}
```

### Coordinator Flow

```go
// internal/coordinator/check.go
package coordinator

import (
    "context"
    "sync"

    "moonbit-tsc/internal/typecache"
    "moonbit-tsc/internal/worker"
)

type Coordinator struct {
    typeCache  *typecache.TypeCache
    workerPool *worker.Pool
    depGraph   *DependencyGraph
}

// CheckProject type-checks all files in dependency order
func (c *Coordinator) CheckProject(ctx context.Context, files []string) ([]Diagnostic, error) {
    // 1. Parse all files to extract imports (can be parallel)
    imports := c.parseImports(ctx, files)

    // 2. Build dependency graph
    c.depGraph = BuildDependencyGraph(files, imports)

    // 3. Get topological order
    levels := c.depGraph.TopologicalLevels()

    var allDiagnostics []Diagnostic

    // 4. Process each level (files in same level can be parallel)
    for _, level := range levels {
        diagnostics := c.checkLevel(ctx, level)
        allDiagnostics = append(allDiagnostics, diagnostics...)
    }

    return allDiagnostics, nil
}

// checkLevel checks all files in a dependency level (parallel safe)
func (c *Coordinator) checkLevel(ctx context.Context, files []string) []Diagnostic {
    var wg sync.WaitGroup
    var mu sync.Mutex
    var diagnostics []Diagnostic

    for _, file := range files {
        wg.Add(1)
        go func(f string) {
            defer wg.Done()

            // Get resolved imports for this file
            importedTypes := c.typeCache.ResolveImports(c.depGraph.Imports(f))

            // Send to worker
            result, err := c.workerPool.Check(ctx, &worker.CheckRequest{
                File:          f,
                Source:        readFile(f),
                ImportedTypes: importedTypes,
            })

            if err != nil {
                mu.Lock()
                diagnostics = append(diagnostics, Diagnostic{
                    File:    f,
                    Message: err.Error(),
                })
                mu.Unlock()
                return
            }

            // Store exported types in cache
            if result.ExportedTypes != nil {
                c.typeCache.Set(f, result.ExportedTypes)
            }

            // Collect diagnostics
            mu.Lock()
            diagnostics = append(diagnostics, result.Diagnostics...)
            mu.Unlock()
        }(file)
    }

    wg.Wait()
    return diagnostics
}
```

---

## Example: Full Type Check Flow

### Input Files

**theme.ts:**
```typescript
export interface Theme {
  primaryColor: string;
  fontSize: number;
}

export const defaultTheme: Theme = {
  primaryColor: "#007bff",
  fontSize: 16,
};
```

**button.ts:**
```typescript
import { Theme } from "./theme";

export interface ButtonProps {
  label: string;
  theme?: Theme;
}

export function Button(props: ButtonProps): void {
  console.log(props.label);
}
```

### Flow

1. **Parse imports** (parallel):
   - `theme.ts`: no imports
   - `button.ts`: imports `Theme` from `./theme`

2. **Build dependency graph**:
   ```
   theme.ts ──► button.ts
   ```

3. **Level 0**: Check `theme.ts` (no dependencies)

   Request:
   ```json
   {
     "id": "1",
     "command": "check",
     "file": "theme.ts",
     "source": "export interface Theme {...}",
     "importedTypes": {}
   }
   ```

   Response:
   ```json
   {
     "id": "1",
     "success": true,
     "diagnostics": [],
     "exportedTypes": {
       "exports": {
         "Theme": {
           "symbolKind": "interface",
           "type": {
             "kind": "object",
             "properties": {
               "primaryColor": { "type": { "kind": "string" } },
               "fontSize": { "type": { "kind": "number" } }
             }
           }
         },
         "defaultTheme": {
           "symbolKind": "variable",
           "type": { "kind": "reference", "name": "Theme" },
           "isConst": true
         }
       }
     }
   }
   ```

4. **Store in type cache**: `theme.ts` → exports

5. **Level 1**: Check `button.ts` (depends on `theme.ts`)

   Request:
   ```json
   {
     "id": "2",
     "command": "check",
     "file": "button.ts",
     "source": "import { Theme } from './theme'; ...",
     "importedTypes": {
       "./theme": {
         "exports": {
           "Theme": {
             "symbolKind": "interface",
             "type": {
               "kind": "object",
               "properties": {
                 "primaryColor": { "type": { "kind": "string" } },
                 "fontSize": { "type": { "kind": "number" } }
               }
             }
           }
         }
       }
     }
   }
   ```

6. **Worker resolves `Theme`** from `importedTypes` when checking `button.ts`

7. **Response** with `button.ts` exports

---

## Summary

| Component | Responsibility |
|-----------|----------------|
| **Go Coordinator** | Orchestrate, build dep graph, manage type cache, parallelize |
| **Type Cache (Go)** | Store/retrieve module exports, resolve imports |
| **MoonBit Worker** | Parse, bind, type check with imported types, serialize exports |
| **IPC Protocol** | JSON-based type serialization, request/response |

This design allows:
- **Parallel checking** of independent files
- **Incremental checking** - only recheck affected files
- **Cross-file type resolution** via coordinator-managed type cache
- **Clean separation** - Go handles orchestration, MoonBit handles core checking
