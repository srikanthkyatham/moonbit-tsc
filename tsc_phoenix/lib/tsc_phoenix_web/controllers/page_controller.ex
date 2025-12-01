defmodule TscPhoenixWeb.PageController do
  use TscPhoenixWeb, :controller

  def home(conn, _params) do
    render(conn, :home)
  end
end
