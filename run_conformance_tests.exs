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
# Ratchet modes (regression gate — see docs/CONFORMANCE_RUNNER.md "Ratchet"):
#   --update-ratchet    Run the full sweep (loose + strict computed from one
#                       compile per test) and (re)write conformance_ratchet.json.
#   --check-ratchet     Run the same sweep and compare against the committed
#                       conformance_ratchet.json. Exit 1 if any category's
#                       loose_pass or strict_pass count dropped or its crash
#                       count rose; exit 0 otherwise. Improvements are reported
#                       as "ratchet can be tightened".
#   --ratchet-file P    Use P instead of <repo root>/conformance_ratchet.json
#                       (mainly for testing the tooling; combine with --limit).
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
        strict: [
          strict: :boolean,
          all: :boolean,
          limit: :integer,
          verbose: :boolean,
          update_ratchet: :boolean,
          check_ratchet: :boolean,
          ratchet_file: :string
        ]
      )

    validate_environment()

    cond do
      opts[:update_ratchet] -> update_ratchet(opts)
      opts[:check_ratchet] -> check_ratchet(opts)
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
      ./run_conformance_tests.exs --check-ratchet    # regression gate
      ./run_conformance_tests.exs --update-ratchet   # after intentional improvements

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

  # -- ratchet (regression gate) --------------------------------------------------
  #
  # The ratchet file (conformance_ratchet.json at the repo root) records
  # per-category {total, loose_pass, strict_pass, crash} for the last blessed
  # sweep. --check-ratchet fails (exit 1) when any category's loose or strict
  # pass count drops, or its crash count rises, relative to that file.
  # --update-ratchet regenerates it after intentional improvements.

  @ratchet_metrics [:total, :loose_pass, :strict_pass, :crash]

  defp ratchet_path(opts) do
    opts[:ratchet_file] || Path.join(@script_dir, "conformance_ratchet.json")
  end

  # One sweep over every category, counting loose and strict passes from the
  # same compile of each test. Returns rows sorted by category name.
  defp ratchet_sweep(opts) do
    conformance_dir = Path.join(ts_repo(), "tests/cases/conformance")
    baselines = build_baseline_index()

    categories =
      conformance_dir
      |> File.ls!()
      |> Enum.filter(&File.dir?(Path.join(conformance_dir, &1)))
      |> Enum.sort()

    Enum.map(categories, fn cat ->
      results = run_category(cat, baselines, opts)

      row = %{
        category: cat,
        total: length(results),
        loose_pass: Enum.count(results, &(not &1.crashed and &1.passed_loose)),
        strict_pass: Enum.count(results, &(not &1.crashed and &1.passed_strict)),
        crash: Enum.count(results, & &1.crashed)
      }

      IO.puts(
        "#{cat}: total=#{row.total} loose=#{row.loose_pass} " <>
          "strict=#{row.strict_pass} crash=#{row.crash}"
      )

      row
    end)
  end

  defp ratchet_overall(rows) do
    Enum.reduce(rows, %{total: 0, loose_pass: 0, strict_pass: 0, crash: 0}, fn row, acc ->
      Map.new(@ratchet_metrics, fn k -> {k, acc[k] + row[k]} end)
    end)
  end

  defp git_sha(dir) do
    case System.cmd("git", ["-C", dir, "rev-parse", "HEAD"], stderr_to_stdout: true) do
      {sha, 0} -> String.trim(sha)
      _ -> "unknown"
    end
  rescue
    _ -> "unknown"
  end

  defp update_ratchet(opts) do
    path = ratchet_path(opts)
    IO.puts("\n=== Ratchet sweep (loose + strict from one compile per test) ===\n")
    rows = ratchet_sweep(opts)
    File.write!(path, ratchet_json(rows))

    overall = ratchet_overall(rows)

    IO.puts("\nWrote #{path}")

    IO.puts(
      "Overall: total=#{overall.total} loose_pass=#{overall.loose_pass} " <>
        "strict_pass=#{overall.strict_pass} crash=#{overall.crash}"
    )
  end

  defp check_ratchet(opts) do
    path = ratchet_path(opts)

    unless File.exists?(path) do
      IO.puts("Error: ratchet file not found: #{path}")
      IO.puts("Generate it with: ./run_conformance_tests.exs --update-ratchet")
      System.halt(1)
    end

    committed = JSON.decode!(File.read!(path))
    old_categories = committed["categories"] || %{}

    IO.puts("\n=== Ratchet check against #{path} ===")
    IO.puts("Committed sweep: sha=#{committed["git_sha"]} at #{committed["generated_at"]}\n")

    current_ts_sha = git_sha(ts_repo())

    if committed["ts_repo_sha"] not in [nil, "unknown", current_ts_sha] do
      IO.puts(
        "WARNING: TypeScript repo checkout (#{current_ts_sha}) differs from the one the\n" <>
          "ratchet was generated against (#{committed["ts_repo_sha"]}); baseline drift can\n" <>
          "produce false regressions/improvements.\n"
      )
    end

    rows = ratchet_sweep(opts)
    new_by_cat = Map.new(rows, &{&1.category, &1})

    {regressions, improvements, warnings} =
      Enum.reduce(rows, {[], [], []}, fn row, acc ->
        case old_categories[row.category] do
          nil ->
            {r, i, w} = acc
            {r, i, w ++ ["new category not in ratchet file: #{row.category}"]}

          old ->
            compare_category(row, old, acc)
        end
      end)

    warnings =
      warnings ++
        for {cat, _} <- old_categories, not Map.has_key?(new_by_cat, cat) do
          "category in ratchet file but not in this sweep: #{cat}"
        end

    overall = ratchet_overall(rows)

    IO.puts("")
    Enum.each(warnings, &IO.puts("WARNING: #{&1}"))
    Enum.each(improvements, &IO.puts("IMPROVED: #{&1}"))
    Enum.each(regressions, &IO.puts("REGRESSION: #{&1}"))

    IO.puts(
      "\nOverall: total=#{overall.total} loose_pass=#{overall.loose_pass} " <>
        "strict_pass=#{overall.strict_pass} crash=#{overall.crash}"
    )

    cond do
      regressions != [] ->
        IO.puts(
          "\nRESULT: FAIL — #{length(regressions)} ratchet regression(s). " <>
            "Fix the regression, or (only for an intentional trade-off explained in the\n" <>
            "commit message) re-bless with: ./run_conformance_tests.exs --update-ratchet"
        )

        System.halt(1)

      improvements != [] ->
        IO.puts(
          "\nRESULT: PASS — no regressions. #{length(improvements)} categor(y/ies) improved; " <>
            "the ratchet can be tightened with: ./run_conformance_tests.exs --update-ratchet"
        )

      true ->
        IO.puts("\nRESULT: PASS — all categories at or above the committed ratchet.")
    end
  end

  # Compares one category row against its committed counts, accumulating
  # {regressions, improvements, warnings}. Pass counts may only go up; crash
  # counts may only go down; a changed total means the TS repo checkout moved.
  defp compare_category(row, old, acc) do
    acc =
      if old["total"] != row.total do
        {r, i, w} = acc

        {r, i,
         w ++
           [
             "#{row.category}: total changed #{old["total"]} -> #{row.total} " <>
               "(TypeScript repo checkout differs from the one that generated the ratchet?)"
           ]}
      else
        acc
      end

    acc =
      Enum.reduce([:loose_pass, :strict_pass], acc, fn metric, {r, i, w} ->
        old_v = old[Atom.to_string(metric)] || 0
        new_v = row[metric]

        cond do
          new_v < old_v ->
            {r ++ ["#{row.category}: #{metric} dropped #{old_v} -> #{new_v} (#{new_v - old_v})"],
             i, w}

          new_v > old_v ->
            {r, i ++ ["#{row.category}: #{metric} #{old_v} -> #{new_v} (+#{new_v - old_v})"], w}

          true ->
            {r, i, w}
        end
      end)

    {r, i, w} = acc
    old_crash = old["crash"] || 0

    cond do
      row.crash > old_crash ->
        {r ++ ["#{row.category}: crash rose #{old_crash} -> #{row.crash}"], i, w}

      row.crash < old_crash ->
        {r, i ++ ["#{row.category}: crash #{old_crash} -> #{row.crash}"], w}

      true ->
        {r, i, w}
    end
  end

  # Hand-rolled encoder so the file is deterministic and diff-friendly:
  # fixed key order (schema/generated_at/git_sha/overall/categories; metrics
  # always total, loose_pass, strict_pass, crash), categories sorted, one
  # category per line, trailing newline.
  defp ratchet_json(rows) do
    overall = ratchet_overall(rows)

    generated_at =
      DateTime.utc_now() |> DateTime.truncate(:second) |> DateTime.to_iso8601()

    category_lines =
      Enum.map_join(rows, ",\n", fn row ->
        ~s(    "#{row.category}": #{metrics_json(row)})
      end)

    """
    {
      "schema": 1,
      "generated_at": "#{generated_at}",
      "git_sha": "#{git_sha(@script_dir)}",
      "ts_repo_sha": "#{git_sha(ts_repo())}",
      "overall": #{metrics_json(overall)},
      "categories": {
    #{category_lines}
      }
    }
    """
  end

  defp metrics_json(counts) do
    inner = Enum.map_join(@ratchet_metrics, ", ", fn k -> ~s("#{k}": #{counts[k]}) end)
    "{ #{inner} }"
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

    # Both modes are decidable from the same compile: they share the emitted
    # code set and differ only in the pass predicate. Computing both lets the
    # ratchet sweep cover loose AND strict in a single pass over the suite.
    passed_strict = MapSet.equal?(emitted_codes, expected_codes)

    passed_loose =
      (exit_code != 0 or MapSet.size(emitted_codes) > 0) == expects_errors

    passed = if strict, do: passed_strict, else: passed_loose

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
      crashed: crashed?,
      passed_loose: passed_loose,
      passed_strict: passed_strict,
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
    # The tsc harness resolves unit paths against @currentDirectory; mirror
    # that by resolving every unit name against it before placing the unit in
    # the temp dir (the temp dir plays the role of the filesystem root "/").
    current_dir = current_directory(directives)
    units = split_filename_units(content, current_dir)
    compilable = Enum.filter(units, fn {fname, _} -> compilable_unit?(fname) end)

    honored = if current_dir, do: ["filename", "currentdirectory"], else: ["filename"]

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
        {out, code, honored}
      after
        File.rm_rf(dir)
      end
    end
  end

  # Value of @currentDirectory normalized to forward slashes without a drive
  # letter or trailing slash; nil when the directive is absent.
  defp current_directory(directives) do
    case List.keyfind(directives, "currentdirectory", 0) do
      {_, value} ->
        value
        |> String.trim()
        |> String.replace("\\", "/")
        |> String.replace(~r/^[a-zA-Z]:/, "")
        |> String.trim_trailing("/")

      nil ->
        nil
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
  # Relative unit names are resolved against current_dir (from
  # @currentDirectory) when given, so units spelled "b.ts" and "/root/a.ts"
  # land in the same directory when currentDirectory is "/root".
  defp split_filename_units(content, current_dir \\ nil) do
    lines = String.split(content, ~r/\r?\n/)

    {units, last_name, last_lines, prefix} =
      Enum.reduce(lines, {[], nil, [], []}, fn line, {units, fname, acc, prefix} ->
        case Regex.run(@filename_directive, line) do
          [_, new_name] ->
            case resolve_unit_name(new_name, current_dir) do
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
      # Prefix global directive lines onto compilable units only: they are
      # comments the compiler may honor in TS files, but they would corrupt
      # JSON units (package.json) and other non-TS assets.
      ucontent =
        if prefix == [] or not compilable_unit?(fname),
          do: ucontent,
          else: Enum.join(prefix, "\n") <> "\n" <> ucontent

      {fname, ucontent}
    end)
    |> Enum.uniq_by(fn {fname, _} -> fname end)
  end

  defp finish_unit(units, nil, _lines), do: units

  defp finish_unit(units, fname, lines) do
    [{fname, lines |> Enum.reverse() |> Enum.join("\n")} | units]
  end

  # Resolve a unit name against @currentDirectory (harness semantics: unit
  # paths are relative to it; rooted paths stand alone), then sanitize.
  defp resolve_unit_name(raw, nil), do: sanitize_unit_name(raw)

  defp resolve_unit_name(raw, current_dir) do
    norm =
      raw
      |> String.trim()
      |> String.replace("\\", "/")
      |> String.replace(~r/^[a-zA-Z]:/, "")

    full = if String.starts_with?(norm, "/"), do: norm, else: current_dir <> "/" <> norm
    sanitize_unit_name(full)
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

  # Files the compiler CLI accepts as input (.ts/.tsx including .d.ts, plus
  # the node16 ESM/CJS variants .mts/.cts/.d.mts/.d.cts — the TypeScript
  # harness compiles those units too). Other units (package.json, .js, ...)
  # are still written to disk so module resolution can see them, but are not
  # passed for compilation.
  defp compilable_unit?(fname) do
    String.ends_with?(fname, ".ts") or String.ends_with?(fname, ".tsx") or
      String.ends_with?(fname, ".mts") or String.ends_with?(fname, ".cts")
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

  # Directives that never change the diagnostics we compare against, so they
  # must not demote a mismatch to "unhonored directives":
  #   * noImplicitReferences — harness-only option: it makes tsc compile only
  #     the last unit and pull the rest in via imports/references
  #     (compilerRunner.ts). tsc applies the same behavior implicitly whenever
  #     the last unit contains `require(` or a `/// <reference path`, so the
  #     directive itself is redundant for those tests; our runner always
  #     writes every unit to disk and compiles them together, which yields the
  #     same set of checked files for module-import tests.
  #   * traceResolution — only adds module-resolution trace output (baselined
  #     separately as .trace.json); it never changes the emitted error codes.
  @inert ~w(noimplicitreferences traceresolution)

  # Directives the compiler reads directly from the source text (via its inline
  # `// @directive:` parser) and self-applies during checking, so the runner
  # need not translate them into CLI flags — passing the file already honors
  # them. The strict family defaults ON in the compiler, matching how the
  # TypeScript conformance baselines are generated (see effective_strict_flags /
  # effective_no_implicit_any in checker.mbt).
  @honored_in_file ~w(strict strictnullchecks strictpropertyinitialization noimplicitany)

  defp parse_directives(content) do
    ~r/^\s*\/\/\s*@(\w+)\s*:\s*(.+?)\s*$/m
    |> Regex.scan(content)
    |> Enum.map(fn [_, key, value] -> {String.downcase(key), value} end)
  end

  defp unhonored_directives(directives) do
    directives
    |> Enum.map(&elem(&1, 0))
    |> Enum.uniq()
    |> Enum.reject(
      &(&1 in @honorable or &1 in @inert or &1 in @honored_in_file)
    )
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
