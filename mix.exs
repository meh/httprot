defmodule Httprot.Mixfile do
  use Mix.Project

  def project do
    [ app: :httprot,
      version: "0.0.1",
      elixir: "~> 0.10.1-dev",
      deps: deps ]
  end

  # Configuration for the OTP application
  def application do
    [ applications: [:socket] ]
  end

  # Returns the list of dependencies in the format:
  # { :foobar, "0.1", git: "https://github.com/elixir-lang/foobar.git" }
  defp deps do
    [ { :socket, github: "meh/elixir-socket" },
      { :datastructures, github: "meh/elixir-datastructures" },

      # TODO: change this to finalizer
      { :managed_process, github: "meh/elixir-managed_process" } ]
  end
end
