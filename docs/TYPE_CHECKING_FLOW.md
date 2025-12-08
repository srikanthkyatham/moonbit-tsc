# Type Checking Flow: Go Coordinator ↔ MoonBit Workers

## Overview Diagram

```
┌─────────────────────────────────────────────────────────────────────────────┐
│                              USER REQUEST                                    │
│                         $ tsc --project ./src                               │
└─────────────────────────────────────────────────────────────────────────────┘
                                     │
                                     ▼
┌─────────────────────────────────────────────────────────────────────────────┐
│                           GO COORDINATOR                                     │
│                                                                              │
│  ┌─────────────┐   ┌─────────────┐   ┌─────────────┐   ┌─────────────────┐ │
│  │ CLI Parser  │──►│ File        │──►│ Dependency  │──►│ Type Cache      │ │
│  │ (cobra)     │   │ Discovery   │   │ Graph       │   │ (ristretto)     │ │
│  └─────────────┘   └─────────────┘   └─────────────┘   └─────────────────┘ │
│                                             │                   ▲           │
│                                             ▼                   │           │
│                                    ┌─────────────────┐          │           │
│                                    │ Topological     │          │           │
│                                    │ Sort            │          │           │
│                                    └────────┬────────┘          │           │
│                                             │                   │           │
│                                             ▼                   │           │
│                              ┌──────────────────────────────────┤           │
│                              │         WORKER POOL              │           │
│                              │                                  │           │
│    ┌─────────────────────────┼─────────────────────────┐        │           │
│    │                         │                         │        │           │
│    ▼                         ▼                         ▼        │           │
│ ┌──────┐                 ┌──────┐                 ┌──────┐      │           │
│ │ W1   │                 │ W2   │                 │ W3   │      │           │
│ │stdin │                 │stdin │                 │stdin │      │           │
│ └──┬───┘                 └──┬───┘                 └──┬───┘      │           │
└────┼────────────────────────┼────────────────────────┼──────────┼───────────┘
     │ JSON                   │ JSON                   │ JSON     │
     ▼                        ▼                        ▼          │
┌──────────┐            ┌──────────┐            ┌──────────┐      │
│ MoonBit  │            │ MoonBit  │            │ MoonBit  │      │
│ Worker 1 │            │ Worker 2 │            │ Worker 3 │      │
│          │            │          │            │          │      │
│ Scanner  │            │ Scanner  │            │ Scanner  │      │
│ Parser   │            │ Parser   │            │ Parser   │      │
│ Binder   │            │ Binder   │            │ Binder   │      │
│ Checker  │            │ Checker  │            │ Checker  │      │
│          │            │          │            │          │      │
│ stdout   │            │ stdout   │            │ stdout   │      │
└────┬─────┘            └────┬─────┘            └────┬─────┘      │
     │ JSON                  │ JSON                  │ JSON       │
     └───────────────────────┴───────────────────────┴────────────┘
                                     │
                                     ▼
                         ┌───────────────────────┐
                         │   Aggregated Results  │
                         │   - Diagnostics       │
                         │   - .js files         │
                         │   - .d.ts files       │
                         └───────────────────────┘
```

---

## Phase 1: File Discovery & Dependency Analysis

```
┌─────────────────────────────────────────────────────────────────────────────┐
│                        PHASE 1: DISCOVERY                                    │
└─────────────────────────────────────────────────────────────────────────────┘

  tsconfig.json                      Go Coordinator
       │                                   │
       ▼                                   ▼
  ┌─────────────┐                   ┌─────────────────────────────────────┐
  │ {           │                   │  1. Parse tsconfig.json             │
  │   "include":│                   │  2. Glob for .ts/.tsx files         │
  │   ["src/*"] │         ────►     │  3. Resolve project references      │
  │ }           │                   │  4. Build file list                 │
  └─────────────┘                   └─────────────────────────────────────┘
                                                      │
                                                      ▼
                                    ┌─────────────────────────────────────┐
                                    │  Files Found:                       │
                                    │  ├── src/types.ts                   │
                                    │  ├── src/utils.ts                   │
                                    │  ├── src/api.ts                     │
                                    │  ├── src/components/Button.tsx      │
                                    │  └── src/app.ts                     │
                                    └─────────────────────────────────────┘
```

