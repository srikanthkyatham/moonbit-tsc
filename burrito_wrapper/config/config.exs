import Config

config :moonbit_tsc,
  # Default number of workers (0 means use System.schedulers_online())
  default_workers: 0,

  # Default compilation timeout
  default_timeout: 60_000,

  # CLI binary name
  cli_binary: "moonbit-cli"

# Import environment specific config
import_config "#{config_env()}.exs"
