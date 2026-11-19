# Generates everything under lib/ex_aws/location/ (the service modules and the
# structs for the request data types) from the AWS API models published in
# botocore. Do not edit the generated files by hand: change this script and
# re-run it instead. lib/ex_aws/location.ex is hand-written and is not touched.
#
#   elixir scripts/generate.exs               # downloads the latest models
#   elixir scripts/generate.exs <models dir>  # uses location.json, geo-maps.json,
#                                             # geo-places.json and geo-routes.json
#                                             # from the given directory
#
# The script raises if the models contain something it doesn't know how to
# handle (a new blob member, a name that doesn't survive snake-casing, a new
# Location endpoint prefix and so on), rather than generating something wrong.

defmodule Gen do
  @root "ExAws.Location"

  @groups %{
    "Geofences" => %{
      model: "location",
      title: "Amazon Location Service Geofences",
      blurb:
        "Geofence collections and the geofences stored in them, plus evaluating and " <>
          "forecasting device positions against those geofences.",
      index: "https://docs.aws.amazon.com/location/previous/APIReference/API_Operations.html"
    },
    "Trackers" => %{
      model: "location",
      title: "Amazon Location Service Trackers",
      blurb: "Tracker resources and the device positions sent to and retrieved from them.",
      index: "https://docs.aws.amazon.com/location/previous/APIReference/API_Operations.html"
    },
    "Keys" => %{
      model: "location",
      title: "Amazon Location Service API keys",
      blurb:
        "API key resources, used to grant unauthenticated access to maps, places and routes.",
      index: "https://docs.aws.amazon.com/location/previous/APIReference/API_Operations.html"
    },
    "Jobs" => %{
      model: "location",
      title: "Amazon Location Service jobs",
      blurb: "Asynchronous bulk processing jobs.",
      index: "https://docs.aws.amazon.com/location/previous/APIReference/API_Operations.html"
    },
    "Tags" => %{
      model: "location",
      title: "Amazon Location Service resource tagging",
      blurb: "Tags on Amazon Location resources (geofence collections, trackers, API keys, ...).",
      index: "https://docs.aws.amazon.com/location/previous/APIReference/API_Operations.html"
    },
    "Maps" => %{
      model: "geo-maps",
      title: "Amazon Location Service Maps (the `geo-maps` API)",
      blurb:
        "Map tiles, style descriptors, sprites, glyphs and static map images.\n\n" <>
          "These operations return binary or non-JSON payloads, so the response is returned " <>
          "unparsed: `{:ok, %{status_code: 200, headers: headers, body: body}}`.",
      index:
        "https://docs.aws.amazon.com/location/latest/APIReference/API_Operations_Amazon_Location_Service_Maps_V2.html"
    },
    "Places" => %{
      model: "geo-places",
      title: "Amazon Location Service Places (the `geo-places` API)",
      blurb: "Geocoding, reverse geocoding, place search, autocomplete and suggestions.",
      index:
        "https://docs.aws.amazon.com/location/latest/APIReference/API_Operations_Amazon_Location_Service_Places_V2.html"
    },
    "Routes" => %{
      model: "geo-routes",
      title: "Amazon Location Service Routes (the `geo-routes` API)",
      blurb:
        "Route calculation, route matrices, isolines, waypoint optimisation and snap-to-roads.",
      index:
        "https://docs.aws.amazon.com/location/latest/APIReference/API_Operations_Amazon_Location_Service_Routes_V2.html"
    }
  }

  @job_ops ~w(StartJob GetJob ListJobs CancelJob)
  @tag_ops ~w(ListTagsForResource TagResource UntagResource)

  # {group, service atom} for an operation, or nil when out of scope
  def classify("location", name, op) do
    case get_in(op, ["endpoint", "hostPrefix"]) do
      "geofencing." -> {"Geofences", :geofencing}
      "cp.geofencing." -> {"Geofences", :geofencing_cp}
      "tracking." -> {"Trackers", :tracking}
      "cp.tracking." -> {"Trackers", :tracking_cp}
      "metadata." when name in @job_ops -> {"Jobs", :metadata}
      "cp.metadata." when name in @tag_ops -> {"Tags", :metadata_cp}
      "cp.metadata." -> {"Keys", :metadata_cp}
      p when p in ~w(maps. cp.maps. places. cp.places. routes. cp.routes.) -> nil
    end
  end

  def classify("geo-maps", _, _), do: {"Maps", :maps_v2}
  def classify("geo-places", _, _), do: {"Places", :places_v2}
  def classify("geo-routes", _, _), do: {"Routes", :routes_v2}

  def doc_url("location", name),
    do: "https://docs.aws.amazon.com/location/previous/APIReference/API_#{name}.html"

  def doc_url("geo-maps", name),
    do: "https://docs.aws.amazon.com/location/latest/APIReference/API_geomaps_#{name}.html"

  def doc_url("geo-places", name),
    do: "https://docs.aws.amazon.com/location/latest/APIReference/API_geoplaces_#{name}.html"

  def doc_url("geo-routes", name),
    do: "https://docs.aws.amazon.com/location/latest/APIReference/API_#{name}.html"

  # ---------------------------------------------------------------- naming

  def snake(name) do
    s = Macro.underscore(name)

    if Macro.camelize(s) != name do
      raise "#{name} does not round-trip through underscore/camelize (#{s})"
    end

    s
  end

  # ---------------------------------------------------------------- docs

  def first_para(nil), do: ""

  def first_para(html) do
    html |> String.split(~r{</p>}, parts: 2) |> hd() |> md() |> String.replace(~r/\s+/, " ")
  end

  def md(nil), do: ""

  def md(html) do
    html
    |> String.replace(~r{<a\s+href="([^"]*)"\s*>(.*?)</a>}s, fn m ->
      [_, href, text] = Regex.run(~r{<a\s+href="([^"]*)"\s*>(.*?)</a>}s, m)
      text = text |> String.replace(~r/<[^>]+>/, "") |> String.trim()
      "[#{text}](#{href})"
    end)
    |> String.replace(~r{<code>\s*(.*?)\s*</code>}s, "`\\1`")
    |> String.replace(~r{<li>\s*(<p>)?\s*}, "\n\n* ")
    |> String.replace(~r{</?(p|ul|ol|note|important)>}, "\n\n")
    |> String.replace(~r{<[^>]+>}, "")
    |> String.replace("&lt;", "<")
    |> String.replace("&gt;", ">")
    |> String.replace("&quot;", "\"")
    |> String.replace("&amp;", "&")
    |> String.replace(~r/[ \t]+/, " ")
    |> String.split(~r/\n\s*\n/)
    |> Enum.map(&(&1 |> String.replace(~r/\s+/, " ") |> String.trim()))
    |> Enum.reject(&(&1 in ["", "*"]))
    |> Enum.map_join("\n\n", &wrap(&1, 94))
  end

  # The model describes the wire format; we do the Base64 encoding ourselves
  def member_doc("GeofenceGeometry", "Geobuf", _) do
    "Geobuf is a compact binary encoding for geographic data that provides lossless " <>
      "compression of GeoJSON polygons. Pass the raw Geobuf binary: it is Base64-encoded " <>
      "for you when the request is built."
  end

  def member_doc(_, _, m), do: first_para(m["documentation"])

  def wrap(text, width) do
    indent = if String.starts_with?(text, "* "), do: "  ", else: ""

    text
    |> String.split(" ")
    |> Enum.reduce([""], fn word, [line | rest] ->
      cond do
        line == "" -> [word | rest]
        String.length(line) + 1 + String.length(word) > width -> [indent <> word, line | rest]
        true -> [line <> " " <> word | rest]
      end
    end)
    |> Enum.reverse()
    |> Enum.join("\n")
  end

  def bullet(name, text) do
    wrap("* `:#{name}` - #{text}", 94)
  end

  def heredoc(text, pad) do
    if String.contains?(text, ~s(""")), do: raise("doc contains heredoc terminator")

    body =
      text
      |> String.split("\n")
      |> Enum.map_join("\n", fn
        "" -> ""
        l -> pad <> l
      end)

    "~S\"\"\"\n" <> body <> "\n" <> pad <> "\"\"\""
  end

  # ---------------------------------------------------------------- types

  def type(shapes, name, modules) do
    s = shapes[name]

    case s["type"] do
      "structure" -> "#{Map.fetch!(modules, name)}.t()"
      "list" -> "[#{type(shapes, s["member"]["shape"], modules)}]"
      "map" -> "%{optional(String.t()) => #{type(shapes, s["value"]["shape"], modules)}}"
      "string" -> "String.t()"
      t when t in ["integer", "long"] -> "integer()"
      t when t in ["double", "float"] -> "number()"
      "boolean" -> "boolean()"
      "timestamp" -> "DateTime.t() | String.t()"
      "blob" -> "binary()"
    end
  end

  def enum_note(shapes, name) do
    s = shapes[name]

    case s do
      %{"type" => "string", "enum" => vals} ->
        shown = vals |> Enum.take(24) |> Enum.map_join(", ", &"`#{&1}`")
        more = if length(vals) > 24, do: ", ...", else: ""
        " Valid values: #{shown}#{more}."

      %{"type" => "list", "member" => %{"shape" => inner}} ->
        enum_note(shapes, inner)

      _ ->
        ""
    end
  end

  # ---------------------------------------------------------------- shape walk

  def nested_structs(shapes, name, acc, top \\ false) do
    s = shapes[name]

    case s["type"] do
      "structure" ->
        cond do
          not top and MapSet.member?(acc, name) ->
            acc

          true ->
            acc = if top, do: acc, else: MapSet.put(acc, name)

            Enum.reduce(s["members"] || %{}, acc, fn {_, m}, acc ->
              nested_structs(shapes, m["shape"], acc)
            end)
        end

      "list" ->
        nested_structs(shapes, s["member"]["shape"], acc)

      "map" ->
        nested_structs(shapes, s["value"]["shape"], acc)

      _ ->
        acc
    end
  end

  # ---------------------------------------------------------------- main

  @models ~w(location geo-maps geo-places geo-routes)
  @model_url "https://raw.githubusercontent.com/boto/botocore/develop/botocore/data"
  @model_version "2020-11-19"

  def run([]) do
    {:ok, _} = Application.ensure_all_started([:inets, :ssl])
    run(Map.new(@models, &{&1, download(&1)}))
  end

  def run([models_dir]) do
    run(Map.new(@models, &{&1, File.read!(Path.join(models_dir, "#{&1}.json"))}))
  end

  def run(sources) when is_map(sources) do
    out_root = Path.expand("..", __DIR__)

    # Everything in here is generated, so clear out anything that has gone stale
    File.rm_rf!(Path.join(out_root, "lib/ex_aws/location"))

    models = Map.new(sources, fn {name, json} -> {name, :json.decode(json)} end)

    # ops per group
    ops =
      for {mname, model} <- models,
          {name, op} <- model["operations"],
          c = classify(mname, name, op),
          do: {c, mname, name, op}

    # struct -> groups using it
    usage =
      Enum.reduce(ops, %{}, fn {{group, _}, mname, _, op}, acc ->
        shapes = models[mname]["shapes"]

        shapes
        |> nested_structs(op["input"]["shape"], MapSet.new(), true)
        |> Enum.reduce(acc, fn s, acc ->
          Map.update(acc, {mname, s}, MapSet.new([group]), &MapSet.put(&1, group))
        end)
      end)

    modules_by_model =
      Enum.reduce(usage, %{}, fn {{mname, s}, groups}, acc ->
        mod =
          case MapSet.to_list(groups) do
            [g] ->
              "#{@root}.#{g}.#{s}"

            _ ->
              if Map.has_key?(@groups, s), do: raise("shared type #{s} clashes with a group")
              "#{@root}.#{s}"
          end

        Map.update(acc, mname, %{s => mod}, &Map.put(&1, s, mod))
      end)

    all_mods = modules_by_model |> Map.values() |> Enum.flat_map(&Map.values/1)
    if length(all_mods) != length(Enum.uniq(all_mods)), do: raise("module name clash")

    # blobs must be handled by hand in ExAws.Location.normalise_data/1
    blobs =
      for {{mname, s}, _} <- usage,
          {mn, m} <- models[mname]["shapes"][s]["members"],
          models[mname]["shapes"][m["shape"]]["type"] == "blob",
          do: {s, mn}

    if blobs != [{"GeofenceGeometry", "Geobuf"}], do: raise("unexpected blobs #{inspect(blobs)}")

    # struct modules
    for {{mname, s}, _} <- usage do
      shapes = models[mname]["shapes"]
      modules = modules_by_model[mname]
      mod = modules[s]
      write(out_root, mod, struct_module(mname, shapes, modules, s, mod))
    end

    # group modules
    for {group, info} <- @groups do
      gops =
        ops
        |> Enum.filter(fn {{g, _}, _, _, _} -> g == group end)
        |> Enum.sort_by(fn {_, _, name, _} -> name end)

      shapes = models[info.model]["shapes"]
      modules = Map.get(modules_by_model, info.model, %{})
      mod = "#{@root}.#{group}"
      write(out_root, mod, group_module(group, info, gops, shapes, modules))
    end

    IO.puts("structs: #{map_size(usage)}, operations: #{length(ops)}")
  end

  defp download(model) do
    url = "#{@model_url}/#{model}/#{@model_version}/service-2.json"
    IO.puts("Downloading #{url}")

    http_opts = [
      ssl: [
        verify: :verify_peer,
        cacerts: :public_key.cacerts_get(),
        customize_hostname_check: [match_fun: :public_key.pkix_verify_hostname_match_fun(:https)]
      ]
    ]

    case :httpc.request(:get, {String.to_charlist(url), []}, http_opts, body_format: :binary) do
      {:ok, {{_, 200, _}, _headers, body}} -> body
      other -> raise "failed to download #{url}: #{inspect(other)}"
    end
  end

  def write(out_root, mod, code) do
    code = "# Generated by scripts/generate.exs. Do not edit.\n" <> code

    path =
      Path.join([out_root, "lib" | mod |> String.split(".") |> Enum.map(&Macro.underscore/1)]) <>
        ".ex"

    File.mkdir_p!(Path.dirname(path))
    # One pass of the formatter isn't always enough to reach its fixed point
    formatted = code |> Code.format_string!() |> IO.iodata_to_binary() |> Code.format_string!()
    File.write!(path, [formatted, "\n"])
  end

  # ---------------------------------------------------------------- structs

  def struct_module(mname, shapes, modules, name, mod) do
    s = shapes[name]
    required = MapSet.new(s["required"] || [])
    members = s["members"] |> Enum.reject(fn {_, m} -> m["deprecated"] end) |> Enum.sort()

    Enum.each(members, fn {_, m} ->
      if m["location"] || (m["locationName"] && false), do: raise("located member in #{name}")
    end)

    fields =
      Enum.map_join(members, "\n\n", fn {mn, m} ->
        req = if MapSet.member?(required, mn), do: "(required) ", else: ""
        bullet(snake(mn), req <> member_doc(name, mn, m) <> enum_note(shapes, m["shape"]))
      end)

    doc =
      [
        md(s["documentation"]),
        if(members == [], do: nil, else: "## Fields\n\n" <> fields),
        "See #{doc_url(mname, name)}"
      ]
      |> Enum.reject(&(&1 in [nil, ""]))
      |> Enum.join("\n\n")

    keys = Enum.map_join(members, ",\n", fn {mn, _} -> "    :#{snake(mn)}" end)

    types =
      Enum.map_join(members, ",\n", fn {mn, m} ->
        t = type(shapes, m["shape"], modules)
        t = if MapSet.member?(required, mn), do: t, else: t <> " | nil"
        "          #{snake(mn)}: #{t}"
      end)

    """
    defmodule #{mod} do
      @moduledoc #{heredoc(doc, "  ")}

      defstruct [
    #{keys}
      ]

      @type t :: %__MODULE__{
    #{types}
            }
    end
    """
  end

  # ---------------------------------------------------------------- operations

  def group_module(group, info, gops, shapes, modules) do
    services = gops |> Enum.map(fn {{_, svc}, _, _, _} -> svc end) |> Enum.uniq() |> Enum.sort()

    attr = fn svc ->
      if String.ends_with?(to_string(svc), "_cp"), do: "@control_plane", else: "@service"
    end

    attrs =
      Enum.map_join(services, "\n", fn svc -> "  #{attr.(svc)} #{inspect(svc)}" end)

    funs =
      Enum.map_join(gops, "\n", fn {{_, svc}, mname, name, op} ->
        operation(mname, name, op, attr.(svc), shapes, modules, group)
      end)

    ops_list =
      Enum.map_join(gops, "\n", fn {_, _, name, _} -> "* `#{snake(name)}` - #{name}" end)

    doc =
      "API calls for #{info.title}.\n\n#{info.blurb}\n\n" <>
        "Every function returns an operation struct to be passed to `ExAws.request/2`.\n\n" <>
        "## Operations\n\n#{ops_list}\n\nSee #{info.index}"

    kinds = gops |> Enum.map(fn {_, _, _, op} -> op_kind(group, op) end) |> Enum.uniq()

    aliases =
      ["  alias ExAws.Location"] ++
        if(:json in kinds, do: ["  alias ExAws.Operation.JSON"], else: []) ++
        if(Enum.any?(kinds, &(&1 != :json)), do: ["  alias ExAws.Operation.RestQuery"], else: [])

    """
    defmodule #{@root}.#{group} do
      @moduledoc #{heredoc(doc, "  ")}

    #{Enum.join(aliases, "\n")}

    #{attrs}

    #{funs}end
    """
  end

  def op_kind("Maps", _), do: :raw

  def op_kind(_, op) do
    if op["http"]["method"] in ~w(POST PUT PATCH), do: :json, else: :rest
  end

  def operation(mname, name, op, svc_attr, shapes, modules, group) do
    input = shapes[op["input"]["shape"]]
    members = input["members"] |> Enum.reject(fn {_, m} -> m["deprecated"] end) |> Map.new()
    required = input["required"] || []
    uri = op["http"]["requestUri"]
    method = op["http"]["method"] |> String.downcase()
    kind = op_kind(group, op)

    uri_labels = Regex.scan(~r/\{(\w+)\}/, uri) |> Enum.map(&List.last/1)

    by_label =
      for {mn, m} <- members, m["location"] == "uri", into: %{}, do: {m["locationName"] || mn, mn}

    uri_members = Enum.map(uri_labels, &Map.fetch!(by_label, &1))
    Enum.each(uri_members, fn mn -> if mn not in required, do: raise("optional uri #{mn}") end)

    positional = uri_members ++ Enum.reject(required, &(&1 in uri_members))
    optional = members |> Map.keys() |> Enum.reject(&(&1 in positional)) |> Enum.sort()

    Enum.each(members, fn {mn, m} ->
      if m["location"] not in [nil, "uri", "querystring"], do: raise("location #{mn}")
      if m["location"] == nil and kind != :json, do: raise("body member #{mn} on #{name}")
    end)

    query? = fn mn -> members[mn]["location"] == "querystring" end
    wire = fn mn -> members[mn]["locationName"] || mn end

    path =
      Enum.reduce(uri_labels, uri, fn label, acc ->
        String.replace(
          acc,
          "{#{label}}",
          "\#{Location.encode_path(#{snake(by_label[label])})}"
        )
      end)

    req_body =
      positional
      |> Enum.reject(&(&1 in uri_members or query?.(&1)))
      |> Enum.map_join(", ", &"#{inspect(&1)} => #{snake(&1)}")

    req_query =
      positional
      |> Enum.filter(query?)
      |> Enum.map_join(", ", &"{#{inspect(wire.(&1))}, #{snake(&1)}}")

    opt_body = optional |> Enum.reject(query?) |> Enum.map_join(", ", &":#{snake(&1)}")

    opt_query =
      optional
      |> Enum.filter(query?)
      |> Enum.map_join(", ", &"#{snake(&1)}: #{inspect(wire.(&1))}")

    token =
      Enum.find(Map.keys(members), fn mn ->
        members[mn]["idempotencyToken"] || shapes[members[mn]["shape"]]["idempotencyToken"]
      end)

    spec =
      [
        req_body != "" && "required_body: %{#{req_body}}",
        req_query != "" && "required_query: [#{req_query}]",
        opt_body != "" && "body: [#{opt_body}]",
        opt_query != "" && "query: [#{opt_query}]",
        token && "idempotency_token: :#{snake(token)}"
      ]
      |> Enum.filter(& &1)
      |> Enum.join(", ")

    fname = snake(name)
    has_opts = optional != []
    args = Enum.map(positional, &snake/1) ++ if(has_opts, do: ["opts \\\\ []"], else: [])
    arg_types = Enum.map(positional, &type(shapes, members[&1]["shape"], modules))

    opts_type =
      if has_opts do
        alts =
          Enum.map_join(optional, " | ", fn mn ->
            "{:#{snake(mn)}, #{type(shapes, members[mn]["shape"], modules)}}"
          end)

        "  @type #{fname}_opts :: [#{alts}]\n"
      else
        ""
      end

    spec_args = arg_types ++ if(has_opts, do: ["#{fname}_opts()"], else: [])
    ret = if kind == :json, do: "JSON.t()", else: "RestQuery.t()"

    builder =
      case kind do
        :json -> "json_request"
        :rest -> "rest_request"
        :raw -> "raw_request"
      end

    params_doc =
      if positional == [] do
        nil
      else
        "## Parameters\n\n" <>
          Enum.map_join(positional, "\n\n", fn mn ->
            wrap(
              "* `#{snake(mn)}` - " <>
                first_para(members[mn]["documentation"]) <>
                enum_note(shapes, members[mn]["shape"]),
              94
            )
          end)
      end

    opts_doc =
      if has_opts do
        "## Options\n\n" <>
          Enum.map_join(optional, "\n\n", fn mn ->
            bullet(
              snake(mn),
              first_para(members[mn]["documentation"]) <> enum_note(shapes, members[mn]["shape"])
            )
          end)
      end

    doc =
      [md(op["documentation"]), params_doc, opts_doc, "See #{doc_url(mname, name)}"]
      |> Enum.reject(&(&1 in [nil, ""]))
      |> Enum.join("\n\n")

    call_opts = if has_opts, do: "opts", else: "[]"
    spec = if spec == "", do: "", else: ", " <> spec

    """
    #{opts_type}
      @doc #{heredoc(doc, "  ")}
      @spec #{fname}(#{Enum.join(spec_args, ", ")}) :: #{ret}
      def #{fname}(#{Enum.join(args, ", ")}) do
        Location.#{builder}(#{svc_attr}, :#{method}, "#{path}", #{call_opts}#{spec})
      end
    """
  end
end

Gen.run(System.argv())