---

## Phase 2: Import Extraction (Parallel)

```
┌─────────────────────────────────────────────────────────────────────────────┐
│                    PHASE 2: IMPORT EXTRACTION                                │
│                    (Parallel - all files at once)                            │
└─────────────────────────────────────────────────────────────────────────────┘

   Go Coordinator sends "parse" command to workers in parallel:

   ┌─────────────────────────────────────────────────────────────────────────┐
   │                         WORKER POOL                                      │
   │                                                                          │
   │   ┌──────────────┐     ┌──────────────┐     ┌──────────────┐            │
   │   │   Worker 1   │     │   Worker 2   │     │   Worker 3   │            │
   │   │              │     │              │     │              │            │
   │   │  types.ts    │     │  utils.ts    │     │  api.ts      │            │
   │   │  Button.tsx  │     │  app.ts      │     │              │            │
   │   │              │     │              │     │              │            │
   │   └──────┬───────┘     └──────┬───────┘     └──────┬───────┘            │
   │          │                    │                    │                     │
   └──────────┼────────────────────┼────────────────────┼─────────────────────┘
              │                    │                    │
              ▼                    ▼                    ▼

   Request (Go → MoonBit):         Response (MoonBit → Go):

   {                               {
     "command": "parse",             "imports": [
     "file": "api.ts",                 { "specifier": "./types",
     "source": "import..."               "names": ["User", "Config"] },
   }                                   { "specifier": "./utils",
                                         "names": ["formatDate"] }
                                     ]
                                   }
```

---

## Phase 3: Dependency Graph Construction

```
┌─────────────────────────────────────────────────────────────────────────────┐
│                    PHASE 3: DEPENDENCY GRAPH                                 │
└─────────────────────────────────────────────────────────────────────────────┘

  Collected Imports:                      Dependency Graph (DAG):

  types.ts    → (no imports)
  utils.ts    → types.ts                         ┌──────────┐
  api.ts      → types.ts, utils.ts               │ types.ts │ (Level 0)
  Button.tsx  → types.ts                         └────┬─────┘
  app.ts      → api.ts, Button.tsx                    │
                                           ┌──────────┼──────────┐
                                           ▼          ▼          ▼
                                      ┌─────────┐ ┌─────────┐ ┌──────────┐
                                      │utils.ts │ │ api.ts  │ │Button.tsx│ (Level 1)
                                      └────┬────┘ └────┬────┘ └────┬─────┘
                                           │          │           │
                                           └──────────┼───────────┘
                                                      ▼
                                                 ┌─────────┐
                                                 │ app.ts  │ (Level 2)
                                                 └─────────┘

  Topological Levels:
  ┌───────────────────────────────────────────────────────────────────────────┐
  │ Level 0: [types.ts]              ──► No dependencies, check first        │
  │ Level 1: [utils.ts, api.ts, Button.tsx] ──► Depend on Level 0            │
  │ Level 2: [app.ts]                ──► Depends on Level 1                  │
  └───────────────────────────────────────────────────────────────────────────┘
```

---

## Phase 4: Type Checking by Level

### Level 0: No Dependencies

