defmodule TSC.OptionsTest do
  use ExUnit.Case, async: true

  alias TSC.Options

  describe "validate_check_project/1" do
    test "accepts valid options with defaults" do
      assert {:ok, opts} = Options.validate_check_project([])

      assert Keyword.fetch!(opts, :incremental) == true
      assert Keyword.fetch!(opts, :concurrency) == 4
      assert Keyword.fetch!(opts, :verbose) == false
      assert Keyword.fetch!(opts, :report_diagnostics) == true
      assert Keyword.fetch!(opts, :target) == "es2015"
      assert Keyword.fetch!(opts, :out_dir) == nil
      assert Keyword.fetch!(opts, :source_map) == false
      assert Keyword.fetch!(opts, :declaration) == false
    end

    test "accepts valid custom options" do
      opts = [
        incremental: false,
        concurrency: 8,
        verbose: true,
        target: "es2020",
        out_dir: "/tmp/dist"
      ]

      assert {:ok, validated} = Options.validate_check_project(opts)

      assert Keyword.fetch!(validated, :incremental) == false
      assert Keyword.fetch!(validated, :concurrency) == 8
      assert Keyword.fetch!(validated, :verbose) == true
      assert Keyword.fetch!(validated, :target) == "es2020"
      assert Keyword.fetch!(validated, :out_dir) == "/tmp/dist"
    end

    test "rejects invalid concurrency type" do
      assert {:error, %NimbleOptions.ValidationError{} = error} =
               Options.validate_check_project(concurrency: "four")

      assert Exception.message(error) =~ "concurrency"
    end

    test "rejects invalid concurrency value (zero)" do
      assert {:error, %NimbleOptions.ValidationError{}} =
               Options.validate_check_project(concurrency: 0)
    end

    test "rejects invalid concurrency value (negative)" do
      assert {:error, %NimbleOptions.ValidationError{}} =
               Options.validate_check_project(concurrency: -1)
    end

    test "rejects invalid target value" do
      assert {:error, %NimbleOptions.ValidationError{} = error} =
               Options.validate_check_project(target: "es2099")

      assert Exception.message(error) =~ "target"
    end

    test "accepts all valid target values" do
      targets = ~w(es5 es2015 es2016 es2017 es2018 es2019 es2020 esnext)

      for target <- targets do
        assert {:ok, _} = Options.validate_check_project(target: target)
      end
    end

    test "rejects unknown options" do
      assert {:error, %NimbleOptions.ValidationError{} = error} =
               Options.validate_check_project(unknown_option: true)

      assert Exception.message(error) =~ "unknown_option"
    end
  end

  describe "validate_check_project!/1" do
    test "returns validated options for valid input" do
      opts = Options.validate_check_project!([])
      assert Keyword.fetch!(opts, :incremental) == true
    end

    test "raises for invalid input" do
      assert_raise NimbleOptions.ValidationError, fn ->
        Options.validate_check_project!(concurrency: -1)
      end
    end
  end

  describe "validate_check_file/1" do
    test "accepts valid options with defaults" do
      assert {:ok, opts} = Options.validate_check_file([])

      assert Keyword.fetch!(opts, :content) == nil
      assert Keyword.fetch!(opts, :imported_types) == %{}
      assert Keyword.fetch!(opts, :verbose) == false
    end

    test "accepts custom content and imported_types" do
      opts = [
        content: "const x: number = 1;",
        imported_types: %{"./utils" => %{add: "function"}},
        verbose: true
      ]

      assert {:ok, validated} = Options.validate_check_file(opts)

      assert Keyword.fetch!(validated, :content) == "const x: number = 1;"
      assert Keyword.fetch!(validated, :imported_types) == %{"./utils" => %{add: "function"}}
      assert Keyword.fetch!(validated, :verbose) == true
    end

    test "rejects invalid imported_types type" do
      assert {:error, %NimbleOptions.ValidationError{}} =
               Options.validate_check_file(imported_types: "not a map")
    end
  end

  describe "validate_cli_worker/1" do
    test "accepts valid options with defaults" do
      assert {:ok, opts} = Options.validate_cli_worker([])

      assert Keyword.fetch!(opts, :worker_id) == 1
      assert Keyword.fetch!(opts, :binary_path) == nil
      assert Keyword.fetch!(opts, :timeout) == 60_000
    end

    test "accepts custom worker options" do
      opts = [
        worker_id: 5,
        binary_path: "/usr/local/bin/moonbit",
        timeout: 120_000
      ]

      assert {:ok, validated} = Options.validate_cli_worker(opts)

      assert Keyword.fetch!(validated, :worker_id) == 5
      assert Keyword.fetch!(validated, :binary_path) == "/usr/local/bin/moonbit"
      assert Keyword.fetch!(validated, :timeout) == 120_000
    end

    test "rejects invalid worker_id (zero)" do
      assert {:error, %NimbleOptions.ValidationError{}} =
               Options.validate_cli_worker(worker_id: 0)
    end

    test "rejects invalid timeout (zero)" do
      assert {:error, %NimbleOptions.ValidationError{}} =
               Options.validate_cli_worker(timeout: 0)
    end
  end

  describe "validate_pool_supervisor/1" do
    test "accepts valid options with defaults" do
      assert {:ok, opts} = Options.validate_pool_supervisor([])

      assert Keyword.fetch!(opts, :pool_size) == 4
      assert Keyword.fetch!(opts, :binary_path) == nil
    end

    test "accepts custom pool size" do
      assert {:ok, opts} = Options.validate_pool_supervisor(pool_size: 8)
      assert Keyword.fetch!(opts, :pool_size) == 8
    end

    test "rejects invalid pool_size (zero)" do
      assert {:error, %NimbleOptions.ValidationError{}} =
               Options.validate_pool_supervisor(pool_size: 0)
    end
  end

  describe "validate_file_watcher/1" do
    test "accepts valid options with defaults" do
      assert {:ok, opts} = Options.validate_file_watcher([])

      assert Keyword.fetch!(opts, :dirs) == []
      assert Keyword.fetch!(opts, :debounce_ms) == 100
      assert Keyword.fetch!(opts, :extensions) == [".ts", ".tsx"]
    end

    test "accepts custom directories and debounce" do
      opts = [
        dirs: ["./src", "./lib"],
        debounce_ms: 200,
        extensions: [".ts", ".tsx", ".js"]
      ]

      assert {:ok, validated} = Options.validate_file_watcher(opts)

      assert Keyword.fetch!(validated, :dirs) == ["./src", "./lib"]
      assert Keyword.fetch!(validated, :debounce_ms) == 200
      assert Keyword.fetch!(validated, :extensions) == [".ts", ".tsx", ".js"]
    end

    test "rejects invalid debounce_ms (zero)" do
      assert {:error, %NimbleOptions.ValidationError{}} =
               Options.validate_file_watcher(debounce_ms: 0)
    end

    test "rejects invalid dirs type" do
      assert {:error, %NimbleOptions.ValidationError{}} =
               Options.validate_file_watcher(dirs: "./src")
    end
  end

  describe "validate_api_check/1" do
    test "accepts valid options with defaults" do
      assert {:ok, opts} = Options.validate_api_check([])

      assert Keyword.fetch!(opts, :files) == []
      assert Keyword.fetch!(opts, :project) == nil
      assert Keyword.fetch!(opts, :tsconfig) == nil
      assert Keyword.fetch!(opts, :incremental) == true
      assert Keyword.fetch!(opts, :concurrency) == 4
    end

    test "accepts files list" do
      files = ["src/index.ts", "src/utils.ts"]
      assert {:ok, opts} = Options.validate_api_check(files: files)
      assert Keyword.fetch!(opts, :files) == files
    end

    test "accepts project path" do
      assert {:ok, opts} = Options.validate_api_check(project: "./my-project")
      assert Keyword.fetch!(opts, :project) == "./my-project"
    end

    test "accepts tsconfig path" do
      assert {:ok, opts} = Options.validate_api_check(tsconfig: "./tsconfig.json")
      assert Keyword.fetch!(opts, :tsconfig) == "./tsconfig.json"
    end

    test "rejects invalid files type" do
      assert {:error, %NimbleOptions.ValidationError{}} =
               Options.validate_api_check(files: "not a list")
    end

    test "rejects invalid concurrency" do
      assert {:error, %NimbleOptions.ValidationError{}} =
               Options.validate_api_check(concurrency: 0)
    end
  end

  describe "from_map/2" do
    test "converts map to keyword list for check_project" do
      map = %{
        "incremental" => false,
        "concurrency" => 8,
        "verbose" => true
      }

      opts = Options.from_map(map, :check_project)

      assert opts[:incremental] == false
      assert opts[:concurrency] == 8
      assert opts[:verbose] == true
    end

    test "filters out unknown keys" do
      map = %{
        "incremental" => true,
        "unknown_key" => "should be filtered"
      }

      opts = Options.from_map(map, :check_project)

      assert opts[:incremental] == true
      refute Keyword.has_key?(opts, :unknown_key)
    end

    test "works with check_file schema" do
      map = %{
        "content" => "const x = 1;",
        "verbose" => true
      }

      opts = Options.from_map(map, :check_file)

      assert opts[:content] == "const x = 1;"
      assert opts[:verbose] == true
    end

    test "works with api_check schema" do
      map = %{
        "files" => ["a.ts", "b.ts"],
        "project" => "./src",
        "incremental" => false
      }

      opts = Options.from_map(map, :api_check)

      assert opts[:files] == ["a.ts", "b.ts"]
      assert opts[:project] == "./src"
      assert opts[:incremental] == false
    end

    test "returns empty list for empty map" do
      assert Options.from_map(%{}, :check_project) == []
    end

    test "returns empty list for unknown schema type" do
      map = %{"key" => "value"}
      assert Options.from_map(map, :unknown_schema) == []
    end
  end

  describe "schema accessors" do
    test "check_project_schema returns NimbleOptions schema" do
      schema = Options.check_project_schema()
      assert %NimbleOptions{} = schema
    end

    test "check_file_schema returns NimbleOptions schema" do
      schema = Options.check_file_schema()
      assert %NimbleOptions{} = schema
    end

    test "cli_worker_schema returns NimbleOptions schema" do
      schema = Options.cli_worker_schema()
      assert %NimbleOptions{} = schema
    end

    test "pool_supervisor_schema returns NimbleOptions schema" do
      schema = Options.pool_supervisor_schema()
      assert %NimbleOptions{} = schema
    end

    test "file_watcher_schema returns NimbleOptions schema" do
      schema = Options.file_watcher_schema()
      assert %NimbleOptions{} = schema
    end

    test "api_check_schema returns NimbleOptions schema" do
      schema = Options.api_check_schema()
      assert %NimbleOptions{} = schema
    end
  end
end
