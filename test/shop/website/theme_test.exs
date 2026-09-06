defmodule Shop.Website.ThemeTest do
  use ExUnit.Case, async: true

  import Shop.WebsiteFixtures

  alias Shop.Website.Color
  alias Shop.Website.Theme

  doctest Color
  doctest Theme

  # Channels within ±2 of the reference, which is as close as an 8-bit
  # round trip through independently published constants gets.
  defp assert_close(hex, want) do
    for {got, expected} <- Enum.zip(channels(hex), channels(want)) do
      assert abs(got - expected) <= 2, "#{hex} is not within 2 of #{want}"
    end
  end

  defp channels("#" <> hex) do
    for <<pair::binary-size(2) <- hex>>, do: String.to_integer(pair, 16)
  end

  defp spread(hex), do: Enum.max(channels(hex)) - Enum.min(channels(hex))

  defp derive!(overrides) do
    {:ok, theme} = Theme.derive(theme_fixture(overrides))
    theme
  end

  describe "Color.oklch_to_hex/3" do
    test "matches known sRGB primaries and greys" do
      assert_close(Color.oklch_to_hex(0.6280, 0.2577, 29.23), "#ff0000")
      assert_close(Color.oklch_to_hex(0.8664, 0.2948, 142.5), "#00ff00")
      assert_close(Color.oklch_to_hex(0.4520, 0.3130, 264.05), "#0000ff")
      assert_close(Color.oklch_to_hex(0.5, 0, 0), "#636363")
      # Not an outside reference: pinned so a change to the constants shows up.
      assert Color.oklch_to_hex(0.5, 0.1, 220) == "#00708a"
    end

    test "clamps what sRGB cannot show rather than wrapping" do
      assert Color.oklch_to_hex(0.9, 0.4, 142) == "#00ff00"
      assert Color.oklch_to_hex(1.2, 0, 0) == "#ffffff"
    end
  end

  describe "Color.contrast/2" do
    test "is the WCAG ratio, in either order" do
      assert Color.contrast("#ffffff", "#000000") == 21.0
      assert Color.contrast("#767676", "#ffffff") == 4.54
      assert Color.contrast("#ffffff", "#767676") == 4.54
      assert Color.contrast("#1e4d3a", "#1e4d3a") == 1.0
    end
  end

  describe "the axes" do
    test "are the fifteen from the design doc, with their values; section_order is retired" do
      assert Theme.axes() ==
               ~w(type_pairing heading_case palette_scheme hue harmony accent_hue chroma shape
                  rules elevation density hero_layout services_layout contact_layout texture)

      refute "section_order" in Theme.axes()

      assert length(Theme.pairings()) == 12
      assert Theme.values("type_pairing") == Theme.pairings()
      assert Theme.values("heading_case") == ~w(sentence upper)
      assert Theme.values("palette_scheme") == ~w(light light_warm_surface dark_hero dark tinted)

      assert Theme.values("harmony") ==
               ~w(monochrome analogous complementary split_complementary triadic)

      assert Theme.values("chroma") == ~w(muted medium vivid)
      assert Theme.values("shape") == ~w(sharp soft round)
      assert Theme.values("rules") == ~w(none hairline heavy)
      assert Theme.values("elevation") == ~w(flat soft hard)
      assert Theme.values("density") == ~w(airy standard compact)
      assert Theme.values("hero_layout") == ~w(stacked split band centred)
      assert Theme.values("services_layout") == ~w(cards list two_column numbered)
      assert Theme.values("contact_layout") == ~w(form_first phone_first side_by_side)
      assert Theme.values("texture") == ~w(none grain lines dots)
      assert Theme.values("hue") == nil
      assert Theme.values("section_order") == nil
    end

    test "the type library carries no Bedrock face and every pairing has both faces" do
      for key <- Theme.pairings() do
        pairing = Theme.pairing(key)
        refute pairing.display =~ "Barlow", key
        refute pairing.body =~ "Barlow", key
        assert pairing.character != ""
      end

      assert Theme.upper_pairings() ==
               ~w(grotesk_humanist slab_sans condensed_sans industrial display_sans)
    end
  end

  describe "derive/1 validation" do
    test "accepts a complete theme with atom or string keys" do
      assert {:ok, _theme} = Theme.derive(theme_fixture())

      atoms = Map.new(theme_fixture(), fn {key, value} -> {String.to_atom(key), value} end)
      assert {:ok, theme} = Theme.derive(atoms)
      assert theme.type_pairing == "slab_sans"
      refute Map.has_key?(theme, :section_order)
    end

    test "ignores a section_order an older document still carries" do
      assert {:ok, theme} = Theme.derive(Map.put(theme_fixture(), "section_order", ~w(why)))
      refute Map.has_key?(theme, :section_order)
      refute Map.has_key?(Theme.settings(theme), "section_order")
    end

    test "rejects every axis outside its set, and anything missing" do
      for {axis, bad} <- [
            {"type_pairing", "barlow"},
            {"heading_case", "title"},
            {"palette_scheme", "neon"},
            {"hue", "amber"},
            {"hue", 400},
            {"hue", -1},
            {"accent_hue", 361},
            {"harmony", "quadratic"},
            {"chroma", "loud"},
            {"shape", "blobby"},
            {"rules", "double"},
            {"elevation", "floating"},
            {"density", "cramped"},
            {"hero_layout", "carousel"},
            {"services_layout", "table"},
            {"contact_layout", "popup"},
            {"texture", "wood"}
          ] do
        assert {:error, :invalid_theme} = Theme.derive(theme_fixture(%{axis => bad})),
               "#{axis} = #{inspect(bad)} should be rejected"
      end

      for axis <- Theme.axes() -- ["accent_hue"] do
        assert {:error, :invalid_theme} = Theme.derive(Map.delete(theme_fixture(), axis)),
               "a theme without #{axis} should be rejected"
      end

      assert {:error, :invalid_theme} = Theme.derive(%{})
      assert {:error, :invalid_theme} = Theme.derive(nil)
      assert {:error, :invalid_theme} = Theme.derive(%{"direction" => "workshop", "hue" => 40})
    end

    test "accent_hue may be absent or nil" do
      assert {:ok, %{accent_hue: nil}} = Theme.derive(Map.delete(theme_fixture(), "accent_hue"))
      assert {:ok, %{accent_hue: nil}} = Theme.derive(theme_fixture(%{"accent_hue" => nil}))
      assert {:ok, %{accent_hue: 300}} = Theme.derive(theme_fixture(%{"accent_hue" => 300}))
    end

    test "settings/1 gives back every axis, harmony included" do
      settings = Theme.settings(derive!(%{"harmony" => "triadic"}))
      assert settings["harmony"] == "triadic"
      assert Map.keys(settings) |> Enum.sort() == Enum.sort(Theme.axes())
    end

    test "honours upper headings only with a pairing that carries them" do
      for pairing <- Theme.upper_pairings() do
        theme = derive!(%{"type_pairing" => pairing, "heading_case" => "upper"})
        assert theme.heading_case == "upper", pairing
        assert theme.heading_transform == "uppercase", pairing
      end

      for pairing <- Theme.pairings() -- Theme.upper_pairings() do
        theme = derive!(%{"type_pairing" => pairing, "heading_case" => "upper"})
        assert theme.heading_case == "sentence", pairing
        assert theme.heading_transform == "none", pairing
      end

      assert derive!(%{"heading_case" => "sentence"}).heading_transform == "none"
    end
  end

  describe "derive/1 tokens" do
    test "each pairing brings its own faces, weight, and a mono face for eyebrows when it has one" do
      slab = derive!(%{"type_pairing" => "slab_sans"})
      assert slab.font_display =~ ~s("Zilla Slab")
      assert slab.font_display =~ "serif"
      assert slab.font_body =~ ~s("Work Sans")
      assert slab.font_mono == slab.font_body
      assert slab.display_weight == "700"

      mono = derive!(%{"type_pairing" => "mono_accent"})
      assert mono.font_mono =~ ~s("IBM Plex Mono")
      assert mono.font_display =~ ~s("IBM Plex Sans")

      editorial = derive!(%{"type_pairing" => "editorial"})
      assert editorial.font_display =~ ~s("Newsreader")
      assert editorial.display_weight == "500"

      industrial = derive!(%{"type_pairing" => "industrial"})
      assert industrial.font_display =~ ~s("Archivo Black")
      assert industrial.display_weight == "400"
    end

    test "shape sets the radii" do
      assert %{radius: "0px", radius_control: "0px", radius_pill: "0px"} =
               derive!(%{"shape" => "sharp"})

      assert %{radius: "8px", radius_control: "6px", radius_pill: "8px"} =
               derive!(%{"shape" => "soft"})

      assert %{radius: "16px", radius_control: "12px", radius_pill: "999px"} =
               derive!(%{"shape" => "round"})
    end

    test "rules set the separator weight and colour" do
      none = derive!(%{"rules" => "none"})
      assert none.rule == "0px"
      assert none.rule_color == "transparent"

      hairline = derive!(%{"rules" => "hairline"})
      assert hairline.rule == "1px"
      assert hairline.rule_color == hairline.colors.border

      heavy = derive!(%{"rules" => "heavy"})
      assert heavy.rule == "3px"
      assert heavy.rule_color == heavy.colors.text
    end

    test "elevation sets the shadow, heavier in the dark" do
      assert derive!(%{"elevation" => "flat"}).shadow == "none"
      assert derive!(%{"elevation" => "soft"}).shadow == "0 8px 24px rgb(0 0 0 / 0.08)"

      assert derive!(%{"elevation" => "soft", "palette_scheme" => "dark"}).shadow ==
               "0 8px 24px rgb(0 0 0 / 0.45)"

      hard = derive!(%{"elevation" => "hard"})
      assert hard.shadow == "6px 6px 0 " <> hard.colors.text
    end

    test "density sets the section padding and column width" do
      assert %{section_pad: "96px", column: "1040px"} = derive!(%{"density" => "airy"})
      assert %{section_pad: "64px", column: "1120px"} = derive!(%{"density" => "standard"})
      assert %{section_pad: "48px", column: "1200px"} = derive!(%{"density" => "compact"})
    end

    test "carries the layout axes through untouched" do
      theme =
        derive!(%{
          "hero_layout" => "split",
          "services_layout" => "two_column",
          "contact_layout" => "side_by_side",
          "texture" => "dots"
        })

      assert theme.hero_layout == "split"
      assert theme.services_layout == "two_column"
      assert theme.contact_layout == "side_by_side"
      assert theme.texture == "dots"
    end
  end

  describe "derive/1 colour" do
    test "keeps large areas nearly neutral in the light schemes and puts colour in the primary" do
      for scheme <- ~w(light light_warm_surface dark_hero tinted) do
        %{colors: colors} = derive!(%{"palette_scheme" => scheme, "hue" => 40})

        assert Color.relative_luminance(colors.bg) > 0.8, scheme
        assert Color.relative_luminance(colors.surface) > 0.7, scheme
        assert Color.relative_luminance(colors.bg) > Color.relative_luminance(colors.surface)
        assert colors.on_primary == colors.bg

        # Amber primary: red channel leads, blue trails.
        [r, _g, b] = channels(colors.primary)
        assert r > b, scheme
      end
    end

    test "the dark scheme inverts: dark page, light text, light primary" do
      %{colors: colors} =
        derive!(%{"palette_scheme" => "dark", "hue" => 220, "hero_layout" => "stacked"})

      assert Color.relative_luminance(colors.bg) < 0.05
      assert Color.relative_luminance(colors.surface) > Color.relative_luminance(colors.bg)
      assert Color.relative_luminance(colors.text) > 0.8
      assert Color.relative_luminance(colors.primary) > Color.relative_luminance(colors.bg)
      assert colors.hero_bg == colors.bg

      assert Color.relative_luminance(colors.surface_alt) >
               Color.relative_luminance(colors.surface)
    end

    test "dark_hero keeps a light page but paints the hero dark with light text" do
      %{colors: colors} = derive!(%{"palette_scheme" => "dark_hero", "hue" => 220})

      assert Color.relative_luminance(colors.bg) > 0.85
      assert Color.relative_luminance(colors.hero_bg) < 0.05
      assert Color.relative_luminance(colors.hero_text) > 0.8
      assert colors.hero_on_button == colors.hero_bg
    end

    test "every light scheme has a second surface a step darker than the first" do
      for scheme <- ~w(light light_warm_surface dark_hero tinted) do
        %{colors: colors} = derive!(%{"palette_scheme" => scheme, "hue" => 40})

        assert Color.relative_luminance(colors.surface_alt) <
                 Color.relative_luminance(colors.surface),
               scheme
      end
    end

    test "a band hero paints the hero in the primary and inverts the button" do
      %{colors: colors} = derive!(%{"hero_layout" => "band", "palette_scheme" => "light"})

      assert colors.hero_bg == colors.primary
      assert colors.hero_text == colors.on_primary
      assert colors.hero_button == colors.on_primary
      assert colors.hero_on_button == colors.primary
    end

    test "a stacked hero on a light page uses the page's own roles" do
      %{colors: colors} = derive!(%{"hero_layout" => "stacked", "palette_scheme" => "light"})

      assert colors.hero_bg == colors.bg
      assert colors.hero_text == colors.text
      assert colors.hero_button == colors.primary
    end

    test "chroma moves the primary's saturation" do
      saturation = fn hex ->
        [r, g, b] = channels(hex)
        Enum.max([r, g, b]) - Enum.min([r, g, b])
      end

      muted = derive!(%{"chroma" => "muted", "hue" => 220}).colors.primary
      medium = derive!(%{"chroma" => "medium", "hue" => 220}).colors.primary
      vivid = derive!(%{"chroma" => "vivid", "hue" => 220}).colors.primary

      assert saturation.(muted) < saturation.(medium)
      assert saturation.(medium) < saturation.(vivid)
    end

    test "the harmony places the secondary and the accent round the wheel from the hue" do
      assert Theme.harmony_hues(%{"hue" => 40, "harmony" => "monochrome"}) ==
               %{primary: 40.0, secondary: 40.0, accent: 40.0}

      assert Theme.harmony_hues(%{"hue" => 40, "harmony" => "analogous"}) ==
               %{primary: 40.0, secondary: 10.0, accent: 70.0}

      assert Theme.harmony_hues(%{"hue" => 40, "harmony" => "complementary"}) ==
               %{primary: 40.0, secondary: 220.0, accent: 60.0}

      assert Theme.harmony_hues(%{"hue" => 40, "harmony" => "split_complementary"}) ==
               %{primary: 40.0, secondary: 250.0, accent: 190.0}

      assert Theme.harmony_hues(%{"hue" => 40, "harmony" => "triadic"}) ==
               %{primary: 40.0, secondary: 160.0, accent: 280.0}

      assert Theme.harmony_hues(%{hue: 350, harmony: :analogous}).accent == 20.0
    end

    test "uses the accent hue when given and lets the harmony place it otherwise" do
      default = derive!(%{"hue" => 40, "harmony" => "split_complementary"}).colors
      chosen = derive!(%{"hue" => 40, "harmony" => "split_complementary", "accent_hue" => 300})
      wrapped = derive!(%{"hue" => 40, "harmony" => "split_complementary", "accent_hue" => 190})

      assert default.accent == wrapped.colors.accent
      assert chosen.colors.accent != default.accent
      assert {_l, _c, 300.0} = chosen.oklch.accent
    end

    test "monochrome keeps one hue and tells the three apart by lightness and chroma" do
      %{colors: c, oklch: o} = derive!(%{"harmony" => "monochrome", "hue" => 220})

      assert {_l, _c, 220.0} = o.primary
      assert {_l, _c, 220.0} = o.secondary
      assert {_l, _c, 220.0} = o.accent
      assert Theme.distinct?(o.primary, o.secondary)
      assert Theme.distinct?(o.primary, o.accent)
      assert Theme.distinct?(o.secondary, o.accent)

      # On a light page the secondary is the deeper, duller self and the
      # accent the lighter, brighter one.
      assert Color.relative_luminance(c.secondary) < Color.relative_luminance(c.primary)
      assert Color.relative_luminance(c.accent) > Color.relative_luminance(c.primary)
      assert elem(o.secondary, 1) < elem(o.primary, 1)
      assert elem(o.accent, 1) > elem(o.primary, 1)
    end

    test "the neutrals take the temperature of the hue, unless the scheme is tinted" do
      warm = derive!(%{"hue" => 40, "palette_scheme" => "light"})
      cool = derive!(%{"hue" => 220, "palette_scheme" => "light"})
      assert warm.neutral_temperature == :warm
      assert cool.neutral_temperature == :cool
      assert Theme.neutral_temperature(150) == :cool
      assert Theme.neutral_temperature(340) == :warm

      for role <- ~w(bg surface surface_alt text muted border)a do
        [wr, _wg, wb] = channels(warm.colors[role])
        [cr, _cg, cb] = channels(cool.colors[role])
        assert wr >= wb, "warm #{role} leans red"
        assert cb >= cr, "cool #{role} leans blue"
        assert spread(warm.colors[role]) <= 16, "warm #{role} is nearly neutral"
        assert spread(cool.colors[role]) <= 16, "cool #{role} is nearly neutral"
      end

      # A green hue takes cool greys rather than green ones.
      green = derive!(%{"hue" => 150, "palette_scheme" => "light"})
      [r, g, b] = channels(green.colors.bg)
      assert b >= g and b >= r

      tinted = derive!(%{"hue" => 150, "palette_scheme" => "tinted"})
      assert spread(tinted.colors.bg) > spread(green.colors.bg)
      assert spread(tinted.colors.surface) > spread(green.colors.surface)
    end

    test "each colour has a soft tint that carries the text and a strong shade for emphasis" do
      %{colors: c} = derive!(%{"palette_scheme" => "light", "harmony" => "triadic", "hue" => 20})

      for role <- ~w(primary secondary accent)a do
        soft = c[:"#{role}_soft"]
        strong = c[:"#{role}_strong"]
        assert Color.relative_luminance(soft) > 0.7, "#{role}_soft is a light tint"
        assert Color.contrast(c.text, soft) >= 4.5, "text on #{role}_soft"
        assert Color.contrast(c.muted, soft) >= 4.5, "muted on #{role}_soft"
        assert Color.relative_luminance(strong) < Color.relative_luminance(c[role]), "#{role}"
      end

      %{colors: d} = derive!(%{"palette_scheme" => "dark", "harmony" => "triadic", "hue" => 20})

      for role <- ~w(primary secondary accent)a do
        assert Color.relative_luminance(d[:"#{role}_soft"]) < 0.1, "#{role}_soft is deep on dark"
        assert Color.contrast(d.text, d[:"#{role}_soft"]) >= 4.5, "text on #{role}_soft"

        assert Color.relative_luminance(d[:"#{role}_strong"]) >
                 Color.relative_luminance(d[role]),
               "#{role}"
      end
    end

    test "the vividness budget trims the secondary first: vivid triadic passes, less saturated" do
      %{oklch: o} =
        derive!(%{"palette_scheme" => "light", "harmony" => "triadic", "chroma" => "vivid"})

      {_l, primary_c, _h} = o.primary
      {_l, secondary_c, _h} = o.secondary
      {_l, accent_c, _h} = o.accent

      assert secondary_c < primary_c
      assert primary_c + secondary_c + accent_c <= Theme.chroma_cap("light") + 1.0e-9
      assert Theme.chroma_cap("dark") < Theme.chroma_cap("light")
    end

    test "the hero carries the secondary as the eyebrow reads there" do
      plain = derive!(%{"hero_layout" => "stacked", "palette_scheme" => "light"}).colors
      assert plain.hero_secondary == plain.secondary

      band = derive!(%{"hero_layout" => "band", "palette_scheme" => "light"}).colors
      assert band.hero_secondary == band.on_primary

      dark = derive!(%{"palette_scheme" => "dark_hero", "hue" => 220}).colors
      assert Color.contrast(dark.hero_secondary, dark.hero_bg) >= 4.5
      assert Color.relative_luminance(dark.hero_secondary) > 0.4
    end

    test "every harmony, scheme, chroma, hue, and hero treatment passes every contrast and distinctness rule" do
      grounds = ~w(bg surface surface_alt primary_soft secondary_soft accent_soft)a

      for harmony <- Theme.values("harmony"),
          scheme <- Theme.values("palette_scheme"),
          chroma <- Theme.values("chroma"),
          hue <- 0..359//15,
          hero <- ~w(stacked band) do
        label = "#{harmony}/#{scheme}/#{chroma}/#{hero} at hue #{hue}"

        assert {:ok, %{colors: c, oklch: o}} =
                 Theme.derive(
                   theme_fixture(%{
                     "harmony" => harmony,
                     "palette_scheme" => scheme,
                     "chroma" => chroma,
                     "hue" => hue,
                     "hero_layout" => hero
                   })
                 ),
               "#{label} was rejected"

        for ground <- grounds do
          assert Color.contrast(c.text, c[ground]) >= 4.5, "text on #{ground}, #{label}"
          assert Color.contrast(c.muted, c[ground]) >= 4.5, "muted on #{ground}, #{label}"
          assert Color.contrast(c.primary, c[ground]) >= 4.5, "primary on #{ground}, #{label}"
          assert Color.contrast(c.secondary, c[ground]) >= 4.5, "secondary on #{ground}, #{label}"
          assert Color.contrast(c.accent, c[ground]) >= 3.0, "accent mark on #{ground}, #{label}"
          assert Color.contrast(c.border, c[ground]) >= 3.0, "border on #{ground}, #{label}"

          assert Color.contrast(c.primary_strong, c[ground]) >= 4.5,
                 "primary_strong on #{ground}, #{label}"

          assert Color.contrast(c.secondary_strong, c[ground]) >= 4.5,
                 "secondary_strong on #{ground}, #{label}"

          assert Color.contrast(c.accent_strong, c[ground]) >= 3.0,
                 "accent_strong on #{ground}, #{label}"
        end

        for role <- ~w(primary secondary accent)a do
          on = c[:"on_#{role}"]
          assert Color.contrast(c[role], on) >= 4.5, "on_#{role} on #{role}, #{label}"
          assert Color.contrast(c[:"#{role}_strong"], on) >= 4.5, "on_#{role} on strong, #{label}"
        end

        assert Theme.distinct?(o.primary, o.secondary), "primary and secondary alike, #{label}"
        assert Theme.distinct?(o.primary, o.accent), "primary and accent alike, #{label}"
        assert Theme.distinct?(o.secondary, o.accent), "secondary and accent alike, #{label}"

        {_l, pc, _h} = o.primary
        {_l, sc, _h} = o.secondary
        {_l, ac, _h} = o.accent
        assert pc + sc + ac <= Theme.chroma_cap(scheme) + 1.0e-9, "over the budget, #{label}"

        assert Color.contrast(c.hero_text, c.hero_bg) >= 4.5, "hero text, #{label}"
        assert Color.contrast(c.hero_muted, c.hero_bg) >= 4.5, "hero eyebrow, #{label}"
        assert Color.contrast(c.hero_secondary, c.hero_bg) >= 4.5, "hero secondary, #{label}"
        assert Color.contrast(c.hero_button, c.hero_bg) >= 4.5, "hero link, #{label}"
        assert Color.contrast(c.hero_button, c.hero_on_button) >= 4.5, "hero button, #{label}"
        assert Color.contrast(c.hero_border, c.hero_bg) >= 3.0, "hero border, #{label}"
      end
    end
  end

  describe "distinct?/2" do
    test "accepts a perceptual distance or a real hue gap with chroma, and nothing less" do
      assert Theme.distinct?({0.5, 0.1, 40}, {0.62, 0.1, 40})
      refute Theme.distinct?({0.5, 0.1, 40}, {0.58, 0.1, 40})
      assert Theme.distinct?({0.5, 0.06, 40}, {0.5, 0.06, 65})
      refute Theme.distinct?({0.5, 0.05, 40}, {0.5, 0.05, 65})
      refute Theme.distinct?({0.5, 0.15, 40}, {0.5, 0.15, 60})
      assert Theme.distinct?({0.5, 0.15, 40}, {0.5, 0.15, 65})
    end
  end

  describe "fit_lightness/4" do
    test "stops at the first lightness the check accepts, in either direction" do
      assert {:ok, hex} =
               Theme.fit_lightness({0.02, 40}, 0.6, 0.05, &(Color.contrast(&1, "#ffffff") >= 7))

      assert Color.contrast(hex, "#ffffff") >= 7
      assert Color.contrast(Color.oklch_to_hex(0.6, 0.02, 40), "#ffffff") < 7

      assert {:ok, light} =
               Theme.fit_lightness({0.02, 40}, 0.5, 0.99, &(Color.contrast(&1, "#000000") >= 7))

      assert Color.contrast(light, "#000000") >= 7
    end

    test "gives up when nothing in the range is readable" do
      assert :error =
               Theme.fit_lightness({0.02, 40}, 0.6, 0.5, &(Color.contrast(&1, "#ffffff") >= 21))
    end
  end
end
