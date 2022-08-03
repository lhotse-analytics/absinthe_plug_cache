defmodule Mix.AbsinthePlugCache.Plug.GraphiQL.AssetsTask do
  def run(_args) do
    if Mix.Project.umbrella?(),
      do: Mix.raise("mix absinthe.plug.graphiql.assets.download can only be run inside an application directory")

    AbsinthePlugCache.Plug.GraphiQL.Assets.assets_config()
  end
end
