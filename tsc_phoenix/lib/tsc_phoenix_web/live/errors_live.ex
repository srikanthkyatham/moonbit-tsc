defmodule TscPhoenixWeb.ErrorsLive do
  @moduledoc """
  Error browser page for viewing and filtering diagnostics.
  """

  use TscPhoenixWeb, :live_view

  @impl true
  def mount(_params, _session, socket) do
    if connected?(socket) do
      Phoenix.PubSub.subscribe(TscPhoenix.PubSub, "compiler:updates")
    end

    socket =
      socket
      |> assign(:page_title, "Errors")
      |> assign(:errors, [])
      |> assign(:filter, "all")
      |> assign(:search, "")

    {:ok, socket}
  end

  @impl true
  def handle_info({:file_check_stop, data}, socket) do
    new_errors =
      case data do
        %{result: {:ok, %{diagnostics: diags}}} when is_list(diags) ->
          diags ++ socket.assigns.errors
        _ ->
          socket.assigns.errors
      end
      |> Enum.take(500)

    {:noreply, assign(socket, :errors, new_errors)}
  end

  @impl true
  def handle_info({:incremental_check_complete, result}, socket) do
    {:noreply, assign(socket, :errors, result.diagnostics)}
  end

  @impl true
  def handle_info(_, socket), do: {:noreply, socket}

  @impl true
  def handle_event("filter", %{"filter" => filter}, socket) do
    {:noreply, assign(socket, :filter, filter)}
  end

  @impl true
  def handle_event("search", %{"search" => search}, socket) do
    {:noreply, assign(socket, :search, search)}
  end

  @impl true
  def handle_event("clear", _, socket) do
    {:noreply, assign(socket, :errors, [])}
  end

  @impl true
  def render(assigns) do
    filtered_errors = filter_errors(assigns.errors, assigns.filter, assigns.search)

    assigns = assign(assigns, :filtered_errors, filtered_errors)

    ~H"""
    <div class="min-h-screen bg-base-200">
      <header class="navbar bg-base-100 shadow-lg">
        <div class="flex-1">
          <a href="/" class="btn btn-ghost text-xl">TSC Dashboard</a>
          <span class="text-xl font-bold px-4">/ Errors</span>
        </div>
        <div class="flex-none gap-2">
          <input
            type="text"
            placeholder="Search..."
            class="input input-bordered w-64"
            value={@search}
            phx-keyup="search"
            phx-value-search={@search}
          />
          <select class="select select-bordered" phx-change="filter">
            <option value="all" selected={@filter == "all"}>All</option>
            <option value="error" selected={@filter == "error"}>Errors</option>
            <option value="warning" selected={@filter == "warning"}>Warnings</option>
          </select>
          <button phx-click="clear" class="btn btn-ghost">Clear</button>
        </div>
      </header>

      <main class="container mx-auto p-4">
        <div class="mb-4 flex gap-4">
          <div class="badge badge-error gap-2">
            Errors: <%= Enum.count(@errors, &(&1[:category] == :error)) %>
          </div>
          <div class="badge badge-warning gap-2">
            Warnings: <%= Enum.count(@errors, &(&1[:category] == :warning)) %>
          </div>
          <div class="badge badge-info gap-2">
            Total: <%= length(@errors) %>
          </div>
        </div>

        <%= if length(@filtered_errors) > 0 do %>
          <div class="space-y-2">
            <%= for error <- @filtered_errors do %>
              <div class={"alert #{error_class(error[:category])} shadow-lg"}>
                <div class="w-full">
                  <div class="flex justify-between items-start">
                    <div>
                      <span class="font-mono text-xs">
                        <%= error[:file] %>:<%= error[:line] %>:<%= error[:column] %>
                      </span>
                      <span class="badge badge-sm ml-2"><%= error[:code] %></span>
                    </div>
                    <span class="badge"><%= error[:category] %></span>
                  </div>
                  <p class="mt-2"><%= error[:message] %></p>
                </div>
              </div>
            <% end %>
          </div>
        <% else %>
          <div class="alert alert-info">
            <span>No diagnostics to display</span>
          </div>
        <% end %>
      </main>
    </div>
    """
  end

  defp filter_errors(errors, filter, search) do
    errors
    |> Enum.filter(fn error ->
      category_match = filter == "all" or to_string(error[:category]) == filter

      search_match = search == "" or
        String.contains?(String.downcase(error[:message] || ""), String.downcase(search)) or
        String.contains?(String.downcase(error[:file] || ""), String.downcase(search))

      category_match and search_match
    end)
  end

  defp error_class(:error), do: "alert-error"
  defp error_class(:warning), do: "alert-warning"
  defp error_class(_), do: "alert-info"
end