```
┌─────────────────────────────────────────────────────────────────────────────┐
│                    PHASE 4a: CHECK LEVEL 0                                   │
│                    (types.ts - no dependencies)                              │
└─────────────────────────────────────────────────────────────────────────────┘

   Go Coordinator                              MoonBit Worker
        │                                            │
        │  ┌─────────────────────────────────┐       │
        │  │ CHECK REQUEST                   │       │
        │  │ {                               │       │
        │  │   "command": "check",           │       │
        │  │   "file": "types.ts",           │       │
        │  │   "source": "                   │       │
        │  │     export interface User {     │       │
        │  │       id: number;               │       │
        │  │       name: string;             │       │
        │  │     }                           │       │
        │  │     export type Config = {...}  │       │
        │  │   ",                            │       │
        │  │   "importedTypes": {}  ◄─── Empty, no deps
        │  │ }                               │       │
        │  └─────────────────────────────────┘       │
        │                    │                       │
        │                    │  stdin (JSON)         │
        │                    ▼                       │
        │              ┌───────────────────────────────────────┐
        │              │         MOONBIT WORKER                │
        │              │                                       │
        │              │  ┌─────────┐                          │
        │              │  │ Scanner │ "export interface..."    │
        │              │  └────┬────┘                          │
        │              │       ▼                               │
        │              │  ┌─────────┐                          │
        │              │  │ Parser  │ AST: InterfaceDecl       │
        │              │  └────┬────┘                          │
        │              │       ▼                               │
        │              │  ┌─────────┐                          │
        │              │  │ Binder  │ Symbols: User, Config    │
        │              │  └────┬────┘                          │
        │              │       ▼                               │
        │              │  ┌─────────┐                          │
        │              │  │ Checker │ Types resolved           │
        │              │  └────┬────┘                          │
        │              │       ▼                               │
        │              │  ┌─────────────┐                      │
        │              │  │ Extract     │ Serialize exports    │
        │              │  │ Exports     │                      │
        │              │  └─────────────┘                      │
        │              └───────────────────────────────────────┘
        │                    │
        │                    │  stdout (JSON)
        │                    ▼
        │  ┌─────────────────────────────────────────────────────┐
        │  │ CHECK RESPONSE                                      │
        │  │ {                                                   │
        │  │   "success": true,                                  │
        │  │   "diagnostics": [],                                │
        │  │   "exportedTypes": {                                │
        │  │     "exports": {                                    │
        │  │       "User": {                                     │
        │  │         "symbolKind": "interface",                  │
        │  │         "type": {                                   │
        │  │           "kind": "object",                         │
        │  │           "properties": {                           │
        │  │             "id": { "type": {"kind":"number"} },    │
        │  │             "name": { "type": {"kind":"string"} }   │
        │  │           }                                         │
        │  │         }                                           │
        │  │       },                                            │
        │  │       "Config": { ... }                             │
        │  │     }                                               │
        │  │   }                                                 │
        │  │ }                                                   │
        │  └─────────────────────────────────────────────────────┘
        │                    │
        ▼                    ▼
   ┌─────────────────────────────────────────────────────────────┐
   │                    TYPE CACHE (Go)                          │
   │  ┌────────────────────────────────────────────────────────┐ │
   │  │ "types.ts" → {                                         │ │
   │  │   "User": { kind: "object", properties: {...} },       │ │
   │  │   "Config": { ... }                                    │ │
   │  │ }                                                      │ │
   │  └────────────────────────────────────────────────────────┘ │
   └─────────────────────────────────────────────────────────────┘
```

### Level 1: With Dependencies (Parallel)

