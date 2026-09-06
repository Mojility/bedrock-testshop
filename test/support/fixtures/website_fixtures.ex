defmodule Shop.WebsiteFixtures do
  @moduledoc "Pure theme settings for customer website contract tests."

  @doc "A full theme, with any axes in `overrides` replaced."
  def theme_fixture(overrides \\ %{}) do
    Map.merge(
      %{
        "type_pairing" => "slab_sans",
        "heading_case" => "upper",
        "palette_scheme" => "light",
        "hue" => 40,
        "harmony" => "split_complementary",
        "accent_hue" => nil,
        "chroma" => "medium",
        "shape" => "sharp",
        "rules" => "heavy",
        "elevation" => "hard",
        "density" => "compact",
        "hero_layout" => "band",
        "services_layout" => "numbered",
        "contact_layout" => "phone_first",
        "texture" => "none"
      },
      Map.new(overrides, fn {key, value} -> {to_string(key), value} end)
    )
  end
end
