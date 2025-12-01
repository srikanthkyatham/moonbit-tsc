defmodule MoonbitTscTest do
  use ExUnit.Case
  doctest MoonbitTsc

  describe "version/0" do
    test "returns version string" do
      assert MoonbitTsc.version() == "0.1.0"
    end
  end

  describe "compile/1" do
    @tag :skip
    test "compiles TypeScript files" do
      # Requires CLI binary to be available
      assert {:ok, _} = MoonbitTsc.compile(["test/fixtures/simple.ts"], out_dir: "test/output")
    end
  end

  describe "check/2" do
    @tag :skip
    test "checks TypeScript files" do
      # Requires CLI binary to be available
      assert {:ok, _} = MoonbitTsc.check(["test/fixtures/simple.ts"])
    end
  end
end
