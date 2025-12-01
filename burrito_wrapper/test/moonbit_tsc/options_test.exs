defmodule MoonbitTsc.OptionsTest do
  use ExUnit.Case

  alias MoonbitTsc.Options

  describe "validate_compile/1" do
    test "accepts valid options" do
      assert {:ok, opts} = Options.validate_compile(out_dir: "dist", source_map: true)
      assert opts[:out_dir] == "dist"
      assert opts[:source_map] == true
    end

    test "provides defaults" do
      assert {:ok, opts} = Options.validate_compile([])
      assert opts[:source_map] == false
      assert opts[:declaration] == false
    end

    test "rejects invalid options" do
      assert {:error, _} = Options.validate_compile(invalid_option: true)
    end
  end

  describe "validate_check/1" do
    test "accepts valid options" do
      assert {:ok, opts} = Options.validate_check(project: "tsconfig.json")
      assert opts[:project] == "tsconfig.json"
    end
  end

  describe "validate_watch/1" do
    test "accepts valid options" do
      assert {:ok, opts} = Options.validate_watch(poll_interval: 1000)
      assert opts[:poll_interval] == 1000
    end

    test "provides default poll interval" do
      assert {:ok, opts} = Options.validate_watch([])
      assert opts[:poll_interval] == 500
    end
  end
end
