defmodule Business.Catalogue.ModelTest do
  use ExUnit.Case, async: true
  alias Business.Catalogue.{Components, Domain, Model}

  test "typed relationships resolve and allow traversal in both directions" do
    nodes = Model.nodes()
    ids = Enum.map(nodes, & &1["id"])
    assert length(ids) == length(Enum.uniq(ids))

    assert length(Model.relationships()) == length(Enum.uniq(Model.relationships()))

    for edge <- Model.relationships() do
      assert edge["source"] in ids
      assert edge["target"] in ids
      assert edge in Model.outgoing(edge["source"])
      assert edge in Model.incoming(edge["target"])
    end

    for node <- nodes do
      assert Model.get(node["id"]) == node
      assert is_list(Model.details(node))
    end

    assert Model.get("unknown")["kind"] == "Actor"
    assert Model.describe(%{"regions" => ["work", "context"]}) == "Regions: work · context"
    assert Model.describe([]) == "None"
    assert Model.label("read_only") == "Read only"
  end

  test "relationship names carry consistent source and target meanings" do
    domain = ["Primitive", "Value object", "Entity"]
    visual = ["Foundation", "Control", "Pattern", "Composition"]

    contracts = %{
      "undertakes" => {["Actor"], ["Journey"]},
      "pursues" => {["Journey"], ["Goal"]},
      "seeks" => {["Actor"], ["Goal"]},
      "performs" => {["Actor"], ["Interaction"]},
      "advances" => {["Interaction"], ["Goal"]},
      "supports" => {["Capability", "Binding", "Composition"], ["Interaction"]},
      "uses" => {["Capability"] ++ visual, domain ++ visual},
      "offers" => {["Capability"], ["Command", "Query"]},
      "contains" => {["Workspace"], ["Composition"]},
      "operates_in" => {["Workspace"], ["Mode"]},
      "applies_in" => {["Blueprint"], ["Business context"]},
      "proposes" => {["Blueprint"], ["Capability"]},
      "includes" => {["Blueprint", "Journey"], ["Workspace", "Composition", "Interaction"]},
      "references" => {domain, ["Entity"]},
      "has_field_of_type" => {domain, domain},
      "records" => {["Command"], ["Event"]},
      "describes" => {["Event", "Projection"], domain},
      "applies" => {["Command"], ["Policy"]},
      "triggered_by" => {["State transition"], ["Command"]},
      "affects" => {["State transition"], domain},
      "constrained_by" => {["Capability"], ["Rule"]},
      "returns" => {["Query"], ["Projection"]},
      "reads_through" => {["Binding"], ["Projection"]},
      "submits_to" => {["Binding", "Composition"], ["Command"]},
      "connects" => {["Binding"], visual},
      "bound_by" => {["Composition"], ["Binding"]},
      "checks" => {["Evidence"], ["Blueprint"]}
    }

    for edge <- Model.relationships() do
      {sources, targets} = Map.fetch!(contracts, edge["relation"])
      assert Model.get(edge["source"])["kind"] in sources
      assert Model.get(edge["target"])["kind"] in targets
    end
  end

  test "Actor journeys retain stage order and match interaction compositions" do
    [journey] = Model.journeys_for("actor:warehouse_staff")
    assert Model.get(journey["actor"])["kind"] == "Actor"
    assert Model.get(journey["goal"])["kind"] == "Goal"
    assert Enum.map(journey["stages"], & &1["interaction"]) == journey["steps"]

    assert Enum.map(journey["stages"], & &1["compositions"]) == [
             ["split"],
             ["record"],
             ["movement-history"]
           ]

    for stage <- journey["stages"] do
      assert Model.get(stage["performer"])["kind"] == "Actor"
      assert Model.get(stage["interaction"])["kind"] == "Interaction"
      assert stage["completion"] != ""
      assert stage["handoff"] != ""

      for component <- stage["compositions"] do
        assert Domain.composition(component)["interaction"] == stage["interaction"]
        assert journey in Model.journeys_for("component:" <> component)
      end

      assert journey in Model.journeys_for(stage["interaction"])
    end

    assert [journey] == Model.journeys_for(journey["id"])
    assert [journey] == Model.journeys_for(journey["goal"])
    assert [] == Model.journeys_for("domain:number")
  end

  test "bindings distinguish read projections, command inputs and view state" do
    for binding <- Domain.bindings() do
      assert Model.get(binding["projection"])["kind"] == "Projection"
      assert Model.get(binding["interaction"])["kind"] == "Interaction"
      assert binding["effect"] in ~w(command read_only view_state)

      if binding["effect"] == "command" do
        command = Model.get(binding["command"])
        assert command["kind"] == "Command"
        assert binding["view_state"] == []
        assert Enum.all?(binding["inputs"], &(&1 in command["inputs"]))

        for path <- command["inputs"] do
          [concept, name] = String.split(path, ".")
          field = Enum.find(Domain.get(concept)["fields"], &(&1["name"] == name))
          assert field
          refute field["value_source"] == "derived"
        end
      else
        assert binding["command"] == nil
        assert binding["inputs"] == []
        assert Enum.all?(binding["view_state"], &String.starts_with?(&1, "view."))
      end
    end
  end

  test "blueprint membership and composition contracts agree with executable previews" do
    components = for node <- Components.all(), node.layer == "Composition", do: node.id

    assert Enum.sort(Enum.flat_map(Domain.blueprints(), & &1["compositions"])) ==
             Enum.sort(components)

    assert Enum.sort(Components.get("receiving").depends) ==
             Enum.sort(Domain.blueprint()["compositions"])

    for id <- components do
      contract = Domain.composition(id)
      assert Model.get(contract["interaction"])["kind"] == "Interaction"
      assert contract["regions"]["primary_work"] != ""
      assert contract["regions"]["supporting_context"] != ""
      assert contract["recovery"] != []
      assert contract["gaps"] != []

      for binding <- contract["bindings"] do
        assert Enum.any?(Domain.for_component(id), &(&1["id"] == binding))
      end
    end

    assert Domain.composition("unknown") == nil
  end
end
