defmodule MoonbitTsc.Application do
  @moduledoc """
  OTP Application for MoonBit TypeScript Compiler.
  """

  use Application

  @impl true
  def start(_type, _args) do
    children = [
      # Worker pool for parallel compilation
      {MoonbitTsc.WorkerPool, []},
      # Registry for tracking active compilations
      {Registry, keys: :unique, name: MoonbitTsc.Registry}
    ]

    opts = [strategy: :one_for_one, name: MoonbitTsc.Supervisor]
    Supervisor.start_link(children, opts)
  end
end
