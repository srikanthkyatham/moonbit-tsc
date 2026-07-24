#!/usr/bin/env bash
# Conformance ratchet gate — wraps run_conformance_tests.exs --check-ratchet.
#
# Runs the full conformance sweep (loose + strict computed from one compile per
# test) and compares per-category pass counts against the committed
# conformance_ratchet.json. Any category whose loose_pass or strict_pass count
# dropped, or whose crash count rose, fails the check (exit 1).
#
# Prerequisites:
#   * Elixir on PATH
#   * MoonBit toolchain (moon) on PATH, or a prebuilt CLI via $TSC_CLI
#   * A microsoft/TypeScript checkout (tests/ is enough) at ../typescript-repo
#     relative to the repo root, or pointed to by $TS_REPO
#
# Behavior on missing prerequisites:
#   * default: print a clear SKIPPED message and exit 0 (so CI without the
#     toolchain/test corpus goes green-but-honest instead of red)
#   * RATCHET_REQUIRE=1: missing prerequisites are fatal (exit 2) — use this
#     locally so a misconfigured environment can't masquerade as a pass.
#
# Usage:
#   scripts/check_conformance_ratchet.sh            # check (the gate)
#   scripts/check_conformance_ratchet.sh --update   # re-bless after improvements

set -u

REPO_ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
MODE="--check-ratchet"
if [ "${1:-}" = "--update" ]; then
  MODE="--update-ratchet"
fi

skip() {
  echo "SKIPPED (not a pass, not a fail): $1" >&2
  if [ "${RATCHET_REQUIRE:-0}" = "1" ]; then
    echo "RATCHET_REQUIRE=1 set — treating missing prerequisite as an error." >&2
    exit 2
  fi
  exit 0
}

# 1. Elixir
command -v elixir >/dev/null 2>&1 || skip "Elixir not found on PATH (brew install elixir / apt install elixir)"

# 2. TypeScript repo (test cases + baselines)
TS_REPO="${TS_REPO:-$REPO_ROOT/../typescript-repo}"
if [ ! -d "$TS_REPO/tests/cases/conformance" ]; then
  skip "TypeScript repo not found at $TS_REPO (set TS_REPO, or: git clone --depth 1 https://github.com/microsoft/TypeScript \"$TS_REPO\")"
fi

# 3. Compiler CLI: use $TSC_CLI if given, else build with moon
TSC_CLI="${TSC_CLI:-$REPO_ROOT/src/moonbit/_build/native/debug/build/cli/cli.exe}"
if [ ! -x "$TSC_CLI" ]; then
  if command -v moon >/dev/null 2>&1 || [ -x "$HOME/.moon/bin/moon" ]; then
    export PATH="$HOME/.moon/bin:$PATH"
    echo "Building compiler CLI (moon build --target native)..."
    (cd "$REPO_ROOT/src/moonbit" && moon build --target native) ||
      skip "moon build failed — cannot produce a CLI to test"
  else
    skip "compiler CLI not found at $TSC_CLI and MoonBit toolchain (moon) not installed (https://www.moonbitlang.com/download/)"
  fi
fi
[ -x "$TSC_CLI" ] || skip "compiler CLI still missing after build: $TSC_CLI"

echo "CLI:     $TSC_CLI"
echo "TS repo: $TS_REPO"
echo "Mode:    $MODE"

TSC_CLI="$TSC_CLI" TS_REPO="$TS_REPO" exec "$REPO_ROOT/run_conformance_tests.exs" "$MODE"
