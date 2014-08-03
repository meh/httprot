defmodule Httprot.Mixfile do
  use Mix.Project

  def project do
    [ app: :httprot,
      version: "0.1.4",
      elixir: "~> 0.15.0",
      deps: deps,
      package: package,
      description: "HTTP client library" ]
  end

  defp package do
    [ contributors: ["meh"],
      licenses: ["WTFPL"],
      links: %{"GitHub" => "https://github.com/meh/httprot"} ]
  end

  def application do
    [ applications: [:socket] ]
  end

  defp deps do
    [ { :socket, "~> 0.2.6" },
      { :continuum, github: "meh/continuum" } ]
  end
end
