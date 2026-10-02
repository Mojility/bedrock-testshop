defmodule Business.Website.Components do
  @moduledoc "Customer-owned native renderers. Names must also exist in components.json."
  # Register explicit functions, for example: %{"service_list" => &BusinessWeb.ServiceList.render/1}.
  # Each receives %{node: %{props: ...}, state: %{content: ...}} as Phoenix assigns.
  def native, do: %{}
end
