defmodule Acme.Mixfile do
  use Mix.Project

  def description do
    "Acme (Let's Encrypt) Client for Elixir"
  end

  def project do
    [app: :acme,
     version: "0.2.0",
     elixir: "~> 1.4",
     build_embedded: Mix.env == :prod,
     start_permanent: Mix.env == :prod,
     deps: deps(),
     description: description()]
  end

  def package do
    [maintainers: ["Sikan He"],
     licenses: ["MIT"],
     links: %{github: "https://github.com/sikanhe/acme"}],
     files: ["lib", "config", "mix.exs", "README*"]
  end

  def application do
    [extra_applications: [:logger]]
  end

  defp deps do
    [{:hackney, "~> 1.7.1"},
     {:poison, "~> 3.1.0"},
     {:jose, "~> 1.8.2"},
     # Docs
     {:ex_doc, "~> 0.10", only: :dev},
     {:earmark, "~> 0.1", only: :dev},
     {:inch_ex, ">= 0.0.0", only: :dev}]
  end
end
