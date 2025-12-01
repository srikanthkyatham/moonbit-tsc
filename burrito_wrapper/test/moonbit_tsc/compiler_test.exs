defmodule MoonbitTsc.CompilerTest do
  use ExUnit.Case

  alias MoonbitTsc.Compiler

  describe "cli_path/0" do
    test "returns a path string" do
      assert is_binary(Compiler.cli_path())
    end

    test "path ends with moonbit-cli" do
      assert String.ends_with?(Compiler.cli_path(), "moonbit-cli")
    end
  end

  describe "cli_available?/0" do
    test "returns boolean" do
      assert is_boolean(Compiler.cli_available?())
    end
  end
end
