defmodule AbsinthePlugCache.Plug.DocumentProvider.Default do
  @moduledoc """
  This is the default document provider, implementing the
  `AbsinthePlugCache.Plug.DocumentProvider` behaviour.

  This document provider will handle any document that's provided:

  - As the body of an HTTP POST with content-type `application/graphql`
  - As the parsed `"query"` parameter in an HTTP POST of content-type `application/json`
  - As the `"query"` parameter in an HTTP GET query string

  (Note that the parsing itself happens in `AbsinthePlugCache.Plug.Parser` /
  `AbsinthePlugCache.Plug`; this document provider just knows how to work with the
  value.)

  ## Configuring

  By default, this is the only document provider configured by `AbsinthePlugCache.Plug.init/1`.

  Using the `:document_providers` option, however, you can:

  - Add additional document providers to expand the ways that documents can be loaded.
    See, for example, `AbsinthePlugCache.Plug.DocumentProvider.Compiled`.
  - Remove this document provider from the configuration to disallow ad hoc queries.

  See the documentation on `AbsinthePlugCache.Plug.init/1` for more details on the
  `:document_providers` option.

  """

  @behaviour AbsinthePlugCache.Plug.DocumentProvider

  @doc false
  @spec pipeline(AbsinthePlugCache.Plug.Request.Query.t()) :: Absinthe.Pipeline.t()
  def pipeline(%{pipeline: as_configured}), do: as_configured

  @doc false
  @spec process(AbsinthePlugCache.Plug.Request.Query.t(), Keyword.t()) ::
          AbsinthePlugCache.Plug.DocumentProvider.result()
  def process(%{document: nil} = query, _), do: {:cont, query}
  def process(%{document: _} = query, _), do: {:halt, query}
end
