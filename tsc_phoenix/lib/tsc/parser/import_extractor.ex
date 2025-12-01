defmodule TSC.Parser.ImportExtractor do
  @moduledoc """
  Extracts import statements from TypeScript files.

  Supports:
  - ES6 imports: `import { x } from 'module'`
  - Default imports: `import x from 'module'`
  - Namespace imports: `import * as x from 'module'`
  - Side-effect imports: `import 'module'`
  - Dynamic imports: `import('module')`
  - Require calls: `require('module')`
  - Re-exports: `export { x } from 'module'`
  - Triple-slash references: `/// <reference path="..." />`
  - Triple-slash types: `/// <reference types="..." />`
  """

  @type import_info :: %{
    specifier: String.t(),
    kind: :es6 | :require | :dynamic | :reexport | :side_effect | :reference | :reference_types,
    line: pos_integer(),
    named: list(String.t()),
    default: String.t() | nil,
    namespace: String.t() | nil
  }

  @doc """
  Extract all imports from a TypeScript file.
  """
  @spec extract(String.t()) :: {:ok, list(import_info())} | {:error, term()}
  def extract(file_path) do
    case File.read(file_path) do
      {:ok, content} ->
        {:ok, extract_from_content(content)}

      {:error, reason} ->
        {:error, reason}
    end
  end

  @doc """
  Extract imports from content string.
  """
  @spec extract_from_content(String.t()) :: list(import_info())
  def extract_from_content(content) do
    lines = String.split(content, "\n")

    lines
    |> Enum.with_index(1)
    |> Enum.flat_map(fn {line, line_num} ->
      extract_from_line(line, line_num)
    end)
    |> Enum.uniq_by(& &1.specifier)
  end

  @doc """
  Resolve import specifier to absolute file path.
  """
  @spec resolve(String.t(), String.t()) :: String.t() | nil
  def resolve(source_file, specifier) do
    source_dir = Path.dirname(source_file)

    cond do
      # Relative import
      String.starts_with?(specifier, ".") ->
        resolve_relative(source_dir, specifier)

      # Absolute path (rare but possible)
      String.starts_with?(specifier, "/") ->
        resolve_with_extensions(specifier)

      # Node module - return nil (external dependency)
      true ->
        nil
    end
  end

  # ============================================================================
  # Private - Line Parsing
  # ============================================================================

  defp extract_from_line(line, line_num) do
    trimmed = String.trim(line)

    cond do
      # Triple-slash reference directive (must be checked before general comment skip)
      String.starts_with?(trimmed, "/// <reference") ->
        parse_triple_slash_reference(trimmed, line_num)

      # Skip other comments
      String.starts_with?(trimmed, "//") ->
        []

      String.starts_with?(trimmed, "/*") ->
        []

      # TypeScript import assignment: import x = require("...")
      Regex.match?(~r/^import\s+\w+\s*=\s*require\s*\(/, trimmed) ->
        parse_import_assignment(trimmed, line_num)

      # ES6 import
      String.starts_with?(trimmed, "import ") ->
        parse_es6_import(trimmed, line_num)

      # Re-export
      Regex.match?(~r/^export\s+.*\s+from\s+/, trimmed) ->
        parse_reexport(trimmed, line_num)

      # Dynamic import
      String.contains?(trimmed, "import(") ->
        parse_dynamic_imports(trimmed, line_num)

      # Require
      String.contains?(trimmed, "require(") ->
        parse_require(trimmed, line_num)

      true ->
        []
    end
  end

  # Triple-slash reference directive: /// <reference path="..." /> or /// <reference types="..." />
  defp parse_triple_slash_reference(line, line_num) do
    # Pattern for path reference: /// <reference path="./foo" />
    path_pattern = ~r/<reference\s+path\s*=\s*["']([^"']+)["']\s*\/>/

    # Pattern for types reference: /// <reference types="node" />
    types_pattern = ~r/<reference\s+types\s*=\s*["']([^"']+)["']\s*\/>/

    # Pattern for lib reference: /// <reference lib="es2015" />
    lib_pattern = ~r/<reference\s+lib\s*=\s*["']([^"']+)["']\s*\/>/

    cond do
      Regex.match?(path_pattern, line) ->
        case Regex.run(path_pattern, line) do
          [_, specifier] ->
            [%{specifier: specifier, kind: :reference, line: line_num, named: [], default: nil, namespace: nil}]
          _ ->
            []
        end

      Regex.match?(types_pattern, line) ->
        case Regex.run(types_pattern, line) do
          [_, specifier] ->
            # Types references are like @types/package - external dependencies
            [%{specifier: specifier, kind: :reference_types, line: line_num, named: [], default: nil, namespace: nil}]
          _ ->
            []
        end

      Regex.match?(lib_pattern, line) ->
        # Lib references point to built-in TypeScript libs, skip them
        []

      true ->
        []
    end
  end

  # TypeScript import assignment: import x = require("...")
  defp parse_import_assignment(line, line_num) do
    pattern = ~r/import\s+(\w+)\s*=\s*require\s*\(\s*['"]([^'"]+)['"]\s*\)/

    case Regex.run(pattern, line) do
      [_, name, specifier] ->
        [%{specifier: specifier, kind: :require, line: line_num, named: [], default: name, namespace: nil}]

      _ ->
        []
    end
  end

  # ES6 import: import { x, y } from 'module'
  # import x from 'module'
  # import * as x from 'module'
  # import 'module'
  defp parse_es6_import(line, line_num) do
    # Pattern for import with from clause
    from_pattern = ~r/import\s+(.+?)\s+from\s+['"]([^'"]+)['"]/

    # Pattern for side-effect import
    side_effect_pattern = ~r/import\s+['"]([^'"]+)['"]/

    cond do
      Regex.match?(from_pattern, line) ->
        case Regex.run(from_pattern, line) do
          [_, imports_part, specifier] ->
            [build_import(specifier, :es6, line_num, parse_import_clause(imports_part))]

          _ ->
            []
        end

      Regex.match?(side_effect_pattern, line) ->
        case Regex.run(side_effect_pattern, line) do
          [_, specifier] ->
            [%{specifier: specifier, kind: :side_effect, line: line_num, named: [], default: nil, namespace: nil}]

          _ ->
            []
        end

      true ->
        []
    end
  end

  # Parse import clause: { x, y }, default, * as namespace
  defp parse_import_clause(clause) do
    trimmed = String.trim(clause)

    cond do
      # Namespace import: * as name
      String.starts_with?(trimmed, "*") ->
        case Regex.run(~r/\*\s+as\s+(\w+)/, trimmed) do
          [_, name] -> %{named: [], default: nil, namespace: name}
          _ -> %{named: [], default: nil, namespace: nil}
        end

      # Named imports with possible default: default, { named }
      String.contains?(trimmed, "{") ->
        parse_mixed_imports(trimmed)

      # Default import only
      true ->
        %{named: [], default: String.trim(trimmed), namespace: nil}
    end
  end

  defp parse_mixed_imports(clause) do
    # Extract named imports from braces
    named =
      case Regex.run(~r/\{([^}]+)\}/, clause) do
        [_, names_str] ->
          names_str
          |> String.split(",")
          |> Enum.map(&String.trim/1)
          |> Enum.map(fn name ->
            # Handle "x as y" aliases - use the local name
            case String.split(name, ~r/\s+as\s+/) do
              [_, local] -> String.trim(local)
              [original] -> String.trim(original)
            end
          end)
          |> Enum.reject(&(&1 == ""))

        _ ->
          []
      end

    # Check for default import before the braces
    default =
      case Regex.run(~r/^(\w+)\s*,\s*\{/, clause) do
        [_, default_name] -> default_name
        _ -> nil
      end

    %{named: named, default: default, namespace: nil}
  end

  # Re-export: export { x } from 'module'
  defp parse_reexport(line, line_num) do
    pattern = ~r/export\s+(?:\{[^}]*\}|\*)\s+from\s+['"]([^'"]+)['"]/

    case Regex.run(pattern, line) do
      [_, specifier] ->
        [%{specifier: specifier, kind: :reexport, line: line_num, named: [], default: nil, namespace: nil}]

      _ ->
        []
    end
  end

  # Dynamic import: import('module')
  defp parse_dynamic_imports(line, line_num) do
    pattern = ~r/import\s*\(\s*['"]([^'"]+)['"]\s*\)/

    Regex.scan(pattern, line)
    |> Enum.map(fn [_, specifier] ->
      %{specifier: specifier, kind: :dynamic, line: line_num, named: [], default: nil, namespace: nil}
    end)
  end

  # Require: require('module')
  defp parse_require(line, line_num) do
    pattern = ~r/require\s*\(\s*['"]([^'"]+)['"]\s*\)/

    Regex.scan(pattern, line)
    |> Enum.map(fn [_, specifier] ->
      %{specifier: specifier, kind: :require, line: line_num, named: [], default: nil, namespace: nil}
    end)
  end

  defp build_import(specifier, kind, line_num, %{named: named, default: default, namespace: namespace}) do
    %{
      specifier: specifier,
      kind: kind,
      line: line_num,
      named: named,
      default: default,
      namespace: namespace
    }
  end

  # ============================================================================
  # Private - Path Resolution
  # ============================================================================

  defp resolve_relative(source_dir, specifier) do
    base_path = Path.join(source_dir, specifier) |> Path.expand()
    resolve_with_extensions(base_path)
  end

  defp resolve_with_extensions(base_path) do
    extensions = [
      "",           # Exact match
      ".ts",
      ".tsx",
      ".d.ts",
      ".js",
      ".jsx",
      "/index.ts",
      "/index.tsx",
      "/index.d.ts",
      "/index.js"
    ]

    Enum.find_value(extensions, fn ext ->
      full_path = base_path <> ext
      if File.exists?(full_path), do: full_path
    end)
  end
end
