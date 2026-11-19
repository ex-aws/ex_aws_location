defmodule ExAws.Location.RequestsTest do
  @moduledoc """
  Runs operations from each service module through `ExAws.request/2` with a stub
  HTTP client, checking the endpoint, signing name, path, query string and body
  that would be sent to AWS.
  """
  use ExUnit.Case, async: true

  import ExAws.Location.TestHelper

  alias ExAws.Location.DevicePositionUpdate
  alias ExAws.Location.Geofences
  alias ExAws.Location.Geofences.Circle
  alias ExAws.Location.Geofences.GeofenceGeometry
  alias ExAws.Location.Jobs
  alias ExAws.Location.Jobs.JobInputOptions
  alias ExAws.Location.Jobs.JobOutputOptions
  alias ExAws.Location.Keys
  alias ExAws.Location.Keys.ApiKeyRestrictions
  alias ExAws.Location.Maps
  alias ExAws.Location.Places
  alias ExAws.Location.Places.GeocodeFilter
  alias ExAws.Location.Routes
  alias ExAws.Location.Routes.RouteAvoidanceOptions
  alias ExAws.Location.Tags
  alias ExAws.Location.TestClient
  alias ExAws.Location.Trackers

  @arn "arn:aws:geo:eu-west-1:123456789012:tracker/vans"

  describe "Trackers" do
    test "create_tracker uses the control plane" do
      {result, request} =
        "vans"
        |> Trackers.create_tracker(position_filtering: "TimeBased", tags: %{"env" => "dev"})
        |> request()

      assert result == {:ok, %{}}
      assert request.method == :post
      assert request.host == "cp.tracking.geo.eu-west-1.amazonaws.com"
      assert request.path == "/tracking/v0/trackers"
      assert request.query == nil
      assert signing_name(request) == "geo"
      assert request.headers["content-type"] == "application/json"

      assert request.json == %{
               "TrackerName" => "vans",
               "PositionFiltering" => "TimeBased",
               "Tags" => %{"env" => "dev"}
             }
    end

    test "batch_update_device_position uses the data plane" do
      update = %DevicePositionUpdate{
        device_id: "van-1",
        position: [-1.5, 53.4],
        sample_time: ~U[2026-01-02 03:04:05Z]
      }

      {_result, request} = "vans" |> Trackers.batch_update_device_position([update]) |> request()

      assert request.host == "tracking.geo.eu-west-1.amazonaws.com"
      assert request.path == "/tracking/v0/trackers/vans/positions"
      assert signing_name(request) == "geo"

      assert request.json == %{
               "Updates" => [
                 %{
                   "DeviceId" => "van-1",
                   "Position" => [-1.5, 53.4],
                   "SampleTime" => "2026-01-02T03:04:05Z"
                 }
               ]
             }
    end

    test "get_device_position decodes the response" do
      TestClient.respond_with(
        {:ok, %{status_code: 200, headers: [], body: ~s({"DeviceId":"a b"})}}
      )

      {result, request} = "vans" |> Trackers.get_device_position("a b") |> request()

      assert result == {:ok, %{"DeviceId" => "a b"}}
      assert request.method == :get
      assert request.host == "tracking.geo.eu-west-1.amazonaws.com"
      assert request.path == "/tracking/v0/trackers/vans/devices/a%20b/positions/latest"
      assert request.body == ""
    end

    test "disassociate_tracker_consumer escapes the ARN" do
      {result, request} = "vans" |> Trackers.disassociate_tracker_consumer(@arn) |> request()

      assert result == {:ok, %{}}
      assert request.method == :delete
      assert request.host == "cp.tracking.geo.eu-west-1.amazonaws.com"

      assert request.path ==
               "/tracking/v0/trackers/vans/consumers/" <>
                 "arn%3Aaws%3Ageo%3Aeu-west-1%3A123456789012%3Atracker%2Fvans"
    end

    test "errors are passed through" do
      body = ~s({"message":"nope"})
      TestClient.respond_with({:ok, %{status_code: 404, headers: [], body: body}})

      {result, _request} = "vans" |> Trackers.describe_tracker() |> request()

      assert {:error, {:http_error, 404, %{body: ^body}}} = result
    end
  end

  describe "Geofences" do
    test "put_geofence" do
      geometry = %GeofenceGeometry{circle: %Circle{center: [-1.5, 53.4], radius: 250}}

      {_result, request} =
        "depots"
        |> Geofences.put_geofence("leeds", geometry, geofence_properties: %{"kind" => "depot"})
        |> request()

      assert request.method == :put
      assert request.host == "geofencing.geo.eu-west-1.amazonaws.com"
      assert request.path == "/geofencing/v0/collections/depots/geofences/leeds"
      assert signing_name(request) == "geo"

      assert request.json == %{
               "Geometry" => %{"Circle" => %{"Center" => [-1.5, 53.4], "Radius" => 250}},
               "GeofenceProperties" => %{"kind" => "depot"}
             }
    end

    test "list_geofence_collections uses the control plane" do
      {_result, request} = [max_results: 10] |> Geofences.list_geofence_collections() |> request()

      assert request.method == :post
      assert request.host == "cp.geofencing.geo.eu-west-1.amazonaws.com"
      assert request.path == "/geofencing/v0/list-collections"
      assert request.json == %{"MaxResults" => 10}
    end

    test "update_geofence_collection" do
      {_result, request} =
        "depots" |> Geofences.update_geofence_collection(description: "Depots") |> request()

      assert request.method == :patch
      assert request.host == "cp.geofencing.geo.eu-west-1.amazonaws.com"
      assert request.path == "/geofencing/v0/collections/depots"
      assert request.json == %{"Description" => "Depots"}
    end
  end

  describe "Keys" do
    test "create_key" do
      restrictions = %ApiKeyRestrictions{
        allow_actions: ["geo-maps:*"],
        allow_resources: ["arn:aws:geo-maps:eu-west-1::provider/default"]
      }

      {_result, request} =
        "web"
        |> Keys.create_key(restrictions, expire_time: ~U[2027-01-01 00:00:00Z])
        |> request()

      assert request.host == "cp.metadata.geo.eu-west-1.amazonaws.com"
      assert request.path == "/metadata/v0/keys"
      assert signing_name(request) == "geo"

      assert request.json == %{
               "KeyName" => "web",
               "ExpireTime" => "2027-01-01T00:00:00Z",
               "Restrictions" => %{
                 "AllowActions" => ["geo-maps:*"],
                 "AllowResources" => ["arn:aws:geo-maps:eu-west-1::provider/default"]
               }
             }
    end

    test "delete_key" do
      {_result, request} = "web" |> Keys.delete_key(force_delete: true) |> request()

      assert request.method == :delete
      assert request.path == "/metadata/v0/keys/web"
      assert request.query == "forceDelete=true"
    end
  end

  describe "Jobs" do
    test "start_job uses the metadata data plane and adds a client token" do
      input = %JobInputOptions{format: "Parquet", location: "s3://in/addresses"}
      output = %JobOutputOptions{format: "Parquet", location: "s3://out/"}
      role = "arn:aws:iam::123456789012:role/jobs"

      {_result, request} =
        "ValidateAddress" |> Jobs.start_job(role, input, output, name: "nightly") |> request()

      assert request.host == "metadata.geo.eu-west-1.amazonaws.com"
      assert request.path == "/metadata/v0/jobs"
      assert signing_name(request) == "geo"

      assert %{
               "Action" => "ValidateAddress",
               "ExecutionRoleArn" => ^role,
               "InputOptions" => %{"Format" => "Parquet", "Location" => "s3://in/addresses"},
               "OutputOptions" => %{"Format" => "Parquet", "Location" => "s3://out/"},
               "Name" => "nightly",
               "ClientToken" => <<_::binary-36>>
             } = request.json
    end
  end

  describe "Tags" do
    test "tag_resource" do
      {_result, request} = @arn |> Tags.tag_resource(%{"env" => "dev"}) |> request()

      assert request.method == :post
      assert request.host == "cp.metadata.geo.eu-west-1.amazonaws.com"
      assert request.path == "/tags/arn%3Aaws%3Ageo%3Aeu-west-1%3A123456789012%3Atracker%2Fvans"
      assert request.json == %{"Tags" => %{"env" => "dev"}}
    end

    test "untag_resource repeats the tagKeys parameter" do
      {_result, request} = @arn |> Tags.untag_resource(["env", "cost centre"]) |> request()

      assert request.method == :delete
      assert request.path == "/tags/arn%3Aaws%3Ageo%3Aeu-west-1%3A123456789012%3Atracker%2Fvans"
      assert request.query == "tagKeys=env&tagKeys=cost%20centre"
    end
  end

  describe "Maps" do
    test "get_tile returns the raw response" do
      response = %{status_code: 200, headers: [{"Content-Type", "image/png"}], body: <<137, 80>>}
      TestClient.respond_with({:ok, response})

      {result, request} =
        "vector.basemap"
        |> Maps.get_tile(14, 8100, 5300, additional_features: ["ContourLines", "Hillshade"])
        |> request()

      assert result == {:ok, response}
      assert request.method == :get
      assert request.host == "maps.geo.eu-west-1.amazonaws.com"
      assert request.path == "/v2/tiles/vector.basemap/14/8100/5300"
      assert request.query == "additional-features=ContourLines&additional-features=Hillshade"
      assert signing_name(request) == "geo-maps"
    end

    test "get_static_map" do
      {_result, request} =
        "map" |> Maps.get_static_map(300, 400, center: "-1.5,53.4", zoom: 12.5) |> request()

      assert request.path == "/v2/static/map"

      assert URI.decode_query(request.query) == %{
               "height" => "300",
               "width" => "400",
               "center" => "-1.5,53.4",
               "zoom" => "12.5"
             }
    end
  end

  describe "Places" do
    test "geocode" do
      {result, request} =
        [
          query_text: "1 Main St",
          max_results: 5,
          filter: %GeocodeFilter{include_countries: ["GBR"]},
          key: "v1.public.abc"
        ]
        |> Places.geocode()
        |> request()

      assert result == {:ok, %{}}
      assert request.method == :post
      assert request.host == "places.geo.eu-west-1.amazonaws.com"
      assert request.path == "/v2/geocode"
      assert request.query == "key=v1.public.abc"
      assert signing_name(request) == "geo-places"

      assert request.json == %{
               "QueryText" => "1 Main St",
               "MaxResults" => 5,
               "Filter" => %{"IncludeCountries" => ["GBR"]}
             }
    end

    test "get_place" do
      {_result, request} = "abc/def" |> Places.get_place(language: "en") |> request()

      assert request.method == :get
      assert request.path == "/v2/place/abc%2Fdef"
      assert request.query == "language=en"
    end
  end

  describe "Routes" do
    test "calculate_routes" do
      {_result, request} =
        [-1.2, 53.9]
        |> Routes.calculate_routes([-1.5, 53.4],
          travel_mode: "Truck",
          avoid: %RouteAvoidanceOptions{toll_roads: true, u_turns: false}
        )
        |> request()

      assert request.method == :post
      assert request.host == "routes.geo.eu-west-1.amazonaws.com"
      assert request.path == "/v2/routes"
      assert signing_name(request) == "geo-routes"

      assert request.json == %{
               "Destination" => [-1.2, 53.9],
               "Origin" => [-1.5, 53.4],
               "TravelMode" => "Truck",
               "Avoid" => %{"TollRoads" => true, "UTurns" => false}
             }
    end
  end

  test "the region can be chosen per request" do
    {_result, request} = Trackers.list_trackers() |> request(region: "ap-southeast-5")

    assert request.host == "cp.tracking.geo.ap-southeast-5.amazonaws.com"
  end
end
