defmodule TSC.Worker.CLIWorkerExtTypesTest do
  @moduledoc """
  Tests the CLI worker's external-types transport and failure handling using
  stub binaries, so no MoonBit build is required.
  """
  use ExUnit.Case, async: false

  alias TSC.Cache.TypeCache
  alias TSC.Graph.DependencyGraph
  alias TSC.Worker.CLIWorker

  @stub_dir Path.expand("../../../tmp/cli_worker_stubs", __DIR__)

  # Stub that records its argv, copies any --external-types-file payload,
  # then prints a minimal valid JSON response.
  @json_stub """
  #!/bin/sh
  printf '%s\\n' "$@" > "$ARGDUMP"
  prev=""
  for a in "$@"; do
    if [ "$prev" = "--external-types-file" ]; then
      cp "$a" "$ARGDUMP.payload"
    fi
    prev="$a"
  done
  echo '{"success":true,"stats":{"total_errors":0,"total_warnings":0},"files":[]}'
  """

  # Stub that produces no output at all (models an exec/crash failure).
  @silent_stub """
  #!/bin/sh
  exit 0
  """

  setup do
    File.rm_rf!(@stub_dir)
    File.mkdir_p!(@stub_dir)

    DependencyGraph.init()
    DependencyGraph.clear()
    TypeCache.clear()
    TypeCache.clear_mappings()

    on_exit(fn ->
      File.rm_rf!(@stub_dir)
      DependencyGraph.clear()
      TypeCache.clear()
      TypeCache.clear_mappings()
    end)

    :ok
  end

  defp write_stub(name, contents) do
    path = Path.join(@stub_dir, name)
    File.write!(path, contents)
    File.chmod!(path, 0o755)
    path
  end

  defp start_worker(worker_id, stub_path, argdump) do
    # ARGDUMP tells the stub where to record what it was invoked with
    System.put_env("ARGDUMP", argdump)
    on_exit(fn -> System.delete_env("ARGDUMP") end)

    start_supervised!(
      {CLIWorker, worker_id: worker_id, binary_path: stub_path},
      id: {:cli_worker_test, worker_id}
    )
  end

  defp read_argdump(argdump) do
    argdump |> File.read!() |> String.split("\n", trim: true)
  end

  test "empty CLI output is reported as an error, not silent success" do
    stub = write_stub("silent.sh", @silent_stub)
    start_worker(901, stub, Path.join(@stub_dir, "unused_argdump"))

    assert {:error, :empty_output} = CLIWorker.check_files(901, ["/a.ts"], %{})
  end

  test "external types are passed via temp file scoped to the batch's dependencies" do
    argdump = Path.join(@stub_dir, "argdump")
    stub = write_stub("json.sh", @json_stub)
    start_worker(902, stub, argdump)

    DependencyGraph.add("/a.ts", ["/b.ts"])
    DependencyGraph.add("/b.ts", [])
    TypeCache.put("/b.ts", %{"exports" => %{"B" => "interface"}})
    TypeCache.put("/unrelated.ts", %{"exports" => %{"C" => "interface"}})

    assert {:ok, _} = CLIWorker.check_files(902, ["/a.ts"], %{use_cached_types: true})

    args = read_argdump(argdump)
    assert "--external-types-file" in args
    refute Enum.any?(args, &String.starts_with?(&1, "{"))

    # The payload contains only the dependency, not every cached module
    payload = Jason.decode!(File.read!(argdump <> ".payload"))
    assert Map.keys(payload["modules"]) == ["/b.ts"]

    # The temp file is cleaned up after the CLI exits
    idx = Enum.find_index(args, &(&1 == "--external-types-file"))
    tmp_path = Enum.at(args, idx + 1)
    refute File.exists?(tmp_path)
  end

  test "no external-types argument when the batch has no dependencies in a built graph" do
    argdump = Path.join(@stub_dir, "argdump_nodeps")
    stub = write_stub("json.sh", @json_stub)
    start_worker(903, stub, argdump)

    # Graph is built and knows the file, but it imports nothing
    DependencyGraph.add("/a.ts", [])
    TypeCache.put("/unrelated.ts", %{"exports" => %{"C" => "interface"}})

    assert {:ok, _} = CLIWorker.check_files(903, ["/a.ts"], %{use_cached_types: true})

    args = read_argdump(argdump)
    refute "--external-types-file" in args
    refute "--external-types" in args
  end

  test "falls back to all cached modules when the dependency graph is empty" do
    argdump = Path.join(@stub_dir, "argdump_fallback")
    stub = write_stub("json.sh", @json_stub)
    start_worker(904, stub, argdump)

    # No dependency graph at all (legacy path), but cached types exist
    TypeCache.put("/other.ts", %{"exports" => %{"O" => "interface"}})

    assert {:ok, _} = CLIWorker.check_files(904, ["/a.ts"], %{use_cached_types: true})

    args = read_argdump(argdump)
    assert "--external-types-file" in args

    payload = Jason.decode!(File.read!(argdump <> ".payload"))
    assert Map.keys(payload["modules"]) == ["/other.ts"]
  end
end
