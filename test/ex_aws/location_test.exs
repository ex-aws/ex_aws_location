defmodule ExAws.LocationTest do
  use ExUnit.Case, async: true

  alias ExAws.Location
  alias ExAws.Location.DevicePositionUpdate
  alias ExAws.Location.Geofences.Circle
  alias ExAws.Location.Geofences.GeofenceGeometry
  alias ExAws.Location.PositionalAccuracy
  alias ExAws.Operation.JSON
  alias ExAws.Operation.RestQuery

  describe "normalise_data/1" do
    test "camelises struct fields, recursively, dropping nils" do
      update = %DevicePositionUpdate{
        device_id: "van-1",
        position: [-1.5, 53.4],
        sample_time: "2026-01-02T03:04:05Z",
        accuracy: %PositionalAccuracy{horizontal: 5}
      }

      assert Location.normalise_data([update]) == [
               %{
                 "DeviceId" => "van-1",
                 "Position" => [-1.5, 53.4],
                 "SampleTime" => "2026-01-02T03:04:05Z",
                 "Accuracy" => %{"Horizontal" => 5}
               }
             ]
    end

    test "converts DateTime values to ISO 8601" do
      assert Location.normalise_data(%{sample_time: ~U[2026-01-02 03:04:05.678Z]}) ==
               %{"SampleTime" => "2026-01-02T03:04:05.678Z"}
    end

    test "leaves string keys alone" do
      assert Location.normalise_data(%{tags: %{"cost_centre" => "ops", "env" => "dev"}}) ==
               %{"Tags" => %{"cost_centre" => "ops", "env" => "dev"}}
    end

    test "keeps false and converts other atoms to strings" do
      assert Location.normalise_data(%{no_expiry: false, travel_mode: :Truck}) ==
               %{"NoExpiry" => false, "TravelMode" => "Truck"}
    end

    test "base64 encodes a geobuf" do
      geobuf = <<10, 0, 255, 16>>

      assert Location.normalise_data(%GeofenceGeometry{geobuf: geobuf}) ==
               %{"Geobuf" => Base.encode64(geobuf)}

      assert Location.normalise_data(%GeofenceGeometry{
               circle: %Circle{center: [1.0, 2.0], radius: 10}
             }) == %{"Circle" => %{"Center" => [1.0, 2.0], "Radius" => 10}}
    end
  end

  describe "json_request/5" do
    test "splits options between the body and the query string" do
      assert %JSON{} =
               op =
               Location.json_request(
                 :places_v2,
                 :post,
                 "/v2/geocode",
                 [query_text: "x", key: "k"],
                 body: [:query_text],
                 query: [key: "key"]
               )

      assert op.http_method == :post
      assert op.service == :places_v2
      assert op.path == "/v2/geocode"
      assert op.data == %{"QueryText" => "x"}
      assert op.params == [{"key", "k"}]
    end

    test "merges required members and ignores nil options" do
      op =
        Location.json_request(:tracking_cp, :post, "/p", [description: nil, kms_key_id: "k"],
          required_body: %{"TrackerName" => "t"},
          body: [:description, :kms_key_id]
        )

      assert op.data == %{"TrackerName" => "t", "KmsKeyId" => "k"}
      assert op.params == []
    end

    test "raises on an unknown option" do
      assert_raise ArgumentError, ~r/unknown option :descripton.*:description/, fn ->
        Location.json_request(:tracking_cp, :post, "/p", [descripton: "typo"],
          body: [:description]
        )
      end
    end

    test "generates an idempotency token unless one is given" do
      spec = [body: [:client_token], idempotency_token: :client_token]

      assert %{"ClientToken" => token} =
               Location.json_request(:metadata, :post, "/p", [], spec).data

      assert token =~ ~r/^[0-9a-f]{8}-[0-9a-f]{4}-4[0-9a-f]{3}-[89ab][0-9a-f]{3}-[0-9a-f]{12}$/

      assert Location.json_request(:metadata, :post, "/p", [client_token: "mine"], spec).data ==
               %{"ClientToken" => "mine"}
    end
  end

  describe "rest_request/5" do
    test "repeats list valued query parameters" do
      assert %RestQuery{} =
               op =
               Location.rest_request(:metadata_cp, :delete, "/tags/x", [force: true],
                 required_query: [{"tagKeys", ["a", "b"]}],
                 query: [force: "force"]
               )

      assert op.params == [{"tagKeys", "a"}, {"tagKeys", "b"}, {"force", "true"}]
    end

    test "rejects body members" do
      assert_raise ArgumentError, fn ->
        Location.rest_request(:metadata_cp, :get, "/x", [], body: [:description])
      end
    end
  end

  test "encode_path/1 escapes everything that isn't unreserved" do
    assert Location.encode_path("arn:aws:geo:eu-west-1:123456789012:tracker/My Tracker") ==
             "arn%3Aaws%3Ageo%3Aeu-west-1%3A123456789012%3Atracker%2FMy%20Tracker"

    assert Location.encode_path(14) == "14"
  end
end
