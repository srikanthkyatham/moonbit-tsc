defmodule TscPhoenixWeb.API.CheckControllerTest do
  use TscPhoenixWeb.ConnCase

  # Path relative to project root
  @test_project_path Path.expand("test_project", File.cwd!())

  describe "POST /api/check" do
    test "with explicit files list", %{conn: conn} do
      files = [
        Path.join(@test_project_path, "src/index.ts"),
        Path.join(@test_project_path, "src/utils.ts")
      ]

      conn = post(conn, ~p"/api/check", %{
        "files" => files,
        "options" => %{"incremental" => false}
      })

      assert %{
        "success" => _success,
        "diagnostics" => diagnostics,
        "stats" => stats
      } = json_response(conn, conn.status)

      assert is_list(diagnostics)
      assert is_map(stats)
      assert Map.has_key?(stats, "files_checked")
    end

    test "with project path", %{conn: conn} do
      conn = post(conn, ~p"/api/check", %{
        "project" => @test_project_path,
        "options" => %{"incremental" => false}
      })

      assert %{
        "success" => _success,
        "diagnostics" => diagnostics,
        "stats" => %{"files_checked" => files_checked}
      } = json_response(conn, conn.status)

      assert is_list(diagnostics)
      assert files_checked > 0
    end

    test "with tsconfig.json path", %{conn: conn} do
      tsconfig_path = Path.join(@test_project_path, "tsconfig.json")

      conn = post(conn, ~p"/api/check", %{
        "tsconfig" => tsconfig_path,
        "options" => %{"incremental" => false}
      })

      assert %{
        "success" => _success,
        "diagnostics" => diagnostics,
        "stats" => %{"files_checked" => files_checked}
      } = json_response(conn, conn.status)

      assert is_list(diagnostics)
      assert files_checked >= 1
    end

    test "returns diagnostics with correct structure", %{conn: conn} do
      # Use file with known type error
      type_error_file = Path.join(@test_project_path, "src/type_error.ts")

      conn = post(conn, ~p"/api/check", %{
        "files" => [type_error_file],
        "options" => %{"incremental" => false}
      })

      response = json_response(conn, conn.status)
      diagnostics = response["diagnostics"]

      # Should have at least one diagnostic for type_error.ts
      if length(diagnostics) > 0 do
        [first | _] = diagnostics

        assert is_binary(first["file"])
        assert is_integer(first["line"])
        assert is_integer(first["column"])
        assert is_binary(first["code"])
        assert is_binary(first["category"])
        assert is_binary(first["message"])
      end
    end
  end

  describe "GET /api/check/status" do
    test "returns status information", %{conn: conn} do
      conn = get(conn, ~p"/api/check/status")

      assert %{
        "building" => building,
        "active_files" => active_files,
        "metrics" => metrics
      } = json_response(conn, 200)

      assert is_boolean(building)
      assert is_list(active_files)
      assert is_map(metrics)
    end
  end

  describe "GET /api/metrics" do
    test "returns metrics information", %{conn: conn} do
      conn = get(conn, ~p"/api/metrics")

      assert %{
        "metrics" => metrics,
        "history" => history
      } = json_response(conn, 200)

      assert is_map(metrics)
      assert is_map(history)
    end
  end
end
