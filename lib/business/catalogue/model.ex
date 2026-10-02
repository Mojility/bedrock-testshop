defmodule Business.Catalogue.Model do
  @moduledoc "Navigable design concepts and typed relationships; never an executable model interpreter."
  alias Business.Catalogue.{Components, Domain}

  def nodes do
    Enum.flat_map(Domain.blueprints(), & &1["design_model"]["nodes"]) ++
      for component <- Components.all(), component.layer != "Blueprint" do
        %{
          "id" => "component:" <> component.id,
          "kind" => component.layer,
          "name" => component.title,
          "description" => component.purpose,
          "component_id" => component.id
        }
      end
  end

  def get(id),
    do: Enum.find(nodes(), &(&1["id"] == id)) || Enum.find(nodes(), &(&1["kind"] == "Actor"))

  @doc "Journeys involving an actor, goal, interaction, or composition, retaining declared stage order."
  def journeys_for(id) do
    Enum.filter(nodes(), fn node ->
      node["kind"] == "Journey" and
        (id in [node["id"], node["actor"], node["goal"]] or
           Enum.any?(node["stages"], fn stage ->
             id in [stage["performer"], stage["interaction"]] or
               Enum.any?(stage["compositions"], &(id == "component:" <> &1))
           end))
    end)
  end

  def relationships do
    Enum.flat_map(Domain.blueprints(), & &1["design_model"]["relationships"]) ++
      for component <- Components.all(),
          component.layer != "Blueprint",
          dependency <- component.depends do
        %{
          "source" => "component:" <> component.id,
          "relation" => "uses",
          "target" => "component:" <> dependency
        }
      end
  end

  def outgoing(id), do: Enum.filter(relationships(), &(&1["source"] == id))
  def incoming(id), do: Enum.filter(relationships(), &(&1["target"] == id))
  def label(value), do: value |> String.replace("_", " ") |> String.capitalize()

  def details(node),
    do:
      node
      |> Map.drop(~w(id kind name description domain_id component_id stages steps actor goal))
      |> Enum.sort()

  def describe([]), do: "None"
  def describe(value) when is_list(value), do: Enum.map_join(value, " · ", &describe/1)

  def describe(value) when is_map(value),
    do: Enum.map_join(value, " · ", fn {key, item} -> "#{label(key)}: #{describe(item)}" end)

  def describe(value), do: to_string(value)
end