```
┌─────────────────────────────────────────────────────────────────────────────┐
│                    PHASE 4b: CHECK LEVEL 1                                   │
│                    (utils.ts, api.ts, Button.tsx - parallel)                 │
└─────────────────────────────────────────────────────────────────────────────┘

   TYPE CACHE contains: types.ts exports

   ┌─────────────────────────────────────────────────────────────────────────┐
   │  Go Coordinator builds importedTypes from cache for each file:         │
   │                                                                         │
   │  utils.ts needs: ["./types" → User]                                     │
   │  api.ts needs:   ["./types" → User, Config]                             │
   │  Button.tsx needs: ["./types" → User]                                   │
   └─────────────────────────────────────────────────────────────────────────┘
                                     │
                                     ▼
   ┌─────────────────────────────────────────────────────────────────────────┐
   │                    PARALLEL WORKER DISPATCH                             │
   │                                                                         │
   │    ┌─────────────────┐  ┌─────────────────┐  ┌─────────────────┐       │
   │    │    Worker 1     │  │    Worker 2     │  │    Worker 3     │       │
   │    │                 │  │                 │  │                 │       │
   │    │   utils.ts      │  │    api.ts       │  │   Button.tsx    │       │
   │    │                 │  │                 │  │                 │       │
   │    │ importedTypes:  │  │ importedTypes:  │  │ importedTypes:  │       │
   │    │ {               │  │ {               │  │ {               │       │
   │    │   "./types": {  │  │   "./types": {  │  │   "./types": {  │       │
   │    │     "User": ... │  │     "User": ... │  │     "User": ... │       │
   │    │   }             │  │     "Config":...│  │   }             │       │
   │    │ }               │  │   }             │  │ }               │       │
   │    │                 │  │ }               │  │                 │       │
   │    └────────┬────────┘  └────────┬────────┘  └────────┬────────┘       │
   │             │                    │                    │                 │
   └─────────────┼────────────────────┼────────────────────┼─────────────────┘
                 │                    │                    │
                 ▼                    ▼                    ▼

   ┌─────────────────┐  ┌─────────────────┐  ┌─────────────────┐
   │ MoonBit Worker  │  │ MoonBit Worker  │  │ MoonBit Worker  │
   │                 │  │                 │  │                 │
   │ import {User}   │  │ import {User,   │  │ import {User}   │
   │ from "./types"  │  │   Config}       │  │ from "./types"  │
   │                 │  │ from "./types"  │  │                 │
   │ ─────────────── │  │ ─────────────── │  │ ─────────────── │
   │                 │  │                 │  │                 │
   │ Checker looks   │  │ Checker looks   │  │ Checker looks   │
   │ up "User" in    │  │ up "User" and   │  │ up "User" in    │
   │ importedTypes   │  │ "Config" in     │  │ importedTypes   │
   │       ▼         │  │ importedTypes   │  │       ▼         │
   │ Found! Use it   │  │       ▼         │  │ Found! Use it   │
   │ for type check  │  │ Found! Use them │  │ for type check  │
   │                 │  │ for type check  │  │                 │
   └────────┬────────┘  └────────┬────────┘  └────────┬────────┘
            │                    │                    │
            ▼                    ▼                    ▼
   ┌─────────────────┐  ┌─────────────────┐  ┌─────────────────┐
   │ Response:       │  │ Response:       │  │ Response:       │
   │ exports:        │  │ exports:        │  │ exports:        │
   │   formatDate    │  │   fetchUser     │  │   Button        │
   │   parseDate     │  │   updateConfig  │  │   ButtonProps   │
   └─────────────────┘  └─────────────────┘  └─────────────────┘
            │                    │                    │
            └────────────────────┼────────────────────┘
                                 ▼
   ┌─────────────────────────────────────────────────────────────┐
   │                    TYPE CACHE (Go) - Updated                │
   │  ┌────────────────────────────────────────────────────────┐ │
   │  │ "types.ts"    → { User, Config }                       │ │
   │  │ "utils.ts"    → { formatDate, parseDate }    ◄── NEW   │ │
   │  │ "api.ts"      → { fetchUser, updateConfig }  ◄── NEW   │ │
   │  │ "Button.tsx"  → { Button, ButtonProps }      ◄── NEW   │ │
   │  └────────────────────────────────────────────────────────┘ │
   └─────────────────────────────────────────────────────────────┘
```

### Level 2: Depends on Level 1

