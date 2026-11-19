defmodule ExAwsLocation.MixProject do
  use Mix.Project

  def project do
    [
      app: :ex_aws_location,
      version: "0.1.0",
      elixir: "~> 1.15",
      start_permanent: Mix.env() == :prod,
      deps: deps(),
      package: package(),
      docs: docs()
    ]
  end

  def application do
    [
      extra_applications: [:logger, :crypto]
    ]
  end

  # Run "mix help deps" to learn about dependencies.
  defp deps do
    [
      ex_aws_dep(),
      {:jason, "~> 1.2"},

      # Non-runtime deps
      {:hackney, "~> 4.0", only: [:dev, :test]},
      {:credo, "~> 1.4", only: [:dev, :test], runtime: false},
      {:dialyxir, "~> 1.0", only: [:dev, :test], runtime: false},
      {:ex_doc, ">= 0.0.0", only: :dev, runtime: false}
    ]
  end

  # The Location control plane, metadata and geo-maps services need a version of
  # ex_aws newer than 2.7.0. Until that is released, set EX_AWS_PATH to a checkout
  # of ex_aws that has them. Once it is, bump the requirement and remove this.
  defp ex_aws_dep do
    case System.get_env("EX_AWS_PATH") do
      nil -> {:ex_aws, "~> 2.7"}
      path -> {:ex_aws, path: path}
    end
  end

  defp package do
    [
      description: "Amazon Location Service support library for ExAws",
      licenses: ["MIT"],
      files: ["lib", "mix.exs", "README*", "CHANGELOG*"],
      links: %{github: "https://github.com/ex-aws/ex_aws_location"}
    ]
  end

  defp docs do
    [
      main: "ExAws.Location",
      groups_for_modules: [
        Services: [
          ExAws.Location,
          ExAws.Location.Maps,
          ExAws.Location.Places,
          ExAws.Location.Routes,
          ExAws.Location.Geofences,
          ExAws.Location.Trackers,
          ExAws.Location.Keys,
          ExAws.Location.Jobs,
          ExAws.Location.Tags
        ],
        "Places types": ~r/^ExAws\.Location\.Places\./,
        "Routes types": ~r/^ExAws\.Location\.Routes\./,
        "Geofences types": ~r/^ExAws\.Location\.Geofences\./,
        "Trackers types": ~r/^ExAws\.Location\.Trackers\./,
        "Keys types": ~r/^ExAws\.Location\.Keys\./,
        "Jobs types": ~r/^ExAws\.Location\.Jobs\./,
        "Shared types": ~r/^ExAws\.Location\.[A-Z]\w+$/
      ]
    ]
  end
end
