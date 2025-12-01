defmodule MoonbitTsc.MixProject do
  use Mix.Project

  def project do
    [
      app: :moonbit_tsc,
      version: "0.1.0",
      elixir: "~> 1.15",
      start_permanent: Mix.env() == :prod,
      deps: deps(),
      releases: releases(),
      escript: escript()
    ]
  end

  def application do
    [
      extra_applications: [:logger],
      mod: {MoonbitTsc.Application, []}
    ]
  end

  defp deps do
    [
      {:burrito, "~> 1.0"},
      {:jason, "~> 1.4"},
      {:nimble_options, "~> 1.0"}
    ]
  end

  defp escript do
    [
      main_module: MoonbitTsc.CLI,
      name: "tsc"
    ]
  end

  defp releases do
    [
      moonbit_tsc: [
        steps: [:assemble, &Burrito.wrap/1],
        burrito: [
          targets: [
            macos_arm: [os: :darwin, cpu: :aarch64],
            macos_x86: [os: :darwin, cpu: :x86_64],
            linux_x86: [os: :linux, cpu: :x86_64],
            linux_arm: [os: :linux, cpu: :aarch64],
            windows: [os: :windows, cpu: :x86_64]
          ],
          extra_steps: [
            copy: [
              {"priv/bin/cli.exe", "bin/moonbit-cli"}
            ]
          ]
        ]
      ]
    ]
  end
end