```
┌─────────────────────────────────────────────────────────────────────────────┐
│                    PHASE 4c: CHECK LEVEL 2                                   │
│                    (app.ts - depends on api.ts, Button.tsx)                  │
└─────────────────────────────────────────────────────────────────────────────┘

   TYPE CACHE now contains: types.ts, utils.ts, api.ts, Button.tsx exports

   Go Coordinator                              MoonBit Worker
        │                                            │
        │  ┌─────────────────────────────────────────────────────────────┐
        │  │ CHECK REQUEST                                               │
        │  │ {                                                           │
        │  │   "command": "check",                                       │
        │  │   "file": "app.ts",                                         │
        │  │   "source": "                                               │
        │  │     import { fetchUser } from './api';                      │
        │  │     import { Button } from './Button';                      │
        │  │     ...                                                     │
        │  │   ",                                                        │
        │  │   "importedTypes": {                                        │
        │  │     "./api": {                  ◄── From cache              │
        │  │       "exports": {                                          │
        │  │         "fetchUser": {                                      │
        │  │           "symbolKind": "function",                         │
        │  │           "type": {                                         │
        │  │             "kind": "function",                             │
        │  │             "parameters": [...],                            │
        │  │             "returnType": {                                 │
        │  │               "kind": "reference",                          │
        │  │               "name": "Promise",                            │
        │  │               "typeArguments": [{"kind":"reference","name":"User"}]
        │  │             }                                               │
        │  │           }                                                 │
        │  │         }                                                   │
        │  │       }                                                     │
        │  │     },                                                      │
        │  │     "./Button": {               ◄── From cache              │
        │  │       "exports": {                                          │
        │  │         "Button": {...},                                    │
        │  │         "ButtonProps": {...}                                │
        │  │       }                                                     │
        │  │     }                                                       │
        │  │   }                                                         │
        │  │ }                                                           │
        │  └─────────────────────────────────────────────────────────────┘
        │                    │
        │                    ▼
        │  ┌─────────────────────────────────────────────────────────────┐
        │  │                    MOONBIT WORKER                           │
        │  │                                                             │
        │  │  1. Parse: import { fetchUser } from './api'                │
        │  │                                                             │
        │  │  2. Bind: Create symbol "fetchUser" in scope                │
        │  │                                                             │
        │  │  3. Check:                                                  │
        │  │     ┌──────────────────────────────────────────────────┐    │
        │  │     │ When checker sees: fetchUser(123)                │    │
        │  │     │                                                  │    │
        │  │     │ 1. Look up "fetchUser" in local scope            │    │
        │  │     │    → Found: imported symbol                      │    │
        │  │     │                                                  │    │
        │  │     │ 2. Resolve type from importedTypes:              │    │
        │  │     │    importedTypes["./api"]["fetchUser"]           │    │
        │  │     │    → { kind: "function", params: [...] }         │    │
        │  │     │                                                  │    │
        │  │     │ 3. Deserialize to internal Type                  │    │
        │  │     │    → Function(CheckerFunctionType { ... })       │    │
        │  │     │                                                  │    │
        │  │     │ 4. Type check call: fetchUser(123)               │    │
        │  │     │    → Check arg types match param types           │    │
        │  │     │    → Return type: Promise<User>                  │    │
        │  │     └──────────────────────────────────────────────────┘    │
        │  │                                                             │
        │  └─────────────────────────────────────────────────────────────┘
        │                    │
        │                    ▼
        │  ┌─────────────────────────────────────────────────────────────┐
        │  │ CHECK RESPONSE                                              │
        │  │ {                                                           │
        │  │   "success": true,                                          │
        │  │   "diagnostics": [],                                        │
        │  │   "exportedTypes": {                                        │
        │  │     "exports": {                                            │
        │  │       "main": { "symbolKind": "function", ... }             │
        │  │     }                                                       │
        │  │   }                                                         │
        │  │ }                                                           │
        │  └─────────────────────────────────────────────────────────────┘
```

---

## Phase 5: Error Reporting

```
┌─────────────────────────────────────────────────────────────────────────────┐
│                    PHASE 5: ERROR AGGREGATION                                │
└─────────────────────────────────────────────────────────────────────────────┘

   All workers complete, Go coordinator aggregates diagnostics:

   ┌─────────────────────────────────────────────────────────────────────────┐
   │                         WORKER RESPONSES                                │
   │                                                                         │
   │  types.ts:    { diagnostics: [] }                    ✓ No errors       │
   │  utils.ts:    { diagnostics: [] }                    ✓ No errors       │
   │  api.ts:      { diagnostics: [] }                    ✓ No errors       │
   │  Button.tsx:  { diagnostics: [{                      ✗ 1 error         │
   │                  code: 2322,                                            │
   │                  message: "Type 'string' is not assignable to 'number'",│
   │                  line: 15, column: 8                                    │
   │               }] }                                                      │
   │  app.ts:      { diagnostics: [] }                    ✓ No errors       │
   └─────────────────────────────────────────────────────────────────────────┘
                                     │
                                     ▼
   ┌─────────────────────────────────────────────────────────────────────────┐
   │                         TERMINAL OUTPUT                                 │
   │                                                                         │
   │  src/components/Button.tsx(15,8): error TS2322:                        │
   │      Type 'string' is not assignable to type 'number'.                 │
   │                                                                         │
   │  Found 1 error in 1 file.                                              │
   │                                                                         │
   │  Files checked: 5                                                       │
   │  Time: 45ms                                                             │
   └─────────────────────────────────────────────────────────────────────────┘
```

---

## Inside MoonBit Worker: Type Resolution Flow

