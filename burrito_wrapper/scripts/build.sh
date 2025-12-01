#!/bin/bash

# Build script for MoonBit TypeScript Compiler

set -e

SCRIPT_DIR="$( cd "$( dirname "${BASH_SOURCE[0]}" )" && pwd )"
PROJECT_DIR="$( cd "$SCRIPT_DIR/.." && pwd )"
MOONBIT_DIR="$( cd "$PROJECT_DIR/../src/moonbit" && pwd )"

echo "=== MoonBit TSC Build Script ==="
echo ""

# Step 1: Build MoonBit CLI
echo "Step 1: Building MoonBit CLI..."
cd "$MOONBIT_DIR"
moon build --target native
echo "MoonBit CLI built successfully"
echo ""

# Step 2: Copy CLI binary to priv/bin
echo "Step 2: Copying CLI binary..."
mkdir -p "$PROJECT_DIR/priv/bin"
cp "$MOONBIT_DIR/target/native/release/build/cli/cli.exe" "$PROJECT_DIR/priv/bin/moonbit-cli"
chmod +x "$PROJECT_DIR/priv/bin/moonbit-cli"
echo "CLI binary copied to priv/bin/moonbit-cli"
echo ""

# Step 3: Get Elixir dependencies
echo "Step 3: Getting Elixir dependencies..."
cd "$PROJECT_DIR"
mix deps.get
echo "Dependencies fetched"
echo ""

# Step 4: Compile Elixir project
echo "Step 4: Compiling Elixir project..."
MIX_ENV=prod mix compile
echo "Elixir project compiled"
echo ""

# Step 5: Build Burrito release
echo "Step 5: Building Burrito release..."
MIX_ENV=prod mix release
echo ""

echo "=== Build Complete ==="
echo "Release artifacts are in: $PROJECT_DIR/_build/prod/rel/moonbit_tsc/burrito_out/"
