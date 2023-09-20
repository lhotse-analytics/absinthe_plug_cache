defmodule AbsinthePlugCache.Plug.Cache do
  @moduledoc false

  @cache_name :graphql_cache

  @doc """
  get the params for the cache
  """
  def get_params(%{"query" => query, "variables" => variables}, current_user_id, hostname) do
    query = query |> String.split(["query", "("]) |> Enum.at(1) |> String.trim()
    variables = variables |> Map.drop(["cache"])

    %{"cache_query" => query, "cache_current_user_id" => current_user_id} |> Map.merge(variables) |> Map.put("hostname", hostname)
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
  def get(params, pid, buffer \\ 0) do
    params |> Map.merge(%{"buffer" => buffer}) |> get_cache_entries(pid) |> List.first()
  end

  def get_by_key(key, nil) do
    ConCache.get(@cache_name, key)
  end

  def get_by_key(key, pid) do
    Redix.command!(pid, ["GET", key])
  end

  defp get_cache_entries(params, nil) do
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

  defp get_cache_entries(params, pid) do
    key = params |> hash()
    [{key, Redix.command!(pid, ["GET", key])}]
  end

  @doc """
  get the contents of the cache
  """
  def get_cache(nil) do
    ConCache.ets(@cache_name) |> :ets.tab2list()
  end

  def get_cache(pid) do
    # get all key value pairs
    Redix.command(pid, ["KEYS", "*"])
    |> case do
      {:ok, keys} -> keys
      _any -> []
    end
    |> Enum.map(fn key ->
      {key |> unhash(), Redix.command!(pid, ["GET", key])}
    end)
  end

  @doc """
  build cache key
  """
  def build_key(params, buffer), do: params |> Map.merge(%{"buffer" => buffer}) |> hash()

  @doc """
  put json into cache
  """
  def store(json, key, nil) do
    ConCache.put(@cache_name, key, json)
  end

  def store(json, key, pid) do
    Redix.command!(pid, ["SET", key, json])
  end

  @doc """
  Invalidate all cache entries for a query having these arguments
  """
  def invalidate(params, nil) do
    get_cache_entries(params, nil)
    |> Enum.each(fn key -> ConCache.delete(@cache_name, key |> hash()) end)
  end

  def invalidate(params, pid) do
    get_cache_entries(params, pid)
    |> Enum.each(fn {key, _value} -> Redix.command!(pid, ["DEL", key]) end)
  end

  @doc """
  Invalidate all cache entries for a query having these arguments
  """
  def invalidate_all(pid) do
    # get all key value pairs
    Redix.command(pid, ["KEYS", "*"])
    |> case do
      {:ok, keys} -> keys
      _any -> []
    end
    |> Enum.each(fn key -> Redix.command!(pid, ["DEL", key]) end)
  end

  def invalidate_key(key, nil) do
    ConCache.delete(@cache_name, key)
  end

  def invalidate_key(key, pid) do
    Redix.command!(pid, ["DEL", key])
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
