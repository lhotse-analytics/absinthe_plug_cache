defmodule AbsinthePlugCache.Plug.Cache do
  @moduledoc false

  @cache_name :graphql_cache

  @doc """
  get the params for the cache
  """
  def get_params(%{"query" => query, "variables" => variables}, current_user_id) do
    query = query |> String.split(["query", "("]) |> Enum.at(1) |> String.trim()
    variables = variables |> Map.drop(["cache"])

    %{"cache_query" => query, "cache_current_user_id" => current_user_id} |> Map.merge(variables)
  end

  @doc """
  check if the request should be cached or not or invalidated and cached again
  """
  def cache_type(%Plug.Conn{params: %{"variables" => %{"cache" => "get"}}}), do: "get"

  def cache_type(%Plug.Conn{params: %{"variables" => %{"cache" => "invalidate"}}}),
    do: "invalidate"

  def cache_type(_any), do: nil

  @doc """
  get cached json
  """
  def get(params, buffer \\ 0) do
    params |> Map.merge(%{"buffer" => buffer}) |> get_cache_entries() |> List.first()
  end

  def get_by_key(key) do
    ConCache.get(@cache_name, key)
  end

  defp get_cache_entries(params) do
    # get the ets table of the cache
    ConCache.ets(@cache_name)
    # get the contents of the cache
    |> :ets.tab2list()
    |> Enum.map(fn {key, cached_value} -> {key |> unhash(), cached_value} end)
    |> Enum.filter(fn {cached_args, _cached_value} -> params |> Enum.into([]) |> same_args?(cached_args) end)
    |> Enum.map(fn {cached_args, cached_value} ->
      key = cached_args |> hash()
      {key, cached_value}
    end)
  end

  @doc """
  get the contents of the cache
  """
  def get_cache do
    ConCache.ets(@cache_name) |> :ets.tab2list()
  end

  @doc """
  build cache key
  """
  def build_key(params, buffer), do: params |> Map.merge(%{"buffer" => buffer}) |> hash()

  @doc """
  put json into cache
  """
  def store(json, key) do
    ConCache.put(@cache_name, key, json)
  end

  @doc """
  Invalidate all cache entries for a query having these arguments
  """
  def invalidate(params) do
    get_cache_entries(params)
    |> Enum.each(fn key -> ConCache.delete(@cache_name, key |> hash()) end)
  end

  @doc """
  Invalidate all cache entries for a query having these arguments
  """
  def invalidate_all do
    @cache_name
    |> ConCache.ets()
    |> :ets.tab2list()
    |> Enum.each(fn {key, _} -> ConCache.delete(@cache_name, key) end)
  end

  def invalidate_key(key) do
    ConCache.delete(@cache_name, key)
  end

  defp same_args?([], _cached_args), do: true

  defp same_args?(params, cached_args) do
    params
    |> Enum.find(fn {key, value} -> cached_args |> Map.get(key) != value end)
    |> case do
      nil -> true
      _entry -> false
    end
  end

  defp hash(data), do: data |> :erlang.term_to_binary() |> Base.encode64()
  defp unhash(hash), do: hash |> Base.decode64!() |> :erlang.binary_to_term()
end
