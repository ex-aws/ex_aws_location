defmodule ExAws.Location.TestClient do
  @moduledoc """
  HTTP client that sends each request to the test process instead of AWS, and
  replies with whatever response the test has registered (an empty JSON object
  by default).
  """

  @behaviour ExAws.Request.HttpClient

  def respond_with(response), do: Process.put(__MODULE__, response)

  @impl true
  def request(method, url, body, headers, _http_opts) do
    send(self(), {:request, %{method: method, url: url, body: body, headers: Map.new(headers)}})
    Process.get(__MODULE__, {:ok, %{status_code: 200, headers: [], body: "{}"}})
  end
end

defmodule ExAws.Location.TestHelper do
  @moduledoc false

  import ExUnit.Assertions

  @doc """
  Performs the operation against `ExAws.Location.TestClient` and returns
  `{result, request}`, with the request's URL parsed and its JSON body decoded.
  """
  def request(operation, overrides \\ []) do
    config =
      Keyword.merge(
        [
          http_client: ExAws.Location.TestClient,
          access_key_id: "AKIAIOSFODNN7EXAMPLE",
          secret_access_key: "wJalrXUtnFEMI/K7MDENG/bPxRfiCYEXAMPLEKEY",
          region: "eu-west-1",
          retries: [max_attempts: 1]
        ],
        overrides
      )

    result = ExAws.request(operation, config)
    assert_received {:request, request}

    uri = URI.parse(request.url)

    request =
      request
      |> Map.put(:host, uri.host)
      |> Map.put(:path, uri.path)
      |> Map.put(:query, uri.query)
      |> Map.put(:json, decode(request.body))

    {result, request}
  end

  @doc "The service name the request was signed for"
  def signing_name(request) do
    [_, name] = Regex.run(~r{Credential=[^/]+/\d+/[^/]+/([^/]+)/aws4_request}, auth(request))
    name
  end

  defp auth(%{headers: headers}), do: headers["Authorization"]

  defp decode(""), do: nil
  defp decode(body), do: Jason.decode!(body)
end

ExUnit.start()
