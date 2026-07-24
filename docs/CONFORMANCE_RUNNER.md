# TypeScript Conformance Test Runner

`run_conformance_tests.exs` (repo root) runs the official TypeScript compiler
conformance suite against the MoonBit compiler CLI and compares results with
the checked-in baselines from microsoft/TypeScript.

## Prerequisites

- Elixir (`/opt/homebrew/bin/elixir` or on PATH)
- A built CLI: `cd src/moonbit && moon build --target native`
- A TypeScript repo checkout (only `tests/` is used):

  ```sh
  git clone --depth 1 https://github.com/microsoft/TypeScript ../typescript-repo
  ```

## Environment variables

| Variable  | Meaning                              | Default (relative to the script) |
|-----------|--------------------------------------|----------------------------------|
| `TSC_CLI` | Path to the compiler CLI executable  | `src/moonbit/_build/native/debug/build/cli/cli.exe` |
| `TS_REPO` | Path to the TypeScript repo checkout | `../typescript-repo`             |

## Usage

```sh
# Loose mode, one category (paths are relative to tests/cases/conformance)
./run_conformance_tests.exs es6/computedProperties

# Strict mode: compare TSxxxx error-code sets against the baseline
./run_conformance_tests.exs es6/templates --strict

# Every category, per-category summary table + overall totals
./run_conformance_tests.exs --all
./run_conformance_tests.exs --all --strict

# Smoke run: only the first N tests (per category in --all mode)
./run_conformance_tests.exs --all --limit 10

# Print individual failures in --all mode too
./run_conformance_tests.exs --all --verbose
```

## Modes

### Loose mode (default)

A test passes when "the compiler reported errors" matches "a baseline
`tests/baselines/reference/<name>.errors.txt` exists". This only checks the
*presence* of errors, not which ones — useful as a coarse progress signal.

### Strict mode (`--strict`)

The runner extracts the set of `TSxxxx` error codes from the baseline
`.errors.txt` and from the compiler output (`--reportDiagnostics`), and the
test passes only when the two sets are equal. Failures report the diff:

```
FAIL: templateStringInObjectLiteral missing=[TS1005,TS1128,...] extra=[TS1000,TS1003]
```

- `missing` — codes the baseline expects that the compiler did not emit
- `extra`   — codes the compiler emitted that the baseline does not contain

Strict mode compares code *sets*, not occurrence counts or positions, so it is
still weaker than tsc's own baseline diffing, but far stronger than loose mode.

### Variant baselines

Some tests produce per-configuration baselines such as
`name(target=es5).errors.txt` instead of `name.errors.txt`. When only variant
baselines exist:

- loose mode treats the test as "expects errors" if any variant exists;
- strict mode uses the **union** of codes across all variants (the runner
  compiles only one configuration, so the union is the most permissive set
  that never rejects a code tsc itself would emit for some variant).

Such tests are tagged `[variant baseline]` in failure output.

## Test directives

Conformance tests embed harness directives (`// @target: es5`, `// @filename:
a.ts`, `// @strict: true`, ...). The runner honors `@target` and `@module` by
passing the corresponding CLI flags (first value if comma-separated).

`@filename` multi-file tests are honored by synthesis: the runner splits the
test into real files in a per-test temp directory (mirroring the TypeScript
harness `makeUnitsFromTest` semantics — case-insensitive markers, directive
lines before the first marker treated as global options and prepended to each
unit) and invokes the CLI with every `.ts`/`.tsx` unit at once, so relative
imports between units resolve against the real filesystem. Non-compilable
units (`package.json`, `.js`, ...) are still written to disk so module
resolution can see them. Diagnostics are aggregated across all units. When
synthesis succeeds, `filename` no longer counts as unhonored.

`@currentDirectory` is honored during synthesis: the tsc harness treats unit
paths as relative to it, so the runner resolves each unit name against the
directive value before placing it in the temp dir (the temp dir plays the
role of the filesystem root). Units spelled `b.ts` and `/root/a.ts` therefore
land in the same directory when `@currentDirectory: /root`.

Two directives are treated as inert (never counted as unhonored) because they
cannot change the diagnostics we compare against:

* `@noImplicitReferences` — harness-only option making tsc compile only the
  last unit and pull the rest in via imports/references; tsc applies the same
  behavior implicitly whenever the last unit contains `require(` or a
  `/// <reference path`, and the runner already writes every unit to disk and
  compiles them together.
* `@traceResolution` — only adds module-resolution trace output (baselined
  separately as `.trace.json`).

A further set is treated as **honored in-file**: the compiler parses these
`// @directive:` markers directly from the source text and self-applies them
during checking, so passing the file already honors them — the runner need not
translate them into CLI flags. These are `@strict`, `@strictNullChecks`,
`@strictPropertyInitialization`, and `@noImplicitAny` (the strict family, which
defaults ON in the compiler to match how the baselines are generated; see
`effective_strict_flags` / `effective_no_implicit_any` in `checker.mbt`). A test
whose only unhonored directive is one of these is therefore judged on
diagnostics like any fully-honored test, not demoted to `DirFail`.

All other directives cannot be honored; those tests still run, but if they
fail they are counted in a separate "Failed*" / `DirFail` bucket and tagged
`[unhonored: ...]` so genuine diagnostic mismatches are not conflated with
harness limitations.

## Result buckets

| Bucket    | Meaning                                                        |
|-----------|----------------------------------------------------------------|
| Passed    | Matches the baseline for the selected mode                     |
| Failed    | Diagnostic mismatch on a test with no unhonored directives     |
| Failed* / DirFail | Mismatch on a test with unhonored directives (e.g. `@filename`) |
| Crashed   | Compiler crash (abnormal exit code, panic output) or 30s timeout |
