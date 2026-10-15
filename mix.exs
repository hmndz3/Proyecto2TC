defmodule Cyk.MixProject do
  use Mix.Project

  def project do
    [
      app: :cyk,
      version: "1.0.0",
      elixir: "~> 1.14",
      start_permanent: Mix.env() == :prod,
      escript: [main_module: Cyk.CLI],
      deps: deps()
    ]
  end

  def application do
    [extra_applications: [:logger]]
  end

  # el proyecto no usa librerias externas
  defp deps, do: []
end
