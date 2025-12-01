defmodule TscPhoenixWeb.Router do
  use TscPhoenixWeb, :router

  pipeline :browser do
    plug :accepts, ["html"]
    plug :fetch_session
    plug :fetch_live_flash
    plug :put_root_layout, html: {TscPhoenixWeb.Layouts, :root}
    plug :protect_from_forgery
    plug :put_secure_browser_headers
  end

  pipeline :api do
    plug :accepts, ["json"]
  end

  scope "/", TscPhoenixWeb do
    pipe_through :browser

    live "/", DashboardLive, :index
    live "/metrics", MetricsLive, :index
    live "/errors", ErrorsLive, :index
  end

  # REST API for CI/CD integration
  scope "/api", TscPhoenixWeb.API do
    pipe_through :api

    post "/check", CheckController, :create
    get "/check/status", CheckController, :status

    # Metrics endpoints
    get "/metrics", MetricsController, :summary
    get "/metrics/prometheus", MetricsController, :prometheus
    get "/metrics/json", MetricsController, :json_export
    get "/metrics/phases", MetricsController, :phases
    get "/metrics/history/:metric", MetricsController, :history
  end

  # Enable LiveDashboard in development
  if Application.compile_env(:tsc_phoenix, :dev_routes) do
    # If you want to use the LiveDashboard in production, you should put
    # it behind authentication and allow only admins to access it.
    # If your application does not have an admins-only section yet,
    # you can use Plug.BasicAuth to set up some basic authentication
    # as long as you are also using SSL (which you should anyway).
    import Phoenix.LiveDashboard.Router

    scope "/dev" do
      pipe_through :browser

      live_dashboard "/dashboard", metrics: TscPhoenixWeb.Telemetry
    end
  end
end
