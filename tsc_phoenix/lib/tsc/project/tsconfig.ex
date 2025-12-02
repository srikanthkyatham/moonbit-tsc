defmodule TSC.Project.TsConfig do
  @moduledoc """
  Parser for tsconfig.json files.

  Handles:
  - Loading and parsing tsconfig.json
  - Resolving "extends" inheritance
  - Expanding include/exclude glob patterns
  - Resolving project references
  """

  require Logger

  @default_include ["**/*.ts", "**/*.tsx"]
  @default_exclude ["node_modules", "bower_components", "jspm_packages", "dist", "build"]

  defstruct [
    :path,
    :root_dir,
    :compiler_options,
    :files,
    :include,
    :exclude,
    :references,
    :extends,
    :raw
  ]

  @type t :: %__MODULE__{
    path: String.t(),
    root_dir: String.t(),
    compiler_options: map(),
    files: list(String.t()),
    include: list(String.t()),
    exclude: list(String.t()),
    references: list(map()),
    extends: String.t() | nil,
    raw: map()
  }

  # ============================================================================
  # Public API
  # ============================================================================

  @doc """
  Load and parse a tsconfig.json file.

  Options:
  - `:resolve_extends` - Whether to resolve extends chain (default: true)
  """
  @spec load(String.t(), keyword()) :: {:ok, t()} | {:error, term()}
  def load(path, opts \\ []) do
    resolve_extends = Keyword.get(opts, :resolve_extends, true)

    with {:ok, abs_path} <- resolve_path(path),
         {:ok, content} <- File.read(abs_path),
         {:ok, json} <- parse_json(content) do
      config = build_config(abs_path, json)

      if resolve_extends and config.extends do
        resolve_extends_chain(config)
      else
        {:ok, config}
      end
    end
  end

  @doc """
  Get all TypeScript files for a tsconfig.

  Resolves include/exclude patterns relative to the tsconfig directory.
  """
  @spec get_files(t()) :: list(String.t())
  def get_files(%__MODULE__{} = config) do
    cond do
      # Explicit files list takes priority
      config.files && length(config.files) > 0 ->
        Enum.map(config.files, &Path.join(config.root_dir, &1))
        |> Enum.filter(&File.exists?/1)

      # Use include/exclude patterns
      true ->
        include = config.include || @default_include
        exclude = config.exclude || @default_exclude

        expand_patterns(config.root_dir, include, exclude)
    end
  end

  @doc """
  Get project references from a tsconfig.
  Returns a list of paths to referenced tsconfig.json files.
  """
  @spec get_references(t()) :: list(String.t())
  def get_references(%__MODULE__{} = config) do
    (config.references || [])
    |> Enum.map(fn ref ->
      ref_path = ref["path"] || ref[:path]
      resolve_reference_path(config.root_dir, ref_path)
    end)
    |> Enum.filter(&File.exists?/1)
  end

  @doc """
  Load a tsconfig and all its references recursively.
  Returns configs in topological order (dependencies first).
  """
  @spec load_with_references(String.t(), keyword()) :: {:ok, list(t())} | {:error, term()}
  def load_with_references(path, opts \\ []) do
    case load(path, opts) do
      {:ok, config} ->
        collect_references(config, [], MapSet.new())

      error ->
        error
    end
  end

  @doc """
  Get compiler options from a tsconfig, with inherited values resolved.
  """
  @spec get_compiler_options(t()) :: map()
  def get_compiler_options(%__MODULE__{} = config) do
    config.compiler_options || %{}
  end

  # ============================================================================
  # Private Helpers
  # ============================================================================

  defp resolve_path(path) do
    abs_path = Path.expand(path)

    cond do
      File.regular?(abs_path) ->
        {:ok, abs_path}

      File.dir?(abs_path) ->
        tsconfig_path = Path.join(abs_path, "tsconfig.json")
        if File.exists?(tsconfig_path) do
          {:ok, tsconfig_path}
        else
          {:error, {:not_found, "No tsconfig.json found in #{abs_path}"}}
        end

      true ->
        {:error, {:not_found, "Path does not exist: #{abs_path}"}}
    end
  end

  defp parse_json(content) do
    # Remove comments (tsconfig allows them)
    cleaned = remove_json_comments(content)

    case Jason.decode(cleaned) do
      {:ok, json} -> {:ok, json}
      {:error, reason} -> {:error, {:parse_error, reason}}
    end
  end

  defp remove_json_comments(content) do
    # Properly handle comments while preserving strings
    # This is a simplified approach - we process character by character
    remove_comments_preserving_strings(content, "", false, nil)
  end

  defp remove_comments_preserving_strings("", acc, _in_string, _), do: acc

  # Handle escape sequences in strings
  defp remove_comments_preserving_strings(<<"\\"::utf8, c::utf8, rest::binary>>, acc, true, quote) do
    remove_comments_preserving_strings(rest, acc <> "\\" <> <<c::utf8>>, true, quote)
  end

  # Handle string start/end
  defp remove_comments_preserving_strings(<<"\"", rest::binary>>, acc, false, nil) do
    remove_comments_preserving_strings(rest, acc <> "\"", true, "\"")
  end

  defp remove_comments_preserving_strings(<<"\"", rest::binary>>, acc, true, "\"") do
    remove_comments_preserving_strings(rest, acc <> "\"", false, nil)
  end

  # Handle single-line comments (only outside strings)
  defp remove_comments_preserving_strings(<<"//", rest::binary>>, acc, false, nil) do
    # Skip until newline
    rest = skip_to_newline(rest)
    remove_comments_preserving_strings(rest, acc, false, nil)
  end

  # Handle multi-line comments (only outside strings)
  defp remove_comments_preserving_strings(<<"/*", rest::binary>>, acc, false, nil) do
    # Skip until */
    rest = skip_to_end_of_comment(rest)
    remove_comments_preserving_strings(rest, acc, false, nil)
  end

  # Normal character
  defp remove_comments_preserving_strings(<<c::utf8, rest::binary>>, acc, in_string, quote) do
    remove_comments_preserving_strings(rest, acc <> <<c::utf8>>, in_string, quote)
  end

  defp skip_to_newline(""), do: ""
  defp skip_to_newline(<<"\n", rest::binary>>), do: "\n" <> rest
  defp skip_to_newline(<<_::utf8, rest::binary>>), do: skip_to_newline(rest)

  defp skip_to_end_of_comment(""), do: ""
  defp skip_to_end_of_comment(<<"*/", rest::binary>>), do: rest
  defp skip_to_end_of_comment(<<_::utf8, rest::binary>>), do: skip_to_end_of_comment(rest)

  defp build_config(path, json) do
    root_dir = Path.dirname(path)

    %__MODULE__{
      path: path,
      root_dir: root_dir,
      compiler_options: json["compilerOptions"] || %{},
      files: json["files"],
      include: json["include"],
      exclude: json["exclude"],
      references: json["references"],
      extends: json["extends"],
      raw: json
    }
  end

  defp resolve_extends_chain(config) do
    case resolve_extends_path(config.root_dir, config.extends) do
      {:ok, extends_path} ->
        case load(extends_path, resolve_extends: true) do
          {:ok, parent} ->
            merged = merge_configs(parent, config)
            {:ok, merged}

          {:error, reason} ->
            Logger.warning("Failed to load extended config #{extends_path}: #{inspect(reason)}")
            {:ok, config}
        end

      {:error, _} ->
        Logger.warning("Could not resolve extends path: #{config.extends}")
        {:ok, config}
    end
  end

  defp resolve_extends_path(root_dir, extends) do
    # Handle relative paths
    cond do
      String.starts_with?(extends, ".") ->
        path = Path.join(root_dir, extends)
        path = if String.ends_with?(path, ".json"), do: path, else: path <> ".json"
        {:ok, Path.expand(path)}

      # Node module style (e.g., "@tsconfig/node18")
      true ->
        # Try node_modules
        node_path = Path.join([root_dir, "node_modules", extends, "tsconfig.json"])
        if File.exists?(node_path) do
          {:ok, node_path}
        else
          {:error, :not_found}
        end
    end
  end

  defp merge_configs(parent, child) do
    %__MODULE__{
      path: child.path,
      root_dir: child.root_dir,
      compiler_options: Map.merge(parent.compiler_options || %{}, child.compiler_options || %{}),
      files: child.files || parent.files,
      include: child.include || parent.include,
      exclude: child.exclude || parent.exclude,
      references: child.references || parent.references,
      extends: nil,  # Already resolved
      raw: child.raw
    }
  end

  defp resolve_reference_path(root_dir, ref_path) do
    full_path = Path.join(root_dir, ref_path)

    cond do
      File.regular?(full_path) ->
        Path.expand(full_path)

      File.dir?(full_path) ->
        Path.expand(Path.join(full_path, "tsconfig.json"))

      String.ends_with?(ref_path, ".json") ->
        Path.expand(full_path)

      true ->
        Path.expand(Path.join(full_path, "tsconfig.json"))
    end
  end

  defp expand_patterns(root_dir, include, exclude) do
    # Convert tsconfig patterns to Elixir glob patterns
    include_files =
      include
      |> Enum.flat_map(fn pattern ->
        glob_pattern = tsconfig_to_glob(pattern)
        Path.wildcard(Path.join(root_dir, glob_pattern))
      end)
      |> Enum.filter(&typescript_file?/1)

    # Filter out excluded files
    exclude_patterns = Enum.map(exclude, &tsconfig_to_glob/1)

    include_files
    |> Enum.reject(fn file ->
      rel_path = Path.relative_to(file, root_dir)
      Enum.any?(exclude_patterns, fn pattern ->
        matches_exclude?(rel_path, pattern)
      end)
    end)
    |> Enum.sort()
  end

  defp tsconfig_to_glob(pattern) do
    # tsconfig uses slightly different glob syntax
    pattern
    |> String.replace("**/*", "**/*")  # Already correct
    |> then(fn p ->
      # If pattern doesn't have extension, add ts/tsx
      if String.contains?(p, ".") do
        p
      else
        if String.ends_with?(p, "**/*") do
          String.replace(p, "**/*", "**/*.{ts,tsx}")
        else
          p <> "/**/*.{ts,tsx}"
        end
      end
    end)
  end

  defp typescript_file?(path) do
    ext = Path.extname(path)
    ext in [".ts", ".tsx", ".mts", ".cts"]
  end

  defp matches_exclude?(rel_path, pattern) do
    # Simple exclude matching
    String.starts_with?(rel_path, pattern) or
    String.contains?(rel_path, "/" <> pattern <> "/") or
    String.contains?(rel_path, "/" <> pattern)
  end

  defp collect_references(config, acc, visited) do
    config_path = config.path

    if MapSet.member?(visited, config_path) do
      {:ok, acc}
    else
      visited = MapSet.put(visited, config_path)
      ref_paths = get_references(config)

      # Load all referenced configs
      result =
        Enum.reduce_while(ref_paths, {:ok, acc, visited}, fn ref_path, {:ok, acc, visited} ->
          case load(ref_path) do
            {:ok, ref_config} ->
              case collect_references(ref_config, acc, visited) do
                {:ok, new_acc} ->
                  {:cont, {:ok, new_acc, MapSet.put(visited, ref_path)}}

                error ->
                  {:halt, error}
              end

            {:error, reason} ->
              Logger.warning("Failed to load reference #{ref_path}: #{inspect(reason)}")
              {:cont, {:ok, acc, visited}}
          end
        end)

      case result do
        {:ok, acc, _visited} ->
          # Add current config after its dependencies
          {:ok, acc ++ [config]}

        error ->
          error
      end
    end
  end
end