```
┌─────────────────────────────────────────────────────────────────────────────┐
│              INSIDE MOONBIT WORKER: RESOLVING IMPORTED TYPE                  │
└─────────────────────────────────────────────────────────────────────────────┘

   Source code:
   ┌────────────────────────────────────────────────────────────────┐
   │  import { User } from './types';                               │
   │                                                                │
   │  function greet(user: User): string {                          │
   │    return `Hello, ${user.name}`;                               │
   │  }                                                             │
   └────────────────────────────────────────────────────────────────┘

   importedTypes (from Go):
   ┌────────────────────────────────────────────────────────────────┐
   │  {                                                             │
   │    "./types": {                                                │
   │      "exports": {                                              │
   │        "User": {                                               │
   │          "symbolKind": "interface",                            │
   │          "type": {                                             │
   │            "kind": "object",                                   │
   │            "properties": {                                     │
   │              "id": { "type": { "kind": "number" } },           │
   │              "name": { "type": { "kind": "string" } }          │
   │            }                                                   │
   │          }                                                     │
   │        }                                                       │
   │      }                                                         │
   │    }                                                           │
   │  }                                                             │
   └────────────────────────────────────────────────────────────────┘


   STEP 1: PARSING
   ───────────────

   Parser creates AST:
   ┌────────────────────────────────────────────────────────────────┐
   │  SourceFile                                                    │
   │  ├── ImportDeclaration                                         │
   │  │   ├── moduleSpecifier: "./types"                            │
   │  │   └── namedBindings: [{ name: "User" }]                     │
   │  │                                                             │
   │  └── FunctionDeclaration                                       │
   │      ├── name: "greet"                                         │
   │      ├── parameters: [{ name: "user", type: TypeReference("User") }]
   │      ├── returnType: TypeReference("string")                   │
   │      └── body: ...                                             │
   └────────────────────────────────────────────────────────────────┘


   STEP 2: BINDING
   ───────────────

   Binder creates symbols:
   ┌────────────────────────────────────────────────────────────────┐
   │  Global Scope                                                  │
   │  ├── "User" → Symbol {                                         │
   │  │              kind: Alias,                                   │
   │  │              flags: { is_import: true },                    │
   │  │              import_specifier: "./types"                    │
   │  │           }                                                 │
   │  │                                                             │
   │  └── "greet" → Symbol {                                        │
   │                 kind: Function,                                │
   │                 declarations: [FunctionDeclaration]            │
   │               }                                                │
   └────────────────────────────────────────────────────────────────┘


   STEP 3: TYPE CHECKING
   ─────────────────────

   When checker encounters `user: User`:

   ┌────────────────────────────────────────────────────────────────┐
   │                                                                │
   │  1. Look up "User" in global_scope.symbols                     │
   │     → Found: Symbol { kind: Alias, import_specifier: "./types"}│
   │                                                                │
   │  2. This is an import alias! Resolve from importedTypes:       │
   │     ┌──────────────────────────────────────────────────────┐   │
   │     │ fn resolve_import(checker, "./types", "User"):       │   │
   │     │                                                      │   │
   │     │   // Look up in importedTypes                        │   │
   │     │   let module = importedTypes.get("./types")          │   │
   │     │   let export = module.exports.get("User")            │   │
   │     │                                                      │   │
   │     │   // Deserialize JSON type to internal Type          │   │
   │     │   let type = deserialize_type(export.type)           │   │
   │     │   // → Type::Object(ObjectType {                     │   │
   │     │   //     properties: {                               │   │
   │     │   //       "id": PropertySignature { type: Number }, │   │
   │     │   //       "name": PropertySignature { type: String }│   │
   │     │   //     }                                           │   │
   │     │   //   })                                            │   │
   │     │                                                      │   │
   │     │   return type                                        │   │
   │     └──────────────────────────────────────────────────────┘   │
   │                                                                │
   │  3. Cache the resolved type for future lookups                 │
   │     checker.imported_type_cache["./types::User"] = resolved    │
   │                                                                │
   │  4. Use resolved type to check function body:                  │
   │     `user.name` → Check "name" exists on User → ✓ string       │
   │                                                                │
   └────────────────────────────────────────────────────────────────┘
```

---

## Incremental Type Checking (Watch Mode)

