defmodule Mix.Tasks.TscLsp do
  @moduledoc """
  Starts the TSC Language Server.

  This task starts the language server for use with editors like VS Code, Neovim, etc.

  ## Usage

      mix tsc_lsp

  The server communicates via stdin/stdout using the Language Server Protocol.

  ## Configuration

  The server uses the MoonBit TypeScript compiler CLI. Configure the path in config:

      config :tsc_phoenix, :cli_path, "/path/to/cli.exe"

  ## Editor Integration

  ### VS Code

  Add to settings.json:

      {
        "typescript.tsserver.useSeparateSyntaxServer": false,
        "typescript.tsdk": null
      }

  And configure the language server extension to use this server.

  ### Neovim (with nvim-lspconfig)

      require('lspconfig.configs').tsc_lsp = {
        default_config = {
          cmd = {'mix', 'tsc_lsp'},
          filetypes = {'typescript', 'typescriptreact'},
          root_dir = require('lspconfig').util.root_pattern('tsconfig.json', 'package.json', '.git'),
        }
      }
      require('lspconfig').tsc_lsp.setup{}

  """

  use Mix.Task

  @shortdoc "Starts the TSC Language Server"

  @impl true
  def run(_args) do
    Application.ensure_all_started(:logger)

    # Configure logger for LSP (stderr only, no stdout interference)
    Logger.configure(level: :info)
    Logger.configure_backend(:console, device: :standard_error)

    cli_path =
      Application.get_env(
        :tsc_phoenix,
        :cli_path,
        "/Users/srikanthkyatham/Personal/moonbit/pure-moonbit-cli/src/moonbit/target/native/release/build/cli/cli.exe"
      )

    {:ok, _pid} =
      TscLsp.Supervisor.start_link(
        buffer_opts: [communication: {GenLSP.Communication.Stdio, []}],
        server_opts: [cli_path: cli_path]
      )

    # Keep the process alive
    Process.sleep(:infinity)
  end
end
