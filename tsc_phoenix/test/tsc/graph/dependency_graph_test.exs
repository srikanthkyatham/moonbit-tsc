defmodule TSC.Graph.DependencyGraphTest do
  use ExUnit.Case, async: false

  alias TSC.Graph.DependencyGraph

  setup do
    DependencyGraph.init()
    DependencyGraph.clear()

    on_exit(fn -> DependencyGraph.clear() end)

    :ok
  end

  describe "get_transitive_dependencies/1" do
    test "returns direct and transitive dependencies" do
      DependencyGraph.add("/a.ts", ["/b.ts"])
      DependencyGraph.add("/b.ts", ["/c.ts"])
      DependencyGraph.add("/c.ts", [])
      DependencyGraph.add("/d.ts", [])

      deps = DependencyGraph.get_transitive_dependencies(["/a.ts"])

      assert deps == MapSet.new(["/b.ts", "/c.ts"])
    end

    test "excludes the input files themselves" do
      DependencyGraph.add("/a.ts", ["/b.ts"])
      DependencyGraph.add("/b.ts", [])

      deps = DependencyGraph.get_transitive_dependencies(["/a.ts", "/b.ts"])

      assert deps == MapSet.new()
    end

    test "handles dependency cycles without looping" do
      DependencyGraph.add("/a.ts", ["/b.ts"])
      DependencyGraph.add("/b.ts", ["/a.ts", "/c.ts"])
      DependencyGraph.add("/c.ts", [])

      deps = DependencyGraph.get_transitive_dependencies(["/a.ts"])

      assert deps == MapSet.new(["/b.ts", "/c.ts"])
    end

    test "returns empty set for files not in the graph" do
      assert DependencyGraph.get_transitive_dependencies(["/unknown.ts"]) == MapSet.new()
    end

    test "merges dependencies across multiple input files" do
      DependencyGraph.add("/a.ts", ["/shared.ts"])
      DependencyGraph.add("/b.ts", ["/other.ts"])
      DependencyGraph.add("/shared.ts", [])
      DependencyGraph.add("/other.ts", [])

      deps = DependencyGraph.get_transitive_dependencies(["/a.ts", "/b.ts"])

      assert deps == MapSet.new(["/shared.ts", "/other.ts"])
    end
  end
end