```
┌─────────────────────────────────────────────────────────────────────────────┐
│                    WATCH MODE: INCREMENTAL CHECK                             │
└─────────────────────────────────────────────────────────────────────────────┘

   Initial state (all files checked):

   TYPE CACHE:
   ┌────────────────────────────────────────────────────────────────┐
   │  types.ts   → { User, Config }           (hash: abc123)       │
   │  utils.ts   → { formatDate }             (hash: def456)       │
   │  api.ts     → { fetchUser }              (hash: ghi789)       │
   │  Button.tsx → { Button, ButtonProps }    (hash: jkl012)       │
   │  app.ts     → { main }                   (hash: mno345)       │
   └────────────────────────────────────────────────────────────────┘

   ═══════════════════════════════════════════════════════════════════════════

   User edits types.ts:
   ┌────────────────────────────────────────────────────────────────┐
   │  interface User {                                              │
   │    id: number;                                                 │
   │    name: string;                                               │
   │    email: string;  ◄── NEW PROPERTY ADDED                      │
   │  }                                                             │
   └────────────────────────────────────────────────────────────────┘

   ═══════════════════════════════════════════════════════════════════════════

   Go Coordinator detects change via fsnotify:

   1. File changed: types.ts

   2. Compute new hash: pqr678 (different from abc123)

   3. Find dependents in dependency graph:
      ┌──────────────────────────────────────────────────────────────┐
      │  types.ts ◄── [utils.ts, api.ts, Button.tsx]                │
      │                     │                                        │
      │                     └────► [app.ts]                          │
      │                                                              │
      │  Affected files: ALL except types.ts itself                  │
      │  Recheck order: types.ts → utils.ts, api.ts, Button.tsx → app.ts
      └──────────────────────────────────────────────────────────────┘

   4. Recheck types.ts first:
      ┌──────────────────────────────────────────────────────────────┐
      │  Worker checks types.ts                                      │
      │  → Returns new exports with email property                   │
      │  → Update cache: types.ts → { User: {..., email} }          │
      └──────────────────────────────────────────────────────────────┘

   5. Recheck dependents with NEW importedTypes:
      ┌──────────────────────────────────────────────────────────────┐
      │  Workers check utils.ts, api.ts, Button.tsx in parallel     │
      │  → Each receives updated User type with email               │
      │  → Type check against new definition                        │
      │  → May produce NEW errors if code doesn't handle email      │
      └──────────────────────────────────────────────────────────────┘

   6. Recheck app.ts with updated transitive dependencies

   7. Report any new diagnostics to terminal
```

---

## Sequence Diagram: Complete Flow

```
┌─────┐          ┌──────────────┐          ┌────────────┐          ┌─────────────┐
│User │          │Go Coordinator│          │Type Cache  │          │MoonBit      │
│     │          │              │          │            │          │Workers      │
└──┬──┘          └──────┬───────┘          └─────┬──────┘          └──────┬──────┘
   │                    │                        │                        │
   │ $ tsc ./src        │                        │                        │
   │───────────────────>│                        │                        │
   │                    │                        │                        │
   │                    │ Parse tsconfig         │                        │
   │                    │ Find all .ts files     │                        │
   │                    │                        │                        │
   │                    │ Parse imports (parallel)                        │
   │                    │───────────────────────────────────────────────>│
   │                    │                        │                        │
   │                    │<───────────────────────────────────────────────│
   │                    │ Import lists           │                        │
   │                    │                        │                        │
   │                    │ Build dep graph        │                        │
   │                    │ Topological sort       │                        │
   │                    │                        │                        │
   │                    │                        │                        │
   │                    │ ══════ Level 0 ══════  │                        │
   │                    │                        │                        │
   │                    │ Check types.ts         │                        │
   │                    │ (importedTypes: {})    │                        │
   │                    │───────────────────────────────────────────────>│
   │                    │                        │                        │
   │                    │<───────────────────────────────────────────────│
   │                    │ exports: {User,Config} │                        │
   │                    │                        │                        │
   │                    │ Store exports          │                        │
   │                    │───────────────────────>│                        │
   │                    │                        │                        │
   │                    │ ══════ Level 1 ══════  │                        │
   │                    │                        │                        │
   │                    │ Get imports for        │                        │
   │                    │ utils.ts, api.ts       │                        │
   │                    │<───────────────────────│                        │
   │                    │ {User, Config}         │                        │
   │                    │                        │                        │
   │                    │ Check utils.ts, api.ts (parallel)              │
   │                    │ (importedTypes: cached)│                        │
   │                    │───────────────────────────────────────────────>│
   │                    │                        │                        │
   │                    │<───────────────────────────────────────────────│
   │                    │ exports + diagnostics  │                        │
   │                    │                        │                        │
   │                    │ Store exports          │                        │
   │                    │───────────────────────>│                        │
   │                    │                        │                        │
   │                    │ ══════ Level 2 ══════  │                        │
   │                    │                        │                        │
   │                    │ Get imports for app.ts │                        │
   │                    │<───────────────────────│                        │
   │                    │ {fetchUser, Button}    │                        │
   │                    │                        │                        │
   │                    │ Check app.ts           │                        │
   │                    │───────────────────────────────────────────────>│
   │                    │                        │                        │
   │                    │<───────────────────────────────────────────────│
   │                    │                        │                        │
   │                    │ Aggregate diagnostics  │                        │
   │                    │                        │                        │
   │ Show results       │                        │                        │
   │<───────────────────│                        │                        │
   │                    │                        │                        │
```

