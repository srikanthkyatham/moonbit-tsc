#!/bin/bash

# Setup script for MoonBit TypeScript Compiler development

set -e

SCRIPT_DIR="$( cd "$( dirname "${BASH_SOURCE[0]}" )" && pwd )"
PROJECT_DIR="$( cd "$SCRIPT_DIR/.." && pwd )"
MOONBIT_DIR="$( cd "$PROJECT_DIR/../src/moonbit" && pwd )"

echo "=== MoonBit TSC Development Setup ==="
echo ""

# Check for Elixir
if ! command -v elixir &> /dev/null; then
    echo "Error: Elixir is not installed"
    echo "Please install Elixir: https://elixir-lang.org/install.html"
    exit 1
fi

echo "Elixir version: $(elixir --version | head -1)"
echo ""

# Check for Moon
if ! command -v moon &> /dev/null; then
    echo "Error: Moon CLI is not installed"
    echo "Please install Moon: https://www.moonbitlang.com/"
    exit 1
fi

echo "Moon version: $(moon version 2>/dev/null || echo 'unknown')"
echo ""

# Build MoonBit CLI if not exists
CLI_PATH="$MOONBIT_DIR/target/native/release/build/cli/cli.exe"
if [ ! -f "$CLI_PATH" ]; then
    echo "Building MoonBit CLI..."
    cd "$MOONBIT_DIR"
    moon build --target native
    echo "MoonBit CLI built"
else
    echo "MoonBit CLI already built"
fi
echo ""

# Copy CLI to priv/bin
echo "Setting up CLI binary..."
mkdir -p "$PROJECT_DIR/priv/bin"
cp "$CLI_PATH" "$PROJECT_DIR/priv/bin/moonbit-cli"
chmod +x "$PROJECT_DIR/priv/bin/moonbit-cli"
echo "CLI binary available at: $PROJECT_DIR/priv/bin/moonbit-cli"
echo ""

# Get Elixir dependencies
echo "Fetching Elixir dependencies..."
cd "$PROJECT_DIR"
mix deps.get
echo ""

# Compile
echo "Compiling..."
mix compile
echo ""

echo "=== Setup Complete ==="
echo ""
echo "Available commands:"
echo "  mix test        - Run tests"
echo "  mix compile     - Compile project"
echo "  ./scripts/build.sh - Build release"
