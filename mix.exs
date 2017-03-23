defmodule Acme.Mixfile do
  use Mix.Project

  def project do
    [app: :acme,
     version: "0.1.0",
     elixir: "~> 1.4",
     build_embedded: Mix.env == :prod,
     start_permanent: Mix.env == :prod,
     deps: deps()]
  end

  def application do
    [extra_applications: [:logger]]
  end

  defp deps do
    [{:hackney, "~> 1.7.1"},
     {:poison, "~> 3.1.0"},
     {:jose, "~> 1.8.2"}]
  end
end