---

## Summary: Data Flow

```
┌─────────────────────────────────────────────────────────────────────────────┐
│                         COMPLETE DATA FLOW                                   │
└─────────────────────────────────────────────────────────────────────────────┘

    ┌─────────────────────────────────────────────────────────────────────┐
    │                           GO COORDINATOR                            │
    │                                                                     │
    │  Input:                        Output:                              │
    │  - tsconfig.json               - Aggregated diagnostics             │
    │  - Source files                - .js files (emit)                   │
    │                                - .d.ts files (declarations)         │
    │                                                                     │
    │  ┌───────────────────────────────────────────────────────────────┐  │
    │  │                      TYPE CACHE                               │  │
    │  │                                                               │  │
    │  │  Stores: module path → { name → SerializedType }              │  │
    │  │  Used to: Build importedTypes for each check request          │  │
    │  │  Updated: After each successful check response                │  │
    │  └───────────────────────────────────────────────────────────────┘  │
    │                                                                     │
    └──────────────────────────────────┬──────────────────────────────────┘
                                       │
                                       │ IPC (JSON over stdin/stdout)
                                       │
                    ┌──────────────────┴──────────────────┐
                    │                                     │
                    ▼                                     ▼
    ┌───────────────────────────────┐   ┌───────────────────────────────┐
    │       CHECK REQUEST           │   │       CHECK RESPONSE          │
    │                               │   │                               │
    │  - file: string               │   │  - success: bool              │
    │  - source: string             │   │  - diagnostics: []            │
    │  - importedTypes: {           │   │  - exportedTypes: {           │
    │      "./types": {             │   │      "User": {                │
    │        "User": SerializedType │   │        symbolKind, type       │
    │      }                        │   │      }                        │
    │    }                          │   │    }                          │
    └───────────────────────────────┘   └───────────────────────────────┘
                    │                                     ▲
                    │                                     │
                    ▼                                     │
    ┌─────────────────────────────────────────────────────────────────────┐
    │                         MOONBIT WORKER                              │
    │                                                                     │
    │  ┌─────────┐   ┌─────────┐   ┌─────────┐   ┌───────────────────┐   │
    │  │ Scanner │──►│ Parser  │──►│ Binder  │──►│ TypeChecker       │   │
    │  └─────────┘   └─────────┘   └─────────┘   │                   │   │
    │                                            │ - global_scope    │   │
    │                                            │ - importedTypes ◄─┼───┤
    │                                            │ - symbol_types   │   │
    │                                            │                   │   │
    │                                            │ When resolving    │   │
    │                                            │ import symbol:    │   │
    │                                            │ 1. Look up in     │   │
    │                                            │    importedTypes  │   │
    │                                            │ 2. Deserialize    │   │
    │                                            │ 3. Use for check  │   │
    │                                            └───────────────────┘   │
    │                                                     │              │
    │                                                     ▼              │
    │                                            ┌───────────────────┐   │
    │                                            │ Extract Exports   │   │
    │                                            │ Serialize Types   │   │
    │                                            └───────────────────┘   │
    │                                                                     │
    └─────────────────────────────────────────────────────────────────────┘
```
