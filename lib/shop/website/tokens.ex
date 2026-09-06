defmodule Shop.Website.Tokens do
  @moduledoc """
  The tokens of a tenant site (`docs/atomic-composition.md`, "Tokens"):
  every visual value a page can refer to, derived from a theme
  (`Shop.Website.Theme.derive/1`) and never chosen one by one.

    * colour roles: the neutrals `bg`, `surface`, `surface_alt`, `text`,
      `muted`, `border`; each of `primary`, `secondary`, and `accent` with
      its `*_soft` tint (a surface), its `*_strong` shade (hover and
      emphasis), and the `on_*` colour that sits on it; and the hero
      surface's `hero_bg`, `hero_text`, `hero_muted`, `hero_secondary`,
      `hero_button`, `hero_on_button`, `hero_border`
    * type styles: `display_xl`, `display`, `heading`, `subheading`, `lede`,
      `body`, `caption`, `eyebrow`, `numeral`, each a size, line height,
      family, weight, case, and tracking, per pairing and heading case
    * spacing steps `s1`..`s9` (4, 8, 12, 16, 24, 32, 48, 64, 96 px)
    * radii, the rule weight and colour, the shadow, the measure, container
      widths by density, the texture, and the icon set

  Every node prop that names a colour, a type style, a gap, a width, or a
  surface names one of these, and `Shop.Website.Validator` checks it
  against this module for the current theme. `to_css/1` emits them as
  `--t-*` custom properties for `assets/css/site.css`, which knows only
  these and the levels. Contrast is a property of the colours, checked by
  the theme engine, so any tree that refers only to tokens is readable.
  """
  alias Shop.Website.Theme

  @type_styles ~w(display_xl display heading subheading lede body caption eyebrow numeral)
  @spaces ~w(s1 s2 s3 s4 s5 s6 s7 s8 s9)
  @space_px %{
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
  @gaps ~w(s2 s3 s4 s5 s6 s7)
  @band_paddings ~w(s7 s8 s9)
  @card_paddings ~w(s4 s5 s6)
  @widths ~w(narrow standard wide)
  @surfaces ~w(bg surface surface_alt secondary_soft secondary primary hero)
  @card_surfaces ~w(surface surface_alt bg secondary_soft accent_soft hero)
  @text_colors ~w(text muted primary secondary accent)
  @measure "65ch"

  # Container widths by density: the design doc's column for `standard`, a
  # reading column for `narrow`, and a little more room for `wide`.
  @containers %{
    "airy" => %{"narrow" => "680px", "standard" => "1040px", "wide" => "1200px"},
    "standard" => %{"narrow" => "720px", "standard" => "1120px", "wide" => "1280px"},
    "compact" => %{"narrow" => "760px", "standard" => "1200px", "wide" => "1360px"}
  }

  # Sizes and line heights are the same for every shop; the faces, weights,
  # and case come from the pairing and the heading case.
  @sizes %{
    "display_xl" => {"clamp(2.5rem, 1.6rem + 3vw, 3.5rem)", "1.05", "-0.01em"},
    "display" => {"2.25rem", "1.1", "0"},
    "heading" => {"1.75rem", "1.15", "0"},
    "subheading" => {"1.125rem", "1.3", "0"},
    "lede" => {"1.375rem", "1.4", "0"},
    "body" => {"1.125rem", "1.55", "0"},
    "caption" => {"0.875rem", "1.4", "0"},
    "eyebrow" => {"0.875rem", "1.4", "0.08em"},
    "numeral" => {"2.75rem", "1", "-0.01em"}
  }

  @icons ~w(phone mail clock map_pin check wrench shield star bolt flame droplet
            thermometer truck calendar alert arrow_right info)

  @textures %{
    "none" => {"none", "0"},
    "lines" =>
      {"repeating-linear-gradient(135deg, currentColor 0 1px, transparent 1px 12px)", "0.05"},
    "dots" => {"radial-gradient(currentColor 1px, transparent 1.5px)", "0.07"},
    "grain" =>
      {"url(\"data:image/svg+xml,%3Csvg xmlns='http://www.w3.org/2000/svg' width='160' height='160'%3E%3Cfilter id='n'%3E%3CfeTurbulence type='fractalNoise' baseFrequency='0.9' numOctaves='2' stitchTiles='stitch'/%3E%3CfeColorMatrix values='0 0 0 0 0 0 0 0 0 0 0 0 0 0 0 0 0 0 1 0'/%3E%3C/filter%3E%3Crect width='100%25' height='100%25' filter='url(%23n)'/%3E%3C/svg%3E\")",
       "0.06"}
  }

  @typedoc "One type style, ready for CSS."
  @type type_style :: %{
          size: String.t(),
          line_height: String.t(),
          family: String.t(),
          weight: String.t(),
          case: String.t(),
          tracking: String.t()
        }

  @typedoc "The tokens of one theme."
  @type t :: %{
          colors: %{String.t() => String.t()},
          type: %{String.t() => type_style()},
          space: %{String.t() => String.t()},
          radii: %{String.t() => String.t()},
          rule: %{String.t() => String.t()},
          shadow: String.t(),
          measure: String.t(),
          container: %{String.t() => String.t()},
          texture: %{String.t() => String.t()},
          icons: [String.t()]
        }

  @doc "The names of the type styles, in the design doc's order."
  @spec type_styles() :: [String.t()]
  def type_styles, do: @type_styles

  @doc "The spacing steps, `s1`..`s9`."
  @spec spaces() :: [String.t()]
  def spaces, do: @spaces

  @doc "The steps a layout may use as its gap."
  @spec gaps() :: [String.t()]
  def gaps, do: @gaps

  @doc "The steps a band may use as its padding."
  @spec band_paddings() :: [String.t()]
  def band_paddings, do: @band_paddings

  @doc "The steps a card may use as its padding."
  @spec card_paddings() :: [String.t()]
  def card_paddings, do: @card_paddings

  @doc "The container widths."
  @spec widths() :: [String.t()]
  def widths, do: @widths

  @doc "The surfaces a band may sit on."
  @spec surfaces() :: [String.t()]
  def surfaces, do: @surfaces

  @doc "The surfaces a card may sit on: the page's, and the soft tints of the secondary and accent."
  @spec card_surfaces() :: [String.t()]
  def card_surfaces, do: @card_surfaces

  @doc "The colour roles text may take."
  @spec text_colors() :: [String.t()]
  def text_colors, do: @text_colors

  @doc "The curated icon set, by name."
  @spec icons() :: [String.t()]
  def icons, do: @icons

  @doc "The values a token domain may take, for the catalogue and the validator."
  @spec domain(atom()) :: [String.t()]
  def domain(:type), do: @type_styles
  def domain(:color), do: @text_colors
  def domain(:gap), do: @gaps
  def domain(:width), do: @widths
  def domain(:surface), do: @surfaces
  def domain(:card_surface), do: @card_surfaces
  def domain(:band_padding), do: @band_paddings
  def domain(:card_padding), do: @card_paddings
  def domain(:icon), do: @icons

  @doc "Every token of a derived theme."
  @spec derive(Theme.t()) :: t()
  def derive(%{colors: colors} = theme) do
    %{
      colors: Map.new(colors, fn {role, hex} -> {Atom.to_string(role), hex} end),
      type: Map.new(@type_styles, &{&1, type_style(&1, theme)}),
      space: @space_px,
      radii: %{
        "radius" => theme.radius,
        "control" => theme.radius_control,
        "pill" => theme.radius_pill
      },
      rule: %{"width" => theme.rule, "color" => theme.rule_color},
      shadow: theme.shadow,
      measure: @measure,
      container: Map.fetch!(@containers, theme.density),
      texture: texture(theme.texture),
      icons: @icons
    }
  end

  @doc """
  The tokens as a `:root`-scoped block of `--t-*` custom properties, for
  inline injection ahead of `site.css`. Every value is engine-made.
  """
  @spec to_css(t()) :: String.t()
  def to_css(tokens) do
    properties =
      Enum.map(tokens.colors, fn {role, hex} -> {"color-" <> dash(role), hex} end) ++
        Enum.flat_map(tokens.type, fn {style, values} ->
          prefix = "type-" <> dash(style) <> "-"

          [
            {prefix <> "size", values.size},
            {prefix <> "lh", values.line_height},
            {prefix <> "family", values.family},
            {prefix <> "weight", values.weight},
            {prefix <> "case", values.case},
            {prefix <> "tracking", values.tracking}
          ]
        end) ++
        Enum.map(tokens.space, fn {step, px} -> {"space-" <> step, px} end) ++
        Enum.map(tokens.radii, fn {name, value} -> {"radius-" <> name, value} end) ++
        [
          {"rule-width", tokens.rule["width"]},
          {"rule-color", tokens.rule["color"]},
          {"shadow", tokens.shadow},
          {"measure", tokens.measure}
        ] ++
        Enum.map(tokens.container, fn {width, px} -> {"container-" <> width, px} end) ++
        [
          {"texture-image", tokens.texture["image"]},
          {"texture-opacity", tokens.texture["opacity"]}
        ]

    ":root{" <>
      Enum.map_join(properties, ";", fn {name, value} -> "--t-" <> name <> ":" <> value end) <>
      "}"
  end

  defp type_style(style, theme) do
    {size, line_height, tracking} = Map.fetch!(@sizes, style)

    %{
      size: size,
      line_height: line_height,
      family: family(style, theme),
      weight: weight(style, theme),
      case: text_case(style, theme),
      tracking: tracking
    }
  end

  defp family(style, theme) when style in ~w(display_xl display heading numeral),
    do: theme.font_display

  defp family(style, theme) when style in ~w(caption eyebrow), do: theme.font_mono
  defp family(_style, theme), do: theme.font_body

  defp weight(style, theme) when style in ~w(display_xl display heading numeral),
    do: theme.display_weight

  defp weight(style, _theme) when style in ~w(subheading eyebrow), do: "600"
  defp weight(_style, _theme), do: "400"

  defp text_case(style, theme) when style in ~w(display_xl display heading),
    do: theme.heading_transform

  defp text_case("eyebrow", _theme), do: "uppercase"
  defp text_case(_style, _theme), do: "none"

  defp texture(name) do
    {image, opacity} = Map.fetch!(@textures, name)
    %{"image" => image, "opacity" => opacity}
  end

  defp dash(name), do: String.replace(name, "_", "-")
end
