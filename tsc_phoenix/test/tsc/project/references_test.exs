defmodule TSC.Project.ReferencesTest do
  use ExUnit.Case, async: true

  alias TSC.Project.References

  @test_fixtures_dir Path.expand("../../fixtures/project_refs", __DIR__)

  setup_all do
    # Create test fixtures directory structure
    File.mkdir_p!(Path.join(@test_fixtures_dir, "packages/core/src"))
    File.mkdir_p!(Path.join(@test_fixtures_dir, "packages/utils/src"))
    File.mkdir_p!(Path.join(@test_fixtures_dir, "app/src"))

    # Create core package tsconfig
    core_tsconfig = %{
      "compilerOptions" => %{
        "composite" => true,
        "declaration" => true,
        "outDir" => "./dist",
        "rootDir" => "./src"
      },
      "include" => ["src/**/*.ts"]
    }

    File.write!(
      Path.join(@test_fixtures_dir, "packages/core/tsconfig.json"),
      Jason.encode!(core_tsconfig)
    )

    # Create core source file
    File.write!(
      Path.join(@test_fixtures_dir, "packages/core/src/index.ts"),
      "export const version = '1.0.0';"
    )

    # Create utils package tsconfig (depends on core)
    utils_tsconfig = %{
      "compilerOptions" => %{
        "composite" => true,
        "declaration" => true,
        "outDir" => "./dist",
        "rootDir" => "./src"
      },
      "include" => ["src/**/*.ts"],
      "references" => [
        %{"path" => "../core"}
      ]
    }

    File.write!(
      Path.join(@test_fixtures_dir, "packages/utils/tsconfig.json"),
      Jason.encode!(utils_tsconfig)
    )

    # Create utils source file
    File.write!(
      Path.join(@test_fixtures_dir, "packages/utils/src/helpers.ts"),
      "export function helper() { return 'help'; }"
    )

    # Create app tsconfig (depends on core and utils)
    app_tsconfig = %{
      "compilerOptions" => %{
        "outDir" => "./dist",
        "rootDir" => "./src"
      },
      "include" => ["src/**/*.ts"],
      "references" => [
        %{"path" => "../packages/core"},
        %{"path" => "../packages/utils"}
      ]
    }

    File.write!(
      Path.join(@test_fixtures_dir, "app/tsconfig.json"),
      Jason.encode!(app_tsconfig)
    )

    # Create app source file
    File.write!(
      Path.join(@test_fixtures_dir, "app/src/main.ts"),
      "import { version } from '@core'; console.log(version);"
    )

    on_exit(fn ->
      File.rm_rf!(@test_fixtures_dir)
    end)

    :ok
  end

  describe "parse_references/1" do
    test "parses references from tsconfig" do
      tsconfig_path = Path.join(@test_fixtures_dir, "app/tsconfig.json")

      {:ok, refs} = References.parse_references(tsconfig_path)

      assert length(refs) == 2
      assert Enum.any?(refs, fn r -> String.contains?(r.path, "core") end)
      assert Enum.any?(refs, fn r -> String.contains?(r.path, "utils") end)
    end

    test "returns empty list when no references" do
      tsconfig_path = Path.join(@test_fixtures_dir, "packages/core/tsconfig.json")

      {:ok, refs} = References.parse_references(tsconfig_path)

      assert refs == []
    end

    test "returns error for non-existent file" do
      {:error, _} = References.parse_references("/nonexistent/tsconfig.json")
    end
  end

  describe "load_project/1" do
    test "loads project with composite flag" do
      tsconfig_path = Path.join(@test_fixtures_dir, "packages/core/tsconfig.json")

      {:ok, info} = References.load_project(tsconfig_path)

      assert info.is_composite == true
      assert String.contains?(info.path, "core")
      assert info.references == []
    end

    test "loads project with references" do
      tsconfig_path = Path.join(@test_fixtures_dir, "packages/utils/tsconfig.json")

      {:ok, info} = References.load_project(tsconfig_path)

      assert length(info.references) == 1
      assert Enum.any?(info.references, fn r -> String.contains?(r.path, "core") end)
    end
  end

  describe "build_project_graph/1" do
    test "builds graph of all projects" do
      tsconfig_path = Path.join(@test_fixtures_dir, "app/tsconfig.json")

      {:ok, graph} = References.build_project_graph(tsconfig_path)

      # Should have 3 projects: app, core, utils
      assert map_size(graph) == 3
    end

    test "handles single project without references" do
      tsconfig_path = Path.join(@test_fixtures_dir, "packages/core/tsconfig.json")

      {:ok, graph} = References.build_project_graph(tsconfig_path)

      assert map_size(graph) == 1
    end
  end

  describe "build_order/1" do
    test "returns projects in dependency order" do
      tsconfig_path = Path.join(@test_fixtures_dir, "app/tsconfig.json")

      {:ok, order} = References.build_order(tsconfig_path)

      # Core should be built first (no dependencies)
      # Utils depends on core, so it's second
      # App depends on both, so it's last
      core_idx = Enum.find_index(order, fn p -> String.contains?(p, "core") end)
      utils_idx = Enum.find_index(order, fn p -> String.contains?(p, "utils") end)
      app_idx = Enum.find_index(order, fn p -> String.contains?(p, "app") end)

      # Core must come before utils (since utils depends on core)
      assert core_idx < utils_idx
      # Both must come before app
      assert core_idx < app_idx
      assert utils_idx < app_idx
    end

    test "handles single project" do
      tsconfig_path = Path.join(@test_fixtures_dir, "packages/core/tsconfig.json")

      {:ok, order} = References.build_order(tsconfig_path)

      assert length(order) == 1
    end
  end

  describe "build_order_with_info/1" do
    test "returns project info in build order" do
      tsconfig_path = Path.join(@test_fixtures_dir, "app/tsconfig.json")

      {:ok, projects} = References.build_order_with_info(tsconfig_path)

      assert length(projects) == 3
      assert is_map(hd(projects))
      assert Map.has_key?(hd(projects), :path)
      assert Map.has_key?(hd(projects), :config)
    end
  end

  describe "has_references?/1" do
    test "returns true when project has references" do
      tsconfig_path = Path.join(@test_fixtures_dir, "app/tsconfig.json")

      assert References.has_references?(tsconfig_path) == true
    end

    test "returns false when project has no references" do
      tsconfig_path = Path.join(@test_fixtures_dir, "packages/core/tsconfig.json")

      assert References.has_references?(tsconfig_path) == false
    end

    test "returns false for non-existent file" do
      assert References.has_references?("/nonexistent/tsconfig.json") == false
    end
  end

  describe "get_project_files/1" do
    test "returns TypeScript files for project" do
      tsconfig_path = Path.join(@test_fixtures_dir, "packages/core/tsconfig.json")
      {:ok, info} = References.load_project(tsconfig_path)

      files = References.get_project_files(info)

      assert length(files) >= 1
      assert Enum.any?(files, fn f -> String.ends_with?(f, "index.ts") end)
    end
  end
end
