defmodule TscPhoenixWeb.MetricsLive do
  @moduledoc """
  Metrics page with time series charts and detailed statistics.
  """

  use TscPhoenixWeb, :live_view

  import TscPhoenixWeb.Live.Components.Navigation

  alias TSC.Telemetry.Reporter

  @impl true
  def mount(_params, _session, socket) do
    if connected?(socket) do
      Phoenix.PubSub.subscribe(TscPhoenix.PubSub, "compiler:updates")
      :timer.send_interval(5000, self(), :refresh)
    end

    socket =
      socket
      |> assign(:page_title, "Metrics")
      |> assign(:metrics, Reporter.get_metrics())
      |> assign(:history, %{
        avg_duration: Reporter.get_history(:avg_duration_ms, 60),
        cache_hit_rate: Reporter.get_history(:cache_hit_rate, 60),
        file_checks: Reporter.get_history(:file_checks, 60)
      })

    {:ok, socket}
  end

  @impl true
  def handle_info(:refresh, socket) do
    socket =
      socket
      |> assign(:metrics, Reporter.get_metrics())
      |> assign(:history, %{
        avg_duration: Reporter.get_history(:avg_duration_ms, 60),
        cache_hit_rate: Reporter.get_history(:cache_hit_rate, 60),
        file_checks: Reporter.get_history(:file_checks, 60)
      })

    {:noreply, socket}
  end

  @impl true
  def handle_info(_, socket), do: {:noreply, socket}

  @impl true
  def render(assigns) do
    ~H"""
    <div class="min-h-screen bg-base-200">
      <header class="navbar bg-base-100 shadow-lg">
        <div class="flex-1 gap-4">
          <span class="text-xl font-bold px-4">TSC Dashboard</span>
          <.nav_tabs current_path="/metrics" />
        </div>
      </header>

      <main class="container mx-auto p-4">
        <div class="grid grid-cols-1 md:grid-cols-2 gap-6">
          <!-- Performance Metrics -->
          <div class="card bg-base-100 shadow-xl">
            <div class="card-body">
              <h2 class="card-title">Performance</h2>
              <div class="stats stats-vertical">
                <div class="stat">
                  <div class="stat-title">Total Files Checked</div>
                  <div class="stat-value"><%= @metrics.file_checks %></div>
                </div>
                <div class="stat">
                  <div class="stat-title">Avg Check Time</div>
                  <div class="stat-value"><%= @metrics.avg_duration_ms %>ms</div>
                </div>
                <div class="stat">
                  <div class="stat-title">Total Duration</div>
                  <div class="stat-value"><%= format_duration(@metrics.total_duration_ms) %></div>
                </div>
              </div>
            </div>
          </div>

          <!-- Cache Metrics -->
          <div class="card bg-base-100 shadow-xl">
            <div class="card-body">
              <h2 class="card-title">Cache Performance</h2>
              <div class="stats stats-vertical">
                <div class="stat">
                  <div class="stat-title">Cache Hits</div>
                  <div class="stat-value text-success"><%= @metrics.cache_hits %></div>
                </div>
                <div class="stat">
                  <div class="stat-title">Cache Misses</div>
                  <div class="stat-value text-warning"><%= @metrics.cache_misses %></div>
                </div>
                <div class="stat">
                  <div class="stat-title">Hit Rate</div>
                  <div class="stat-value"><%= @metrics.cache_hit_rate %>%</div>
                </div>
              </div>
            </div>
          </div>

          <!-- Error Metrics -->
          <div class="card bg-base-100 shadow-xl">
            <div class="card-body">
              <h2 class="card-title">Diagnostics</h2>
              <div class="stats stats-vertical">
                <div class="stat">
                  <div class="stat-title">Errors</div>
                  <div class="stat-value text-error"><%= @metrics.errors_count %></div>
                </div>
                <div class="stat">
                  <div class="stat-title">Warnings</div>
                  <div class="stat-value text-warning"><%= @metrics.warnings_count %></div>
                </div>
              </div>
            </div>
          </div>

          <!-- Worker Metrics -->
          <div class="card bg-base-100 shadow-xl">
            <div class="card-body">
              <h2 class="card-title">Workers</h2>
              <div class="stats stats-vertical">
                <div class="stat">
                  <div class="stat-title">Total Requests</div>
                  <div class="stat-value"><%= @metrics.worker_requests %></div>
                </div>
                <div class="stat">
                  <div class="stat-title">Worker Crashes</div>
                  <div class="stat-value text-error"><%= @metrics.worker_crashes %></div>
                </div>
              </div>
            </div>
          </div>
        </div>

        <!-- History Charts Placeholder -->
        <div class="card bg-base-100 shadow-xl mt-6">
          <div class="card-body">
            <h2 class="card-title">History (Last Hour)</h2>
            <div class="grid grid-cols-3 gap-4">
              <div>
                <h3 class="font-semibold">Avg Duration (ms)</h3>
                <div class="text-sm text-base-content/60">
                  <%= length(@history.avg_duration) %> data points
                </div>
              </div>
              <div>
                <h3 class="font-semibold">Cache Hit Rate (%)</h3>
                <div class="text-sm text-base-content/60">
                  <%= length(@history.cache_hit_rate) %> data points
                </div>
              </div>
              <div>
                <h3 class="font-semibold">Files Checked</h3>
                <div class="text-sm text-base-content/60">
                  <%= length(@history.file_checks) %> data points
                </div>
              </div>
            </div>
          </div>
        </div>
      </main>
    </div>
    """
  end

  defp format_duration(ms) when ms < 1000, do: "#{ms}ms"
  defp format_duration(ms) when ms < 60_000, do: "#{Float.round(ms / 1000, 1)}s"
  defp format_duration(ms), do: "#{Float.round(ms / 60_000, 1)}m"
end
