defmodule Business.Catalogue.DomainTest do
  use ExUnit.Case, async: true
  alias Business.Catalogue.{Components, Domain, Receiving, Stock}

  test "domain references and presentation bindings resolve without dangling links" do
    ids = Enum.map(Domain.nodes(), & &1["id"])
    component_ids = Enum.map(Components.all(), & &1.id)
    assert length(ids) == length(Enum.uniq(ids))

    for node <- Domain.nodes() do
      assert Enum.all?(node["presentations"], &(&1 in component_ids))
    end

    for node <- Domain.nodes(), field <- node["fields"] do
      assert field["type"] in ids
    end

    for binding <- Domain.bindings() do
      assert Enum.all?(binding["domain_concepts"], &(&1 in ids))
      assert Enum.all?(binding["components"], &(&1 in component_ids))

      for path <- binding["reads"] ++ binding["inputs"], !String.starts_with?(path, "view.") do
        [entity, field] = String.split(path, ".")
        assert entity in ids
        assert Enum.any?(Domain.get(entity)["fields"], &(&1["name"] == field))
      end
    end
  end

  test "stock quantity context is included in the label without becoming the selected value" do
    part = Stock.get(Receiving.initial(), "MAT-112")
    assert Domain.option_label(part) =~ "MAT-112"
    assert Domain.option_label(part) =~ "0 each available / 8 on hand"
    assert Domain.option_label(part) =~ "Warehouse / A-06"
    assert Domain.option_label(Stock.get(Receiving.initial(), "MAT-224")) =~ "Van 02"
    assert Enum.any?(Domain.used_in("quantity"), &(&1["id"] == "stock_position"))
    assert Enum.any?(Domain.for_component("inventory-picker"), &(&1["effect"] == "view_state"))
    assert Domain.get("unknown")["id"] == "number"
  end
end
