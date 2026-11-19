defmodule ExAws.Location do
  @moduledoc """
  Amazon Location Service support for ExAws.

  The API is split up by service, with one module for each:

    * `ExAws.Location.Maps` - map tiles, styles, sprites, glyphs and static maps (`geo-maps`)
    * `ExAws.Location.Places` - geocoding and place search (`geo-places`)
    * `ExAws.Location.Routes` - routes, route matrices, isolines and more (`geo-routes`)
    * `ExAws.Location.Geofences` - geofence collections and geofences
    * `ExAws.Location.Trackers` - trackers and device positions
    * `ExAws.Location.Keys` - API keys
    * `ExAws.Location.Jobs` - bulk processing jobs
    * `ExAws.Location.Tags` - resource tagging

  Each function builds an operation which is then passed to `ExAws.request/2`:

      "my-tracker"
      |> ExAws.Location.Trackers.create_tracker(description: "Delivery vans")
      |> ExAws.request(region: "eu-west-1")

  Required parameters are positional. Optional parameters are passed as a keyword
  list, using the snake_case form of the name given in the AWS API reference (so
  `KmsKeyId` becomes `:kms_key_id`). Passing an option the operation doesn't know
  about raises an `ArgumentError`.

  Nested request data types each have their own struct, for example
  `ExAws.Location.DevicePositionUpdate`. Timestamps may be given as `DateTime`
  structs or as ISO 8601 strings.

  This module holds the helpers shared by the service modules.
  """

  alias ExAws.Location.Geofences.GeofenceGeometry
  alias ExAws.Operation.JSON
  alias ExAws.Operation.RestQuery

  @typedoc """
  Describes how the arguments of an operation map on to the request.

    * `:required_body` - map of wire name to value for required body members
    * `:required_query` - list of `{wire name, value}` for required query string parameters
    * `:body` - names of the options sent in the request body
    * `:query` - keyword list of option name to query string parameter name
    * `:idempotency_token` - name of a body option that is generated when not supplied
  """
  @type spec :: [
          required_body: %{optional(String.t()) => term()},
          required_query: [{String.t(), term()}],
          body: [atom()],
          query: [{atom(), String.t()}],
          idempotency_token: atom()
        ]

  @doc """
  Builds an operation that sends a JSON body and expects a JSON response.
  """
  @spec json_request(atom(), atom(), String.t(), keyword(), spec()) :: JSON.t()
  def json_request(service, method, path, opts, spec \\ []) do
    {query, body} = split_opts(opts, spec)

    data =
      spec
      |> Keyword.get(:required_body, %{})
      |> Map.merge(body)
      |> put_idempotency_token(spec[:idempotency_token])
      |> normalise_data()

    %JSON{
      http_method: method,
      service: service,
      path: path,
      params: query_params(spec, query),
      data: data,
      headers: [{"content-type", "application/json"}]
    }
  end

  @doc """
  Builds a body-less operation (`GET` or `DELETE`) that expects a JSON response.
  """
  @spec rest_request(atom(), atom(), String.t(), keyword(), spec()) :: RestQuery.t()
  def rest_request(service, method, path, opts, spec \\ []) do
    build_rest_request(service, method, path, opts, spec, &parse_json/2)
  end

  @doc """
  Builds a body-less operation whose response is returned as is.

  This is used for operations that return something other than a JSON document,
  such as map tiles.
  """
  @spec raw_request(atom(), atom(), String.t(), keyword(), spec()) :: RestQuery.t()
  def raw_request(service, method, path, opts, spec \\ []) do
    build_rest_request(service, method, path, opts, spec, &parse_raw/2)
  end

  defp build_rest_request(service, method, path, opts, spec, parser) do
    if Keyword.has_key?(spec, :body) or Keyword.has_key?(spec, :required_body) do
      raise ArgumentError, "#{method} #{path} cannot have a request body"
    end

    {query, _body} = split_opts(opts, spec)

    %RestQuery{
      http_method: method,
      service: service,
      path: path,
      params: query_params(spec, query),
      parser: parser
    }
  end

  @doc """
  Percent-encodes a value for use as a single segment of a request path.
  """
  @spec encode_path(term()) :: String.t()
  def encode_path(value) do
    value |> to_string() |> URI.encode(&URI.char_unreserved?/1)
  end

  @doc """
  Converts request data in to the form expected by the AWS API.

  Structs and maps with atom keys have their keys converted from `:snake_case` to
  `"CamelCase"` and any `nil` values dropped. String keys (for example in tags) are
  left untouched. `DateTime` values are converted to ISO 8601 strings.
  """
  @spec normalise_data(term()) :: term()
  def normalise_data(%DateTime{} = datetime), do: DateTime.to_iso8601(datetime)

  # Geobuf is a blob, which is sent base64 encoded
  def normalise_data(%GeofenceGeometry{geobuf: geobuf} = geometry) when is_binary(geobuf) do
    geometry
    |> Map.from_struct()
    |> Map.delete(:geobuf)
    |> normalise_data()
    |> Map.put("Geobuf", Base.encode64(geobuf))
  end

  def normalise_data(%_{} = struct), do: struct |> Map.from_struct() |> normalise_data()

  def normalise_data(map) when is_map(map) do
    Enum.reduce(map, %{}, fn
      {_k, nil}, acc -> acc
      {k, v}, acc when is_atom(k) -> Map.put(acc, Macro.camelize(to_string(k)), normalise_data(v))
      {k, v}, acc -> Map.put(acc, k, normalise_data(v))
    end)
  end

  def normalise_data(list) when is_list(list), do: Enum.map(list, &normalise_data/1)
  def normalise_data(value) when is_boolean(value), do: value
  def normalise_data(value) when is_atom(value), do: to_string(value)
  def normalise_data(value) when is_binary(value) or is_number(value), do: value

  # Splits the caller's options in to query string parameters and body members
  defp split_opts(opts, spec) do
    body_keys = Keyword.get(spec, :body, [])
    query_keys = Keyword.get(spec, :query, [])

    Enum.reduce(opts, {[], %{}}, fn
      {_key, nil}, acc ->
        acc

      {key, value}, {query, body} ->
        cond do
          Keyword.has_key?(query_keys, key) ->
            {[{Keyword.fetch!(query_keys, key), value} | query], body}

          key in body_keys ->
            {query, Map.put(body, key, value)}

          true ->
            valid = Enum.sort(body_keys ++ Keyword.keys(query_keys))

            raise ArgumentError,
                  "unknown option #{inspect(key)}, expected one of: #{inspect(valid)}"
        end
    end)
  end

  # List values become a repeated parameter, e.g. `tagKeys=a&tagKeys=b`
  defp query_params(spec, query) do
    spec
    |> Keyword.get(:required_query, [])
    |> Kernel.++(Enum.reverse(query))
    |> Enum.flat_map(fn
      {name, values} when is_list(values) -> Enum.map(values, &{name, query_value(&1)})
      {name, value} -> [{name, query_value(value)}]
    end)
  end

  defp query_value(%DateTime{} = datetime), do: DateTime.to_iso8601(datetime)
  defp query_value(value), do: to_string(value)

  defp put_idempotency_token(body, nil), do: body
  defp put_idempotency_token(body, key), do: Map.put_new_lazy(body, key, &uuid4/0)

  defp uuid4 do
    <<a::32, b::16, _::4, c::12, _::2, d::14, e::48>> = :crypto.strong_rand_bytes(16)

    <<a::32, b::16, 4::4, c::12, 2::2, d::14, e::48>>
    |> Base.encode16(case: :lower)
    |> then(fn <<a::binary-8, b::binary-4, c::binary-4, d::binary-4, e::binary-12>> ->
      Enum.join([a, b, c, d, e], "-")
    end)
  end

  defp parse_json({:ok, %{body: ""}}, _action), do: {:ok, %{}}
  defp parse_json({:ok, %{body: body}}, _action), do: Jason.decode(body)
  defp parse_json({:error, error}, _action), do: {:error, error}

  defp parse_raw(result, _action), do: result
end
