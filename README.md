# ExAwsLocation

Amazon Location Service module for [ExAws](https://github.com/ex-aws/ex_aws).

## Installation

The package can be installed by adding `ex_aws_location` to your list of
dependencies in `mix.exs`, along with the HTTP client of your choice (see the
ExAws documentation):

```elixir
def deps do
  [
    {:ex_aws, "~> 2.7"},
    {:ex_aws_location, "~> 0.1.0"},
    {:hackney, "~> 4.0"}
  ]
end
```

Note that this needs a version of ExAws that knows about the Amazon Location
control plane, metadata and `geo-maps` endpoints, which means one newer than
2.7.0.

## Use

The API is split in to a module for each of the Amazon Location services:

| Module                     | Covers                                                      |
| -------------------------- | ----------------------------------------------------------- |
| `ExAws.Location.Maps`      | Tiles, style descriptors, sprites, glyphs and static maps   |
| `ExAws.Location.Places`    | Geocoding, reverse geocoding, search, autocomplete, suggest |
| `ExAws.Location.Routes`    | Routes, route matrices, isolines, waypoints, snap-to-roads  |
| `ExAws.Location.Geofences` | Geofence collections, geofences, evaluation and forecasting |
| `ExAws.Location.Trackers`  | Trackers and device positions                               |
| `ExAws.Location.Keys`      | API keys                                                    |
| `ExAws.Location.Jobs`      | Bulk processing jobs                                        |
| `ExAws.Location.Tags`      | Resource tagging                                            |

Maps, Places and Routes are the current, resource-less versions of those APIs
(`geo-maps`, `geo-places` and `geo-routes`). The older map, place index and
route calculator resources are not implemented.

Each function builds an operation which you pass to `ExAws.request/2`. Required
parameters are positional, optional ones go in a keyword list:

```elixir
alias ExAws.Location.DevicePositionUpdate
alias ExAws.Location.Places
alias ExAws.Location.Trackers

{:ok, _} =
  "vans"
  |> Trackers.create_tracker(description: "Delivery vans", position_filtering: "TimeBased")
  |> ExAws.request()

update = %DevicePositionUpdate{
  device_id: "van-1",
  position: [-1.5491, 53.8008],
  sample_time: DateTime.utc_now()
}

{:ok, _} = "vans" |> Trackers.batch_update_device_position([update]) |> ExAws.request()

{:ok, %{"ResultItems" => results}} =
  [query_text: "Leeds Town Hall", max_results: 1]
  |> Places.geocode()
  |> ExAws.request(region: "eu-west-1")
```

Options are named after the parameters in the
[API reference](https://docs.aws.amazon.com/location/latest/APIReference/Welcome.html),
converted to snake case (`KmsKeyId` is `:kms_key_id`). Nested request types each
have a struct, such as `ExAws.Location.Routes.RouteAvoidanceOptions`. Responses
are returned as decoded JSON, other than those from `ExAws.Location.Maps`, which
are returned as the raw response since they are mostly binary.

## Updating for AWS API changes

Everything under `lib/ex_aws/location/` is generated from the API models that AWS
publishes in [botocore](https://github.com/boto/botocore), so don't edit those
files by hand. To pick up new operations, parameters and types, re-run the
generator and review the diff:

```sh
elixir scripts/generate.exs
```

`lib/ex_aws/location.ex`, which builds and encodes the requests, is hand-written.

## Documentation

Documentation can be generated with [ExDoc](https://github.com/elixir-lang/ex_doc)
and published on [HexDocs](https://hexdocs.pm). Once published, the docs can
be found at <https://hexdocs.pm/ex_aws_location>.
