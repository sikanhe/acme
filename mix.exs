defmodule Acme.Mixfile do
  use Mix.Project

  def description do
    "Acme (Let's Encrypt) Client for Elixir"
  end

  def project do
    [app: :acme,
     version: "0.4.0",
     elixir: "~> 1.4",
     build_embedded: Mix.env == :prod,
     start_permanent: Mix.env == :prod,
     deps: deps(),
     description: description(),
     package: package()]
  end

  def package() do
    [maintainers: ["Sikan He"],
     licenses: ["MIT"],
     links: %{github: "https://github.com/sikanhe/acme"},
     files: ["lib", "config", "mix.exs", "README*"]]
  end

  def application do
    [extra_applications: [:logger]]
  end

  defp deps do
    [{:hackney, "~> 1.10"},
     {:poison, "~> 3.1"},
     {:jose, "~> 1.8"},
     # Docs
     {:ex_doc, "~> 0.15", only: :dev},
     {:earmark, "~> 1.2", only: :dev},
     {:inch_ex, ">= 0.0.0", only: :dev}]
  end
end
