defmodule Shop.Website.TemplateTest do
  use ExUnit.Case, async: true

  alias Shop.Website.Template

  test "optional children disappear for absent values and choose their explicit fallback" do
    optional = %{type: "text", props: %{content: "Shown"}}
    fallback = %{type: "badge", props: %{label: "Unavailable"}}

    template = %{
      type: "stack",
      children: [
        {:if, {:prop, :value}, optional},
        {:if, {:prop, :value}, [optional], fallback}
      ]
    }

    for absent <- [nil, false, "", []] do
      assert %{children: [%{type: "badge", props: %{"label" => "Unavailable"}}]} =
               Template.render(template, %{"value" => absent})
    end

    assert %{children: [%{type: "text"}, %{type: "text"}]} =
             Template.render(template, %{"value" => 0})
  end

  test "case expressions omit absent values and use declared alternatives and fallbacks" do
    template = %{
      type: "stack",
      props: %{
        colour: {:case, {:prop, :kind}, %{"warning" => "primary"}},
        label: {:case, {:prop, :kind}, %{"warning" => {:prop, :label}}, "Default"},
        missing_link: {:concat, ["tel:", {:prop, :phone}]}
      },
      children: [
        {:case, {:prop, :kind}, %{"warning" => %{type: "text", props: %{content: "Careful"}}}}
      ]
    }

    assert %{props: %{"label" => "Default"}, children: []} = Template.render(template, %{})

    assert %{
             props: %{"colour" => "primary", "label" => "Danger", "missing_link" => "tel:123"},
             children: [%{type: "text", props: %{"content" => "Careful"}}]
           } =
             Template.render(template, %{
               "kind" => "warning",
               "label" => "Danger",
               "phone" => "123"
             })
  end

  test "iteration supports scalar items and default fields without confusing false with missing" do
    template = %{
      type: "stack",
      children: [
        {:each, {:prop, :items},
         %{
           type: "text",
           props: %{content: {:item}, position: {:index}, label: {:item, :name, "Unnamed"}}
         }}
      ]
    }

    assert %{
             children: [
               %{name: nil, props: %{"content" => "One", "position" => 1, "label" => "Unnamed"}},
               %{name: nil, props: %{"content" => false, "position" => 2, "label" => "Unnamed"}}
             ]
           } = Template.render(template, %{"items" => ["One", false]})

    assert %{children: [%{props: %{"label" => false}}]} =
             Template.render(template, %{"items" => [%{"name" => false}]})
  end
end
