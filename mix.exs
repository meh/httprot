defmodule Httprot.Mixfile do
  use Mix.Project

  def project do
    [ app: :httprot,
      version: "0.1.0",
      elixir: "~> 0.13.2",
      deps: deps,
      package: package,
      description: "HTTP client library" ]
  end

  defp package do
    [ contributors: ["meh"],
      license: "WTFPL",
      links: [ { "GitHub", "https://github.com/meh/httprot" } ] ]
  end

  def application do
    [ applications: [:socket] ]
  end

  defp deps do
    [ { :socket, "~> 0.2.2" } ]
  end
end
