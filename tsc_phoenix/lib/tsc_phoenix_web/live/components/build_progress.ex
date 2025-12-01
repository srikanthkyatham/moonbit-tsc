defmodule TscPhoenixWeb.Live.Components.BuildProgress do
  @moduledoc """
  Build progress visualization component.

  Shows real-time compilation progress with phase timing,
  file progress, and error counts.
  """

  use Phoenix.Component

  @doc """
  Renders the build progress visualization.

  ## Assigns
  - current_build: Map with build status info
  - active_checks: List of files currently being checked
  - phases: Map of phase timing metrics
  - errors_count: Number of errors found
  - warnings_count: Number of warnings found
  """
  attr :current_build, :map, default: nil
  attr :active_checks, :list, default: []
  attr :phases, :map, default: %{}
  attr :errors_count, :integer, default: 0
  attr :warnings_count, :integer, default: 0

  def build_progress(assigns) do
    ~H"""
    <div class="build-progress bg-base-100 rounded-lg shadow-xl overflow-hidden">
      <!-- Header -->
      <div class="p-3 bg-base-200 flex items-center justify-between">
        <h2 class="font-semibold flex items-center gap-2">
          <.status_icon status={build_status(@current_build)} />
          Build Progress
        </h2>
        <div class="flex gap-2">
          <%= if @errors_count > 0 do %>
            <span class="badge badge-error"><%= @errors_count %> errors</span>
          <% end %>
          <%= if @warnings_count > 0 do %>
            <span class="badge badge-warning"><%= @warnings_count %> warnings</span>
          <% end %>
        </div>
      </div>

      <div class="p-4 space-y-4">
        <!-- Overall Progress -->
        <div>
          <%= if @current_build do %>
            <%= case @current_build[:status] do %>
              <% :in_progress -> %>
                <div class="flex items-center gap-3">
                  <div class="flex-1">
                    <div class="flex justify-between text-sm mb-1">
                      <span>Checking files...</span>
                      <span class="text-base-content/60">
                        <%= @current_build[:checked] || length(@active_checks) %> / <%= @current_build[:files_count] %>
                      </span>
                    </div>
                    <progress
                      class="progress progress-primary w-full"
                      value={(@current_build[:checked] || 0)}
                      max={@current_build[:files_count] || 1}
                    ></progress>
                  </div>
                  <span class="loading loading-spinner loading-sm text-primary"></span>
                </div>
              <% :complete -> %>
                <div class="alert alert-success">
                  <svg xmlns="http://www.w3.org/2000/svg" class="h-5 w-5" fill="none" viewBox="0 0 24 24" stroke="currentColor">
                    <path stroke-linecap="round" stroke-linejoin="round" stroke-width="2" d="M5 13l4 4L19 7" />
                  </svg>
                  <span>
                    Completed in <%= format_duration(@current_build[:duration] || @current_build[:stats][:elapsed_ms]) %>
                  </span>
                </div>
              <% _ -> %>
                <p class="text-base-content/60">Ready to build</p>
            <% end %>
          <% else %>
            <p class="text-base-content/60">No active build</p>
          <% end %>
        </div>

        <!-- Phase Timing -->
        <%= if map_size(@phases) > 0 do %>
          <div>
            <h3 class="font-semibold text-sm mb-2">Phase Timing</h3>
            <div class="space-y-2">
              <%= for {phase, data} <- @phases do %>
                <.phase_bar phase={phase} data={data} />
              <% end %>
            </div>
          </div>
        <% end %>

        <!-- Active Files -->
        <%= if length(@active_checks) > 0 do %>
          <div>
            <h3 class="font-semibold text-sm mb-2 flex items-center gap-2">
              <span class="loading loading-dots loading-xs"></span>
              Currently Checking (<%= length(@active_checks) %>)
            </h3>
            <div class="space-y-1 max-h-32 overflow-y-auto">
              <%= for file <- Enum.take(@active_checks, 8) do %>
                <div class="flex items-center gap-2 text-sm bg-base-200 rounded px-2 py-1">
                  <span class="loading loading-spinner loading-xs text-primary"></span>
                  <span class="truncate font-mono text-xs"><%= Path.basename(file) %></span>
                </div>
              <% end %>
              <%= if length(@active_checks) > 8 do %>
                <p class="text-xs text-base-content/60 px-2">
                  ... and <%= length(@active_checks) - 8 %> more
                </p>
              <% end %>
            </div>
          </div>
        <% end %>
      </div>
    </div>
    """
  end

  attr :phase, :atom, required: true
  attr :data, :map, required: true

  defp phase_bar(assigns) do
    # Calculate relative width based on avg_ms
    max_ms = 1000  # Assume 1s max for scaling
    width = min(100, (assigns.data[:avg_ms] || 0) / max_ms * 100)
    assigns = assign(assigns, :width, width)

    ~H"""
    <div class="flex items-center gap-2">
      <span class="w-20 text-xs font-mono capitalize"><%= @phase %></span>
      <div class="flex-1 bg-base-200 rounded-full h-2 overflow-hidden">
        <div
          class={"h-full #{phase_color(@phase)}"}
          style={"width: #{@width}%"}
        ></div>
      </div>
      <span class="w-16 text-xs text-right font-mono">
        <%= @data[:avg_ms] || 0 %>ms
      </span>
      <span class="w-12 text-xs text-base-content/60">
        x<%= @data[:count] || 0 %>
      </span>
    </div>
    """
  end

  attr :status, :atom, required: true

  defp status_icon(assigns) do
    ~H"""
    <%= case @status do %>
      <% :in_progress -> %>
        <span class="loading loading-spinner loading-sm text-primary"></span>
      <% :complete -> %>
        <svg xmlns="http://www.w3.org/2000/svg" class="h-5 w-5 text-success" fill="none" viewBox="0 0 24 24" stroke="currentColor">
          <path stroke-linecap="round" stroke-linejoin="round" stroke-width="2" d="M5 13l4 4L19 7" />
        </svg>
      <% :error -> %>
        <svg xmlns="http://www.w3.org/2000/svg" class="h-5 w-5 text-error" fill="none" viewBox="0 0 24 24" stroke="currentColor">
          <path stroke-linecap="round" stroke-linejoin="round" stroke-width="2" d="M6 18L18 6M6 6l12 12" />
        </svg>
      <% _ -> %>
        <svg xmlns="http://www.w3.org/2000/svg" class="h-5 w-5 text-base-content/40" fill="none" viewBox="0 0 24 24" stroke="currentColor">
          <path stroke-linecap="round" stroke-linejoin="round" stroke-width="2" d="M12 8v4l3 3m6-3a9 9 0 11-18 0 9 9 0 0118 0z" />
        </svg>
    <% end %>
    """
  end

  defp build_status(nil), do: :idle
  defp build_status(%{status: status}), do: status
  defp build_status(_), do: :idle

  defp phase_color(:parse), do: "bg-blue-500"
  defp phase_color(:resolve), do: "bg-green-500"
  defp phase_color(:bind), do: "bg-yellow-500"
  defp phase_color(:check), do: "bg-purple-500"
  defp phase_color(:emit), do: "bg-pink-500"
  defp phase_color(_), do: "bg-primary"

  defp format_duration(nil), do: "..."
  defp format_duration(ms) when ms < 1000, do: "#{ms}ms"
  defp format_duration(ms), do: "#{Float.round(ms / 1000, 2)}s"
end
