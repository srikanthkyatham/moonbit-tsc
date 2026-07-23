#!/usr/bin/env elixir

# TypeScript conformance test runner for the MoonBit TypeScript compiler.
#
# Usage:
#   ./run_conformance_tests.exs <category>            # loose mode, one category
#   ./run_conformance_tests.exs <category> --strict   # strict mode (compare TSxxxx code sets)
#   ./run_conformance_tests.exs --all                 # run every category, summary table
#   ./run_conformance_tests.exs --all --strict --limit 20
#
# Options:
#   --strict        Compare the SET of TSxxxx error codes emitted by the compiler
#                   against the set found in the baseline .errors.txt (not just
#                   "errors vs no errors").
#   --all           Run all categories under tests/cases/conformance and print a
#                   per-category summary table plus overall totals.
#   --limit N       Only run the first N tests (per category in --all mode).
#   --verbose       Print individual failures even in --all mode.
#
# Environment variables:
#   TSC_CLI   Path to the compiler CLI.
#             Default: <script dir>/src/moonbit/_build/native/debug/build/cli/cli.exe
#   TS_REPO   Path to a microsoft/TypeScript checkout.
#             Default: <script dir>/../typescript-repo

defmodule ConformanceTestRunner do
  @script_dir __DIR__
  @per_test_timeout_secs "30"

  # -- configuration -----------------------------------------------------------

  def cli_path do
    System.get_env("TSC_CLI") ||
      Path.join(@script_dir, "src/moonbit/_build/native/debug/build/cli/cli.exe")
  end

  def ts_repo do
    System.get_env("TS_REPO") || Path.expand(Path.join(@script_dir, "../typescript-repo"))
  end

  # -- entry point --------------------------------------------------------------

  def main(args) do
    {opts, rest, _} =
      OptionParser.parse(args,
        strict: [strict: :boolean, all: :boolean, limit: :integer, verbose: :boolean]
      )

    validate_environment()

    cond do
      opts[:all] -> run_all(opts)
      rest != [] -> run_single_category(hd(rest), opts)
      true -> usage()
    end
  end

  defp usage do
    IO.puts("""
    Usage: ./run_conformance_tests.exs <category> [--strict] [--limit N]
           ./run_conformance_tests.exs --all [--strict] [--limit N] [--verbose]

    Examples:
      ./run_conformance_tests.exs es6/computedProperties
      ./run_conformance_tests.exs es6/templates --strict
      ./run_conformance_tests.exs --all --limit 25

    Env vars: TSC_CLI (compiler path), TS_REPO (TypeScript repo checkout)
    """)

    System.halt(1)
  end

  defp validate_environment do
    unless File.exists?(cli_path()) do
      IO.puts("Error: compiler CLI not found: #{cli_path()}")
      IO.puts("Set TSC_CLI or build with: cd src/moonbit && moon build --target native")
      System.halt(1)
    end

    unless File.dir?(Path.join(ts_repo(), "tests/cases/conformance")) do
      IO.puts("Error: TypeScript repo not found (or missing tests/): #{ts_repo()}")
      IO.puts("Set TS_REPO or clone with:")
      IO.puts("  git clone --depth 1 https://github.com/microsoft/TypeScript #{ts_repo()}")
      System.halt(1)
    end
  end

  # -- modes --------------------------------------------------------------------

  defp run_single_category(category, opts) do
    baselines = build_baseline_index()
    results = run_category(category, baselines, opts)

    print_failures(results, opts[:strict])
    {pass, fail, dirfail, crash} = tally(results)
    total = length(results)

    IO.puts("\n=== Test Results (#{if opts[:strict], do: "strict", else: "loose"} mode) ===")
    IO.puts("Category: #{category}")
    IO.puts("Passed:   #{pass}/#{total} (#{rate(pass, total)}%)")
    IO.puts("Failed:   #{fail} (diagnostic mismatch)")
    IO.puts("Failed*:  #{dirfail} (mismatch on tests with unhonored directives, e.g. @filename)")
    IO.puts("Crashed:  #{crash} (compiler crash or timeout)")

    if pass == total and total > 0, do: IO.puts("\nAll tests passing!")
  end

  defp run_all(opts) do
    conformance_dir = Path.join(ts_repo(), "tests/cases/conformance")
    baselines = build_baseline_index()

    categories =
      conformance_dir
      |> File.ls!()
      |> Enum.filter(&File.dir?(Path.join(conformance_dir, &1)))
      |> Enum.sort()

    mode = if opts[:strict], do: "strict", else: "loose"
    IO.puts("\n=== Running ALL conformance categories (#{mode} mode) ===\n")

    rows =
      Enum.map(categories, fn cat ->
        results = run_category(cat, baselines, opts)
        if opts[:verbose], do: print_failures(results, opts[:strict])
        {pass, fail, dirfail, crash} = tally(results)
        {cat, length(results), pass, fail, dirfail, crash}
      end)

    print_summary_table(rows, mode)
  end

  # -- category execution -------------------------------------------------------

  defp run_category(category, baselines, opts) do
    test_dir = Path.join([ts_repo(), "tests/cases/conformance", category])

    unless File.dir?(test_dir) do
      IO.puts("Error: Test directory not found: #{test_dir}")
      System.halt(1)
    end

    files =
      Path.wildcard("#{test_dir}/**/*.ts")
      |> Enum.sort()
      |> maybe_limit(opts[:limit])

    files
    |> Task.async_stream(&run_test(&1, baselines, opts[:strict] || false),
      max_concurrency: max(System.schedulers_online(), 4),
      timeout: :infinity,
      ordered: true
    )
    |> Enum.map(fn {:ok, result} -> result end)
  end

  defp maybe_limit(list, nil), do: list
  defp maybe_limit(list, n), do: Enum.take(list, n)

  # -- single test --------------------------------------------------------------

  defp run_test(file, baselines, strict) do
    name = Path.basename(file, ".ts")
    content = File.read!(file)
    directives = parse_directives(content)

    {output, exit_code, honored_extra} =
      if multi_file_test?(directives) do
        run_multi_file_test(file, name, content, directives)
      else
        {out, code} = run_compiler([file], directives)
        {out, code, []}
      end

    unhonored = unhonored_directives(directives) -- honored_extra
    emitted_codes = extract_codes(output)

    crashed? = exit_code not in [0, 1] or crash_output?(output)

    {expected_codes, expects_errors, variant?} =
      expected_from_baselines(name, baselines, run_config(directives))

    passed =
      if strict do
        MapSet.equal?(emitted_codes, expected_codes)
      else
        has_errors = exit_code != 0 or MapSet.size(emitted_codes) > 0
        has_errors == expects_errors
      end

    status =
      cond do
        crashed? -> :crash
        passed -> :pass
        unhonored != [] -> :fail_directives
        true -> :fail
      end

    %{
      name: name,
      status: status,
      missing: MapSet.difference(expected_codes, emitted_codes) |> Enum.sort(),
      extra: MapSet.difference(emitted_codes, expected_codes) |> Enum.sort(),
      expects_errors: expects_errors,
      unhonored: unhonored,
      variant_baseline: variant?,
      exit_code: exit_code
    }
  end

  # A crash marker only counts when it appears outside a diagnostic line —
  # messages like "error TS7027: Unreachable code detected." must not trip it.
  defp crash_output?(output) do
    output
    |> String.split("\n")
    |> Enum.any?(fn line ->
      line =~ ~r/panic|Segmentation fault|abort trap/i and not (line =~ ~r/error TS\d+/)
    end)
  end

  defp run_compiler(files, directives) do
    extra_args =
      honored_flag(directives, "target", "--target") ++
        honored_flag(directives, "module", "--module") ++
        honored_flag(directives, "ignoredeprecations", "--ignoreDeprecations")

    args = files ++ ["--noEmit", "--reportDiagnostics" | extra_args]

    # Guard against compiler hangs with coreutils timeout when available.
    case System.find_executable("timeout") || System.find_executable("gtimeout") do
      nil -> safe_cmd(cli_path(), args)
      timeout_bin -> safe_cmd(timeout_bin, [@per_test_timeout_secs, cli_path() | args])
    end
  end

  # -- multi-file (@filename) tests ----------------------------------------------

  # A test with `// @filename:` directives contains several virtual files.
  # Mirror the TypeScript harness (makeUnitsFromTest): split the test into real
  # files in a per-test temp directory and compile them all together, so
  # relative imports between the units resolve against the real filesystem.
  # Returns {output, exit_code, honored_extra_directives}.
  defp run_multi_file_test(file, name, content, directives) do
    units = split_filename_units(content)
    compilable = Enum.filter(units, fn {fname, _} -> compilable_unit?(fname) end)

    if units == [] or compilable == [] do
      # Synthesis not possible; fall back to single-file compilation.
      {out, code} = run_compiler([file], directives)
      {out, code, []}
    else
      dir =
        Path.join(
          System.tmp_dir!(),
          "mbt_conf_#{name}_#{:erlang.unique_integer([:positive])}"
        )

      try do
        Enum.each(units, fn {fname, ucontent} ->
          path = Path.join(dir, fname)
          File.mkdir_p!(Path.dirname(path))
          File.write!(path, ucontent)
        end)

        compile_paths = Enum.map(compilable, fn {fname, _} -> Path.join(dir, fname) end)
        {out, code} = run_compiler(compile_paths, directives)
        {out, code, ["filename"]}
      after
        File.rm_rf(dir)
      end
    end
  end

  defp multi_file_test?(directives) do
    Enum.any?(directives, fn {key, _} -> key == "filename" end)
  end

  @filename_directive ~r/^\s*\/\/\s*@filename\s*:\s*(.+?)\s*$/i

  # Split test content into {relative_name, content} units, one per @filename
  # marker. Directive lines that appear before the first marker are global
  # options; keep them by prepending to every unit (the compiler honors a few
  # inline directives, and they are inert comments otherwise). Non-directive
  # content before the first marker is comments only per harness rules — drop it.
  defp split_filename_units(content) do
    lines = String.split(content, ~r/\r?\n/)

    {units, last_name, last_lines, prefix} =
      Enum.reduce(lines, {[], nil, [], []}, fn line, {units, fname, acc, prefix} ->
        case Regex.run(@filename_directive, line) do
          [_, new_name] ->
            case sanitize_unit_name(new_name) do
              nil -> {units, fname, acc, prefix}
              clean -> {finish_unit(units, fname, acc), clean, [], prefix}
            end

          nil ->
            if fname == nil do
              # Before the first @filename marker: keep global directive lines.
              if Regex.match?(~r/^\s*\/\/\s*@\w+\s*:/, line) do
                {units, fname, acc, prefix ++ [line]}
              else
                {units, fname, acc, prefix}
              end
            else
              {units, fname, [line | acc], prefix}
            end
        end
      end)

    units = finish_unit(units, last_name, last_lines)

    units
    |> Enum.reverse()
    |> Enum.map(fn {fname, ucontent} ->
      ucontent = if prefix == [], do: ucontent, else: Enum.join(prefix, "\n") <> "\n" <> ucontent
      {fname, ucontent}
    end)
    |> Enum.uniq_by(fn {fname, _} -> fname end)
  end

  defp finish_unit(units, nil, _lines), do: units

  defp finish_unit(units, fname, lines) do
    [{fname, lines |> Enum.reverse() |> Enum.join("\n")} | units]
  end

  # Normalize a @filename value to a safe path relative to the temp dir:
  # forward slashes, no drive letter, no leading /, no escaping via "..".
  defp sanitize_unit_name(raw) do
    parts =
      raw
      |> String.trim()
      |> String.replace("\\", "/")
      |> String.replace(~r/^[a-zA-Z]:/, "")
      |> String.split("/")
      |> Enum.reduce([], fn
        "", acc -> acc
        ".", acc -> acc
        "..", [] -> []
        "..", [_ | rest] -> rest
        part, acc -> [part | acc]
      end)
      |> Enum.reverse()

    case parts do
      [] -> nil
      _ -> Path.join(parts)
    end
  end

  # Files the compiler CLI accepts as input (.ts/.tsx, including .d.ts).
  # Other units (package.json, .js, ...) are still written to disk so module
  # resolution can see them, but are not passed for compilation.
  defp compilable_unit?(fname) do
    String.ends_with?(fname, ".ts") or String.ends_with?(fname, ".tsx")
  end

  defp safe_cmd(bin, args) do
    System.cmd(bin, args, stderr_to_stdout: true)
  rescue
    e -> {"runner exception: #{Exception.message(e)}", 127}
  end

  # -- directives ---------------------------------------------------------------

  # Directives the runner can translate into CLI flags. A comma-separated value
  # (e.g. "@target: es5, es6") means the harness runs multiple variants; we run
  # only the first listed value.
  @honorable ~w(target module ignoredeprecations)

  defp parse_directives(content) do
    ~r/^\s*\/\/\s*@(\w+)\s*:\s*(.+?)\s*$/m
    |> Regex.scan(content)
    |> Enum.map(fn [_, key, value] -> {String.downcase(key), value} end)
  end

  defp unhonored_directives(directives) do
    directives
    |> Enum.map(&elem(&1, 0))
    |> Enum.uniq()
    |> Enum.reject(&(&1 in @honorable))
  end

  defp honored_flag(directives, key, flag) do
    case List.keyfind(directives, key, 0) do
      {^key, value} ->
        first = value |> String.split(",") |> hd() |> String.trim() |> String.downcase()
        [flag, first]

      nil ->
        []
    end
  end

  # -- baselines ----------------------------------------------------------------

  # Index tests/baselines/reference once. Two lookups per test name:
  #   * exact:   "<name>.errors.txt"
  #   * variant: "<name>(target=es5).errors.txt" etc. (multi-variant tests)
  defp build_baseline_index do
    dir = Path.join(ts_repo(), "tests/baselines/reference")

    error_files =
      dir
      |> File.ls!()
      |> Enum.filter(&String.ends_with?(&1, ".errors.txt"))

    exact = MapSet.new(error_files)

    variants =
      Enum.reduce(error_files, %{}, fn fname, acc ->
        case Regex.run(~r/^(.+?)\([^)]*\)\.errors\.txt$/, fname) do
          [_, base] -> Map.update(acc, base, [fname], &[fname | &1])
          nil -> acc
        end
      end)

    %{dir: dir, exact: exact, variants: variants}
  end

  # The configuration this runner actually compiles with, normalized to the
  # spelling used inside variant baseline filenames ("es6" -> "es2015", ...).
  defp run_config(directives) do
    %{
      "target" => normalized_directive(directives, "target"),
      "module" => normalized_directive(directives, "module")
    }
  end

  defp normalized_directive(directives, key) do
    case List.keyfind(directives, key, 0) do
      {^key, value} ->
        value
        |> String.split(",")
        |> hd()
        |> String.trim()
        |> String.downcase()
        |> normalize_option_value()

      nil ->
        nil
    end
  end

  defp normalize_option_value("es6"), do: "es2015"
  defp normalize_option_value("es7"), do: "es2016"
  defp normalize_option_value(v), do: v

  # Returns {expected_code_set, expects_errors?, used_variant_baselines?}.
  #
  # Variant handling: multi-variant tests ("@target: es5, es2015") produce
  # baselines like "<name>(target=es5).errors.txt". The runner compiles ONE
  # configuration (the first directive value), so strict mode compares against
  # the variant whose options match that configuration:
  #   * matching variant baseline exists  -> its codes, expects errors
  #   * no variant matches our config     -> our config produced no errors
  #   * variants keyed on options we don't honor -> fall back to the UNION of
  #     all variants (conservative; never rejects a code tsc would emit)
  defp expected_from_baselines(name, %{dir: dir, exact: exact, variants: variants}, config) do
    exact_file = "#{name}.errors.txt"

    cond do
      MapSet.member?(exact, exact_file) ->
        codes = dir |> Path.join(exact_file) |> File.read!() |> extract_codes()
        {codes, true, false}

      Map.has_key?(variants, name) ->
        expected_from_variants(dir, variants[name], config)

      true ->
        {MapSet.new(), false, false}
    end
  end

  defp expected_from_variants(dir, files, config) do
    parsed = Enum.map(files, fn f -> {f, parse_variant_options(f)} end)

    decidable? =
      Enum.all?(parsed, fn {_, opts} ->
        Enum.all?(opts, fn {k, _} -> Map.get(config, k) != nil end)
      end)

    cond do
      decidable? ->
        case Enum.find(parsed, fn {_, opts} ->
               Enum.all?(opts, fn {k, v} -> config[k] == v end)
             end) do
          {file, _} ->
            codes = dir |> Path.join(file) |> File.read!() |> extract_codes()
            {codes, true, true}

          nil ->
            # tsc produced no .errors.txt for the configuration we run
            {MapSet.new(), false, true}
        end

      true ->
        codes =
          files
          |> Enum.map(&(dir |> Path.join(&1) |> File.read!() |> extract_codes()))
          |> Enum.reduce(MapSet.new(), &MapSet.union/2)

        {codes, true, true}
    end
  end

  # "name(target=es5,module=amd).errors.txt" -> %{"target" => "es5", "module" => "amd"}
  defp parse_variant_options(fname) do
    case Regex.run(~r/\(([^)]*)\)\.errors\.txt$/, fname) do
      [_, opts] ->
        opts
        |> String.split(",")
        |> Enum.map(&String.split(&1, "=", parts: 2))
        |> Enum.filter(&match?([_, _], &1))
        |> Map.new(fn [k, v] ->
          {String.downcase(String.trim(k)), normalize_option_value(String.downcase(String.trim(v)))}
        end)

      nil ->
        %{}
    end
  end

  # Matches both compiler output ("error TS2322: ...") and baseline lines
  # ("file.ts(1,5): error TS2322: ..." / "!!! error TS2322: ...").
  defp extract_codes(text) do
    ~r/error (TS\d+)/
    |> Regex.scan(text)
    |> Enum.map(fn [_, code] -> code end)
    |> MapSet.new()
  end

  # -- reporting ----------------------------------------------------------------

  defp tally(results) do
    {
      Enum.count(results, &(&1.status == :pass)),
      Enum.count(results, &(&1.status == :fail)),
      Enum.count(results, &(&1.status == :fail_directives)),
      Enum.count(results, &(&1.status == :crash))
    }
  end

  defp rate(_pass, 0), do: 0.0
  defp rate(pass, total), do: Float.round(pass / total * 100, 1)

  defp print_failures(results, strict) do
    Enum.each(results, fn r ->
      case r.status do
        :pass ->
          :ok

        :crash ->
          IO.puts("CRASH: #{r.name} (exit code #{r.exit_code})")

        status when status in [:fail, :fail_directives] ->
          tag = if status == :fail_directives, do: " [unhonored: #{Enum.join(r.unhonored, ",")}]", else: ""
          variant = if r.variant_baseline, do: " [variant baseline]", else: ""

          if strict do
            IO.puts(
              "FAIL: #{r.name}#{tag}#{variant} " <>
                "missing=#{format_codes(r.missing)} extra=#{format_codes(r.extra)}"
            )
          else
            reason =
              if r.expects_errors,
                do: "expected errors, got none",
                else: "expected no errors, got errors"

            IO.puts("FAIL: #{r.name}#{tag}#{variant} (#{reason})")
          end
      end
    end)
  end

  defp format_codes([]), do: "[]"
  defp format_codes(codes), do: "[" <> Enum.join(codes, ",") <> "]"

  defp print_summary_table(rows, mode) do
    header = {"Category", "Total", "Pass", "Fail", "DirFail", "Crash", "Rate"}
    widths = column_widths([header | Enum.map(rows, &row_strings/1)])

    IO.puts("\n=== Per-category summary (#{mode} mode) ===\n")
    IO.puts(format_row(Tuple.to_list(header), widths))
    IO.puts(Enum.map_join(widths, "-+-", &String.duplicate("-", &1)))

    Enum.each(rows, fn row ->
      IO.puts(format_row(Tuple.to_list(row_strings(row)), widths))
    end)

    {t, p, f, d, c} =
      Enum.reduce(rows, {0, 0, 0, 0, 0}, fn {_, total, pass, fail, dirfail, crash},
                                            {t, p, f, d, cr} ->
        {t + total, p + pass, f + fail, d + dirfail, cr + crash}
      end)

    IO.puts("")
    IO.puts("Overall: #{p}/#{t} passed (#{rate(p, t)}%)  " <>
              "fail=#{f} dirfail=#{d} crash=#{c}")
  end

  defp row_strings({cat, total, pass, fail, dirfail, crash}) do
    {cat, "#{total}", "#{pass}", "#{fail}", "#{dirfail}", "#{crash}",
     "#{rate(pass, total)}%"}
  end

  defp column_widths(rows) do
    rows
    |> Enum.map(&Tuple.to_list/1)
    |> Enum.zip()
    |> Enum.map(fn col -> col |> Tuple.to_list() |> Enum.map(&String.length/1) |> Enum.max() end)
  end

  defp format_row(cells, widths) do
    cells
    |> Enum.zip(widths)
    |> Enum.map_join(" | ", fn {cell, w} -> String.pad_trailing(cell, w) end)
  end
end

ConformanceTestRunner.main(System.argv())
