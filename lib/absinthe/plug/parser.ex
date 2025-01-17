defmodule AbsinthePlugCache.Plug.Parser do
  @moduledoc """
  Extracts the GraphQL request body.

  For use with `Plug.Parsers`, as in the example below.

  ## Examples

  Should be used with `Plug.Parsers`, before `AbsinthePlugCache.Plug`:

      plug Plug.Parsers,
        parsers: [:urlencoded, :multipart, :json, AbsinthePlugCache.Plug.Parser],
        pass: ["*/*"],
        json_decoder: Jason

      plug AbsinthePlugCache.Plug,
        schema: MyAppWeb.Schema
  """

  @behaviour Plug.Parsers

  @doc false
  def init(opts), do: opts

  @doc false
  def parse(conn, "application", "graphql", _headers, opts) do
    case Plug.Conn.read_body(conn, opts) do
      {:ok, body, conn} ->
        {:ok, %{"query" => body}, conn}

      {:more, _data, conn} ->
        {:error, :too_large, conn}

      {:error, :timeout} ->
        raise Plug.TimeoutError

      {:error, _} ->
        raise Plug.BadRequestError
    end
  end

  def parse(conn, _type, _subtype, _headers, _opts) do
    {:next, conn}
  end
end
