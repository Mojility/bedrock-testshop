defmodule Shop.Website.TokensTest do
  use ExUnit.Case, async: true

  import Shop.WebsiteFixtures

  alias Shop.Website.Color
  alias Shop.Website.Theme
  alias Shop.Website.Tokens

  defp tokens!(overrides) do
    {:ok, theme} = Theme.derive(theme_fixture(overrides))
    Tokens.derive(theme)
  end

  describe "derive/1" do
    test "carries every colour role from the theme: neutrals, the three colours' tonal ranges, the hero" do
      tokens = tokens!(%{})

      for role <- ~w(bg surface surface_alt text muted border
                     primary primary_soft primary_strong on_primary
                     secondary secondary_soft secondary_strong on_secondary
                     accent accent_soft accent_strong on_accent
                     hero_bg hero_text hero_muted hero_secondary hero_button hero_on_button
                     hero_border) do
        assert tokens.colors[role] =~ ~r/^#[0-9a-f]{6}$/, role
      end
    end

    test "every type style resolves for every pairing and both heading cases" do
      for pairing <- Theme.pairings(), heading_case <- ~w(sentence upper) do
        tokens = tokens!(%{"type_pairing" => pairing, "heading_case" => heading_case})
        assert Map.keys(tokens.type) |> Enum.sort() == Enum.sort(Tokens.type_styles())

        for {style, values} <- tokens.type do
          label = "#{pairing}/#{heading_case}/#{style}"

          for key <- [:size, :line_height, :family, :weight, :case, :tracking] do
            assert is_binary(values[key]) and values[key] != "", "#{label} #{key}"
          end

          refute values.family =~ "Barlow", label
        end

        display = Theme.pairing(pairing).display
        assert tokens.type["display_xl"].family =~ display
        assert tokens.type["heading"].family =~ display
        assert tokens.type["numeral"].family =~ display
        assert tokens.type["body"].family =~ Theme.pairing(pairing).body
        assert tokens.type["eyebrow"].case == "uppercase"
        assert tokens.type["body"].case == "none"
      end
    end

    test "heading case reaches the display styles only where the pairing carries it" do
      upper = tokens!(%{"type_pairing" => "slab_sans", "heading_case" => "upper"})
      assert upper.type["display_xl"].case == "uppercase"
      assert upper.type["heading"].case == "uppercase"
      assert upper.type["subheading"].case == "none"

      sentence = tokens!(%{"type_pairing" => "editorial", "heading_case" => "upper"})
      assert sentence.type["display_xl"].case == "none"
    end

    test "the mono face carries the eyebrow and caption where a pairing has one" do
      mono = tokens!(%{"type_pairing" => "mono_accent"})
      assert mono.type["eyebrow"].family =~ "IBM Plex Mono"
      assert mono.type["caption"].family =~ "IBM Plex Mono"
      assert mono.type["body"].family =~ "IBM Plex Sans"
    end

    test "spacing, radii, rules, shadow, measure, and container come from the scale and the axes" do
      tokens = tokens!(%{"shape" => "round", "rules" => "hairline", "density" => "airy"})

      assert tokens.space == %{
               "s1" => "4px",
               "s2" => "8px",
               "s3" => "12px",
               "s4" => "16px",
               "s5" => "24px",
               "s6" => "32px",
               "s7" => "48px",
               "s8" => "64px",
               "s9" => "96px"
             }

      assert tokens.radii == %{"radius" => "16px", "control" => "12px", "pill" => "999px"}
      assert tokens.rule == %{"width" => "1px", "color" => tokens.colors["border"]}
      assert tokens.shadow == "6px 6px 0 " <> tokens.colors["text"]
      assert tokens.measure == "65ch"

      assert tokens.container == %{
               "narrow" => "680px",
               "standard" => "1040px",
               "wide" => "1200px"
             }

      assert tokens!(%{"density" => "compact"}).container["standard"] == "1200px"
      assert Tokens.gaps() == ~w(s2 s3 s4 s5 s6 s7)
      assert Tokens.band_paddings() == ~w(s7 s8 s9)
    end

    test "texture is an image and an opacity, none by default" do
      assert tokens!(%{"texture" => "none"}).texture == %{"image" => "none", "opacity" => "0"}
      dots = tokens!(%{"texture" => "dots"}).texture
      assert dots["image"] =~ "radial-gradient"
      assert dots["opacity"] == "0.07"
      assert tokens!(%{"texture" => "grain"}).texture["image"] =~ "data:image/svg+xml"
    end

    test "names the icon set and the token domains the catalogue lists" do
      tokens = tokens!(%{})
      assert "phone" in tokens.icons and "check" in tokens.icons
      assert Tokens.domain(:icon) == tokens.icons
      assert Tokens.domain(:type) == Tokens.type_styles()
      assert Tokens.domain(:color) == ~w(text muted primary secondary accent)

      assert Tokens.domain(:surface) ==
               ~w(bg surface surface_alt secondary_soft secondary primary hero)

      assert Tokens.domain(:card_surface) ==
               ~w(surface surface_alt bg secondary_soft accent_soft hero)

      assert Tokens.card_surfaces() == Tokens.domain(:card_surface)
      assert Tokens.domain(:width) == ~w(narrow standard wide)
    end

    test "contrast holds for every surface the tokens offer, across every scheme" do
      for scheme <- Theme.values("palette_scheme"), hue <- [20, 200, 300] do
        tokens = tokens!(%{"palette_scheme" => scheme, "hue" => hue})
        c = tokens.colors

        for ground <- ~w(bg surface surface_alt primary_soft secondary_soft accent_soft) do
          assert Color.contrast(c["text"], c[ground]) >= 4.5, "#{scheme} text on #{ground}"
          assert Color.contrast(c["muted"], c[ground]) >= 4.5, "#{scheme} muted on #{ground}"
          assert Color.contrast(c["primary"], c[ground]) >= 4.5, "#{scheme} primary on #{ground}"

          assert Color.contrast(c["secondary"], c[ground]) >= 4.5,
                 "#{scheme} secondary on #{ground}"
        end

        assert Color.contrast(c["on_primary"], c["primary"]) >= 4.5, "#{scheme} on primary"
        assert Color.contrast(c["on_secondary"], c["secondary"]) >= 4.5, "#{scheme} on secondary"
        assert Color.contrast(c["on_accent"], c["accent"]) >= 4.5, "#{scheme} on accent"
        assert Color.contrast(c["hero_text"], c["hero_bg"]) >= 4.5, "#{scheme} hero"
      end
    end
  end

  describe "to_css/1" do
    test "emits every token as a --t-* property in one :root block, and nothing of Bedrock's" do
      css = Tokens.to_css(tokens!(%{"type_pairing" => "editorial", "shape" => "soft"}))

      assert String.starts_with?(css, ":root{")
      assert String.ends_with?(css, "}")

      for role <- ~w(bg surface surface-alt text muted border primary primary-soft primary-strong
                     on-primary secondary secondary-soft secondary-strong on-secondary accent
                     accent-soft accent-strong on-accent hero-bg hero-text hero-muted
                     hero-secondary hero-button hero-on-button hero-border) do
        assert css =~ ~r/--t-color-#{role}:#[0-9a-f]{6}/, role
      end

      for style <- ~w(display-xl display heading subheading lede body caption eyebrow numeral),
          part <- ~w(size lh family weight case tracking) do
        assert css =~ "--t-type-#{style}-#{part}:", "#{style} #{part}"
      end

      assert css =~ ~s(--t-type-display-xl-family:"Newsreader")
      assert css =~ ~s(--t-type-body-family:"Source Sans 3")
      assert css =~ "--t-type-display-xl-weight:500"
      assert css =~ "--t-type-heading-case:none"
      assert css =~ "--t-type-eyebrow-case:uppercase"
      for step <- 1..9, do: assert(css =~ "--t-space-s#{step}:")
      assert css =~ "--t-radius-radius:8px"
      assert css =~ "--t-radius-control:6px"
      assert css =~ "--t-radius-pill:8px"
      assert css =~ "--t-rule-width:3px"
      assert css =~ ~r/--t-rule-color:#[0-9a-f]{6}/
      assert css =~ ~r/--t-shadow:6px 6px 0 #[0-9a-f]{6}/
      assert css =~ "--t-measure:65ch"
      assert css =~ "--t-container-standard:1200px"
      assert css =~ "--t-texture-image:none"
      assert css =~ "--t-texture-opacity:0"
      refute css =~ "--site-"
      refute css =~ "Barlow"
    end
  end
end
