defmodule TscPhoenixWeb.PageControllerTest do
  use TscPhoenixWeb.ConnCase

  test "GET / renders dashboard", %{conn: conn} do
    conn = get(conn, ~p"/")
    # The dashboard LiveView is rendered at the root
    assert html_response(conn, 200) =~ "TSC Dashboard"
  end
end
