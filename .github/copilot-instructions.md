# GitHub Copilot Instructions for Pure MoonBit CLI

## Project Overview

This is a pure MoonBit implementation of a TypeScript compiler/checker CLI. The project uses **bd (beads)** for issue tracking.

**Key Features:**
- TypeScript parser written in MoonBit
- Type checker implementation
- Diagnostic reporting
- ES6+ feature support

## Tech Stack

- **Language**: MoonBit
- **Build System**: moon build
- **Testing**: moon test
- **Target**: native

## Coding Guidelines

### Building
- Always use `moon build --target native` to build the CLI
- Build from the `/src/moonbit` directory
- Clean build when needed: `moon clean && moon build --target native`

### Testing
- Run tests with `moon test`
- Test conformance with TypeScript repo test cases
- CLI location: `target/native/release/build/cli/cli.exe`

### Code Style
- Follow MoonBit conventions
- Update parser carefully to avoid regressions
- Test inline type literals when modifying type parsing

### Git Workflow
- Always commit `.beads/issues.jsonl` with code changes
- Run `bd sync` at end of work sessions
- Ensure all tests pass before committing

## Issue Tracking with bd

**CRITICAL**: This project uses **bd** for ALL task tracking. Do NOT create markdown TODO lists.

### Essential Commands

```bash
# Find work
bd ready --json                    # Unblocked issues
bd stale --days 30 --json          # Forgotten issues

# Create and manage
bd create "Title" -t bug|feature|task -p 0-4 --json
bd create "Subtask" --parent <epic-id> --json  # Hierarchical subtask
bd update <id> --status in_progress --json
bd close <id> --reason "Done" --json

# Search
bd list --status open --priority 1 --json
bd show <id> --json

# Sync (CRITICAL at end of session!)
bd sync  # Force immediate export/commit/push
```

### Workflow

1. **Check ready work**: `bd ready --json`
2. **Claim task**: `bd update <id> --status in_progress`
3. **Work on it**: Implement, test, document
4. **Discover new work?** `bd create "Found bug" -p 1 --deps discovered-from:<parent-id> --json`
5. **Complete**: `bd close <id> --reason "Done" --json`
6. **Sync**: `bd sync` (flushes changes to git immediately)

### Priorities

- `0` - Critical (security, data loss, broken builds)
- `1` - High (major features, important bugs)
- `2` - Medium (default, nice-to-have)
- `3` - Low (polish, optimization)
- `4` - Backlog (future ideas)

## Project Structure

```
pure-moonbit-cli/
├── src/moonbit/
│   ├── compiler/
│   │   ├── parser.mbt           # Main parser
│   │   ├── parser_type.mbt      # Type expression parser
│   │   └── ast.mbt              # AST definitions
│   └── target/native/release/build/cli/cli.exe  # Built CLI
└── .beads/
    ├── beads.db                 # SQLite database (DO NOT COMMIT)
    └── issues.jsonl             # Git-synced issue storage
```

## CLI Help

Run `bd <command> --help` to see all available flags for any command.
For example: `bd create --help` shows `--parent`, `--deps`, `--assignee`, etc.

## Important Rules

- ✅ Use bd for ALL task tracking
- ✅ Always use `--json` flag for programmatic use
- ✅ Run `bd sync` at end of sessions
- ✅ Build with `moon build --target native`
- ✅ Test regressions when modifying parser
- ✅ Run `bd <cmd> --help` to discover available flags
- ❌ Do NOT create markdown TODO lists
- ❌ Do NOT commit `.beads/beads.db` (JSONL only)
- ❌ Do NOT break inline type literal parsing

---

**For detailed workflows and advanced features, see [AGENTS.md](../AGENTS.md)**
