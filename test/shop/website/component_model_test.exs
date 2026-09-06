defmodule Shop.Website.ComponentModelTest do
  use ExUnit.Case, async: true

  alias Shop.Website.ComponentModel
  alias Shop.Website.Registry
  alias Shop.Website.Template
  alias Shop.Website.Tree

  defp component(overrides \\ %{}) do
    Map.merge(
      %{
        "name" => "shop_notice",
        "level" => "molecule",
        "template" => %{
          "type" => "text",
          "props" => %{"content" => %{"$expr" => ["prop", "message"]}}
        }
      },
      overrides
    )
  end

  defp model(components), do: %{"version" => 1, "components" => components}

  test "empty models extend nothing and have a stable content fingerprint" do
    assert ComponentModel.entries(nil) == %{}
    assert ComponentModel.entries(model([])) == %{}
    assert ComponentModel.hash(nil) == ComponentModel.hash(model([]))
    assert ComponentModel.hash(nil) =~ ~r/^[a-f0-9]{64}$/
  end

  test "customer components declare schemas and safely expand into built-in nodes" do
    definition =
      component(%{
        "native" => true,
        "purpose" => "Tell customers about holiday hours",
        "children" => ["atom"],
        "props" => %{
          "message" => %{"type" => "string", "required" => true, "doc" => "Opening hours"},
          "active" => %{"type" => "boolean", "default" => false},
          "count" => %{"type" => "integer"},
          "kind" => %{"type" => "enum", "values" => ["info", "alert"]},
          "tone" => %{"type" => "token", "domain" => "color"},
          "labels" => %{"type" => "list", "of" => "string"},
          "rows" => %{"type" => "list", "of" => %{"name" => %{"type" => "string"}}}
        }
      })

    entries = ComponentModel.entries(model([definition]))
    entry = entries["shop_notice"]
    assert entry.native
    assert entry.level == :molecule
    assert entry.children == [:atom]
    assert entry.props["message"] == %{type: :string, required: true, doc: "Opening hours"}
    assert entry.props["active"] == %{type: :boolean, default: false}
    assert entry.props["tone"] == %{type: :token, domain: :color}
    assert entry.props["labels"].of == :string
    assert entry.props["rows"].of == %{"name" => %{type: :string}}
    assert Registry.get("shop_notice", entries) == entry
    assert Registry.catalogue(entries) =~ "Tell customers about holiday hours"

    rendered = Template.render(entry.template, %{"message" => "Closed Monday"})
    assert rendered.type == "text"
    assert rendered.props == %{"content" => "Closed Monday"}

    tree =
      Tree.from_stored(%{
        "notice" => %{"type" => "shop_notice", "props" => %{"message" => "Open"}}
      })

    assert [%{id: "notice", type: "text", props: %{"content" => "Open"}}] =
             Tree.expand(tree, entries)
  end

  test "fingerprints ignore map order but identify changes to the customer model" do
    original = component()
    reordered = original |> Enum.reverse() |> Map.new()
    assert ComponentModel.hash(model([original])) == ComponentModel.hash(model([reordered]))

    changed = Map.put(original, "purpose", "Emergency closure notice")
    refute ComponentModel.hash(model([original])) == ComponentModel.hash(model([changed]))
  end

  test "only the supported model version and bounded component collections are accepted" do
    for invalid <- [
          %{},
          %{"version" => 2, "components" => []},
          model(nil),
          model(List.duplicate(component(), 101))
        ] do
      assert_raise ArgumentError, "unsupported component model", fn ->
        ComponentModel.entries(invalid)
      end
    end
  end

  test "definitions require a template and a new valid name" do
    assert_raise ArgumentError, "component requires a declarative preview template", fn ->
      ComponentModel.entries(model([%{"name" => "missing"}]))
    end

    for name <- ["text", "Invalid", "", "invalid name", String.duplicate("a", 65), nil] do
      assert_raise ArgumentError, "component name must be new", fn ->
        ComponentModel.entries(model([component(%{"name" => name})]))
      end
    end

    assert_raise ArgumentError, "duplicate component", fn ->
      ComponentModel.entries(model([component(), component()]))
    end
  end

  test "rejects unknown schema and expression operations without creating atoms" do
    for override <- [
          %{"level" => "unknown_level"},
          %{"children" => ["unknown_child"]},
          %{"props" => %{"message" => %{"type" => "unknown_type"}}},
          %{"props" => %{"message" => %{"type" => "token", "domain" => "unknown_domain"}}},
          %{"template" => %{"$expr" => ["execute", "untrusted"]}}
        ] do
      assert_raise ArgumentError, "unsupported model value", fn ->
        ComponentModel.entries(model([component(override)]))
      end
    end
  end

  test "rejects missing dependencies and direct or indirect component recursion" do
    assert_raise ArgumentError, "unknown template component", fn ->
      ComponentModel.entries(model([component(%{"template" => %{"type" => "missing"}})]))
    end

    recursive = component(%{"template" => %{"type" => "shop_notice"}})

    assert_raise ArgumentError, "recursive component model", fn ->
      ComponentModel.entries(model([recursive]))
    end

    first = component(%{"name" => "first", "template" => %{"type" => "second"}})
    second = component(%{"name" => "second", "template" => %{"type" => "first"}})

    assert_raise ArgumentError, "recursive component model", fn ->
      ComponentModel.entries(model([first, second]))
    end
  end

  test "limits long acyclic expansion chains" do
    chain =
      Enum.map(0..14, fn index ->
        type = if index == 14, do: "text", else: "part#{index + 1}"
        component(%{"name" => "part#{index}", "template" => %{"type" => type}})
      end)

    assert_raise ArgumentError, "recursive component model", fn ->
      ComponentModel.entries(model(chain))
    end
  end

  test "nested expression data remains data and resolves customer list items" do
    definition =
      component(%{
        "template" => %{
          "type" => "stack",
          "props" => %{"metadata" => %{"labels" => ["holiday", "hours"]}},
          "children" => [
            %{
              "$expr" => [
                "each",
                %{"$expr" => ["prop", "rows"]},
                %{"type" => "text", "props" => %{"content" => %{"$expr" => ["item", "name"]}}}
              ]
            }
          ]
        }
      })

    entry = ComponentModel.entries(model([definition]))["shop_notice"]
    rendered = Template.render(entry.template, %{"rows" => [%{"name" => "Monday"}]})
    assert rendered.props["metadata"] == %{"labels" => ["holiday", "hours"]}
    assert [%{type: "text", props: %{"content" => "Monday"}}] = rendered.children
  end
end
