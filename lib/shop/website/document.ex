defmodule Shop.Website.Document do
  @moduledoc "Reads the stored website document owned by this application."

  @type t :: %{optional(String.t()) => term()}

  alias Shop.Website.{Tree, ComponentModel}
  def tree(document), do: Tree.from_stored(get_in(document, ["page", "nodes"]))
  def components(document), do: ComponentModel.entries(document["component_model"])

  def title(document),
    do: get_in(document, ["page", "title"]) || get_in(document, ["facts", "name"]) || "Website"

  def description(document), do: get_in(document, ["page", "description"]) || title(document)
end
