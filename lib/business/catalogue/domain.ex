defmodule Business.Catalogue.Domain do
  @moduledoc "Domain and presentation contracts carried in the standalone blueprint snapshot."
  @path Path.expand("../../../priv/catalogue/receiving.json", __DIR__)
  @external_resource @path
  @blueprint @path |> File.read!() |> Jason.decode!()

  @leads_path Path.expand("../../../priv/catalogue/website-leads.json", __DIR__)
  @external_resource @leads_path
  @leads_blueprint @leads_path |> File.read!() |> Jason.decode!()

  def blueprints, do: [@blueprint, @leads_blueprint]
  def blueprint, do: @blueprint

  def composition(id),
    do:
      Enum.find(
        Enum.flat_map(blueprints(), & &1["composition_contracts"]),
        &(&1["component"] == id)
      )

  def nodes, do: Enum.flat_map(blueprints(), & &1["domain_model"]["nodes"])
  def bindings, do: Enum.flat_map(blueprints(), & &1["presentation_bindings"])
  def get(id), do: Enum.find(nodes(), &(&1["id"] == id)) || hd(nodes())
  def for_component(id), do: Enum.filter(bindings(), &(id in &1["components"]))
  def for_concept(id), do: Enum.filter(bindings(), &(id in &1["domain_concepts"]))

  def used_in(id),
    do: Enum.filter(nodes(), fn node -> Enum.any?(node["fields"], &(&1["type"] == id)) end)

  def option_label(part) do
    available = part.on_hand - part.reserved

    location =
      if String.starts_with?(part.bin, "Van"), do: part.bin, else: "Warehouse / #{part.bin}"

    "#{part.name} · #{part.id} — #{available} #{part.unit} available / #{part.on_hand} on hand · #{location}"
  end
end
