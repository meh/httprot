defmodule Httprot.Mixfile do
  use Mix.Project

  def project do
    [ app: :httprot,
      version: "0.1.7",
      deps: deps(),
      package: package(),
      description: "HTTP client library" ]
  end

  defp package do
    [ maintainers: ["meh"],
      licenses: ["WTFPL"],
      links: %{"GitHub" => "https://github.com/meh/httprot"} ]
  end

  def application do
    [ applications: [:socket] ]
  end

  defp deps do
    [ { :socket, "~> 0.3.0" },
      { :datastructures, "~> 0.2" },
      { :ex_doc, "~> 0.14", only: [:dev] } ]
  end
end
