defmodule Algolia.Client do
  alias Algolia.Protocol
  alias Algolia.Error.AlgoliaProtocolError
  @application_id Application.get_env(:algolia, :application_id)
  @api_key Application.get_env(:algolia, :api_key)

  @hosts [
    "#{@application_id}.algolia.net"
    | Enum.shuffle(Enum.map(1..3, fn i -> "#{@application_id}-#{i}.algolianet.com" end))
  ]
  @search_hosts [
    "#{@application_id}-dsn.algolia.net"
    | Enum.shuffle(Enum.map(1..3, fn i -> "#{@application_id}-#{i}.algolianet.com" end))
  ]

  @wait_task_default_time_before_retry 100

  @request_headers [
    {"Content-type", "application/json"},
    {"X-Algolia-API-Key", @api_key},
    {"X-Algolia-Application-Id", @application_id}
  ]

  def request(uri, method, data \\ %{}, type \\ :write, request_options \\ %{})

  def request(uri, method, data, type, request_options) when type in [:write, :batch] do
    with {:ok, body} <- Jason.encode(data) do
      request_hosts(@hosts, method, uri, build_headers(request_options), body)
    end
  end

  def request(uri, method, data, _, request_options) do
    with {:ok, body} <- Jason.encode(data) do
      request_hosts(@search_hosts, method, uri, build_headers(request_options), body)
    end
  end

  def request_hosts(hosts, method, uri, headers, body) do
    Enum.reduce_while(hosts, {:error, []}, fn host, {_status, acc} ->
      case build_and_request(method, build_url(host, uri), headers, body) do
        {:ok, body} ->
          {:halt, {:ok, body}}

        {:error, %AlgoliaProtocolError{code: status_code} = reason} when div(status_code, 100) === 4 ->
          {:halt, {:error, reason}}

        {:error, %AlgoliaProtocolError{} = reason} ->
          {:cont, {:error, [reason | acc]}}

        {:error, reason} ->
          {:halt, {:error, reason}}
      end
    end)
  end

  def get_task_status(index_name, task_id, request_options \\ %{}) do
    index_name
    |> Protocol.task_uri(task_id)
    |> get(:read, request_options)
  end

  def wait_task(
        index_name,
        task_id,
        time_before_retry \\ @wait_task_default_time_before_retry,
        request_options \\ %{}
      ) do
    with {:ok, response} <- get_task_status(index_name, task_id, request_options) do
      case response["status"] do
        "published" ->
          {:ok, task_id}

        _ ->
          :timer.sleep(time_before_retry)
          wait_task(index_name, task_id, time_before_retry, request_options)
      end
    end
  end

  def get(uri, type \\ :write, request_options \\ %{}) do
    request(uri, :get, %{}, type, request_options)
  end

  def post(uri, body \\ %{}, type \\ :write, request_options \\ %{}) do
    request(uri, :post, body, type, request_options)
  end

  def put(uri, body \\ %{}, type \\ :write, request_options \\ %{}) do
    request(uri, :put, body, type, request_options)
  end

  def delete(uri, type \\ :write, request_options \\ %{}) do
    request(uri, :delete, %{}, type, request_options)
  end

  def build_url(host, uri) do
    "https://" <> host <> uri
  end

  def build_headers(%{headers: extra_headers}) do
    Keyword.merge(@request_headers, extra_headers)
  end

  def build_headers(_) do
    @request_headers
  end

  defp build_and_request(method, url, headers, body, opts \\ []) do
    case Finch.request(Finch.build(method, url, headers, body), Algolia.Finch, opts) do
      {:ok, %Finch.Response{status: status, body: body}} when div(status, 100) === 2 ->
        Jason.decode(body)

      {:ok, %Finch.Response{status: status, body: body}} ->
        {:error,
         %AlgoliaProtocolError{
           code: status,
           message: "Cannot #{method} to #{url}: #{body} (#{status})"
         }}

      {:error, error} ->
        {:error, error}
    end
  end
end
