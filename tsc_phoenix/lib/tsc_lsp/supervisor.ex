defmodule TscLsp.Supervisor do
  @moduledoc """
  Supervisor for the TSC Language Server.

  Manages the LSP server and its buffer for communication.
  """

  use Supervisor

  def start_link(args) do
    Supervisor.start_link(__MODULE__, args, name: __MODULE__)
  end

  @impl true
  def init(args) do
    buffer_opts = Keyword.get(args, :buffer_opts, [])
    server_opts = Keyword.get(args, :server_opts, [])

    children = [
      {GenLSP.Buffer, buffer_opts},
      {TscLsp.Server, Keyword.put(server_opts, :buffer, GenLSP.Buffer)}
    ]

    Supervisor.init(children, strategy: :one_for_one)
  end
end
