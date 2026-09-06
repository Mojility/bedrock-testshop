defmodule Shop.Website.Theme do
  @moduledoc """
  The theme engine from `docs/site-design-system.md`. Pure: give it the
  style axes the composer or the interviewer chose and it returns
  everything the stylesheet and the renderer need, already checked.

  A theme is a map of independent axes: a type pairing, a heading case, a
  palette scheme, a hue, a harmony, an optional accent hue, a chroma, and
  the shape, rules, elevation, density, layout, and texture choices. (The
  old `section_order` axis is retired: order is the page tree, see
  `docs/atomic-composition.md`.) Every axis is validated against its set
  of values.

  Colour is where the theory lives. From the hue and the harmony the
  engine derives a secondary and an accent hue; from the scheme it lays
  out the grounds (page, surfaces, and a soft tint of each colour) and the
  neutrals, tinted warm or cool after the hue; then it places each
  chromatic role in OKLCH so that it holds WCAG contrast on every ground
  it can sit on, reads as a different colour from the other two
  (ΔE ≥ 0.12 in OKLab, or a hue 25° away with real chroma), and
  keeps the three within a vividness budget for the scheme. When a check
  fails the role's lightness and chroma are moved within bounds; a theme
  that cannot be made readable and distinct is rejected with
  `{:error, :unreadable}` so the caller keeps its previous theme.

  The colours here are the roles the page's tokens are built from
  (`Shop.Website.Tokens`); the invariants (spacing scale, measure, type
  scale, target sizes, focus rings) live in the tokens and in
  `assets/css/site.css`, not here. Nothing here is Bedrock's own brand: no
  Barlow, no cream, no maple red.
  """
  alias Shop.Website.Color

  @pairings [
    {"grotesk_humanist",
     %{
       display: "Space Grotesk",
       body: "Nunito Sans",
       serif?: false,
       weight: 700,
       upper?: true,
       character: "modern and friendly"
     }},
    {"serif_sans",
     %{
       display: "Fraunces",
       body: "Public Sans",
       serif?: true,
       weight: 600,
       upper?: false,
       character: "warm and established"
     }},
    {"slab_sans",
     %{
       display: "Zilla Slab",
       body: "Work Sans",
       serif?: true,
       weight: 700,
       upper?: true,
       character: "solid and practical"
     }},
    {"condensed_sans",
     %{
       display: "Oswald",
       body: "Open Sans",
       serif?: false,
       weight: 600,
       upper?: true,
       character: "bold, like signage"
     }},
    {"geometric",
     %{
       display: "Outfit",
       body: "Outfit",
       serif?: false,
       weight: 600,
       upper?: false,
       character: "clean and contemporary"
     }},
    {"editorial",
     %{
       display: "Newsreader",
       body: "Source Sans 3",
       serif?: true,
       weight: 500,
       upper?: false,
       character: "calm and honest"
     }},
    {"classic_serif",
     %{
       display: "Libre Baskerville",
       body: "Lato",
       serif?: true,
       weight: 700,
       upper?: false,
       character: "traditional and trusted"
     }},
    {"rounded",
     %{
       display: "Bricolage Grotesque",
       body: "Figtree",
       serif?: false,
       weight: 700,
       upper?: false,
       character: "approachable and plain-spoken"
     }},
    {"industrial",
     %{
       display: "Archivo Black",
       body: "Archivo",
       serif?: false,
       weight: 400,
       upper?: true,
       character: "heavy and industrial"
     }},
    {"mono_accent",
     %{
       display: "IBM Plex Sans",
       body: "IBM Plex Sans",
       mono: "IBM Plex Mono",
       serif?: false,
       weight: 600,
       upper?: false,
       character: "technical and precise"
     }},
    {"humanist_serif",
     %{
       display: "Lora",
       body: "Merriweather Sans",
       serif?: true,
       weight: 600,
       upper?: false,
       character: "literary and personal"
     }},
    {"display_sans",
     %{
       display: "Sora",
       body: "Inter Tight",
       serif?: false,
       weight: 700,
       upper?: true,
       character: "sharp and confident"
     }}
  ]

  @pairing_keys Enum.map(@pairings, &elem(&1, 0))
  @pairing_table Map.new(@pairings)

  # The enumerated axes and their values, in the order the design doc lists
  # them. `hue` and `accent_hue` are validated separately.
  @enumerated [
    {"type_pairing", @pairing_keys},
    {"heading_case", ~w(sentence upper)},
    {"palette_scheme", ~w(light light_warm_surface dark_hero dark tinted)},
    {"harmony", ~w(monochrome analogous complementary split_complementary triadic)},
    {"chroma", ~w(muted medium vivid)},
    {"shape", ~w(sharp soft round)},
    {"rules", ~w(none hairline heavy)},
    {"elevation", ~w(flat soft hard)},
    {"density", ~w(airy standard compact)},
    {"hero_layout", ~w(stacked split band centred)},
    {"services_layout", ~w(cards list two_column numbered)},
    {"contact_layout", ~w(form_first phone_first side_by_side)},
    {"texture", ~w(none grain lines dots)}
  ]
  @enumerated_table Map.new(@enumerated)

  @axes ~w(type_pairing heading_case palette_scheme hue harmony accent_hue chroma shape rules
           elevation density hero_layout services_layout contact_layout texture)
  @axis_atoms Map.new(@axes, &{&1, String.to_atom(&1)})

  @chroma %{"muted" => 0.06, "medium" => 0.11, "vivid" => 0.16}

  # Where the secondary and the accent sit round the wheel from the hue,
  # per harmony. Monochrome keeps one hue and separates the roles by
  # lightness and chroma instead; complementary keeps its accent close to
  # the primary so the page is not a 50/50 clash.
  @harmonies %{
    "monochrome" => %{secondary: 0, accent: 0},
    "analogous" => %{secondary: -30, accent: 30},
    "complementary" => %{secondary: 180, accent: 20},
    "split_complementary" => %{secondary: 210, accent: 150},
    "triadic" => %{secondary: 120, accent: 240}
  }

  # A hue whose neutrals should lean warm (stone) rather than cool (slate).
  @warm_hues [{0, 110}, {330, 360}]
  @neutral_hue %{warm: 70, cool: 250}

  # Chroma of the neutral roles when they take the temperature: a tint the
  # eye reads as warmth or coolness, never as a colour.
  @neutral_chroma %{
    bg: 0.006,
    surface: 0.010,
    surface_alt: 0.012,
    text: 0.012,
    muted: 0.012,
    border: 0.012
  }

  # Where each scheme's roles start in OKLCH and how far the placer may
  # push them in search of contrast: `{start, limit}` lightness. A light
  # scheme's foregrounds move darker; a dark scheme's move lighter. The
  # grounds are fixed. `soft` is the lightness of the soft tints; `cap` is
  # the scheme's vividness budget, the most chroma primary, secondary, and
  # accent may carry between them.
  @schemes %{
    "light" => %{
      dark?: false,
      bg: 0.975,
      surface: 0.94,
      surface_alt: 0.90,
      grounds: :neutral,
      text: {0.22, 0.05},
      muted: {0.45, 0.20},
      primary: {0.48, 0.25},
      secondary: {0.46, 0.22},
      accent: {0.55, 0.30},
      border: {0.80, 0.40},
      soft: 0.92,
      cap: 0.42
    },
    "light_warm_surface" => %{
      dark?: false,
      bg: 0.975,
      surface: 0.93,
      surface_alt: 0.88,
      grounds: :washed,
      text: {0.22, 0.05},
      muted: {0.45, 0.20},
      primary: {0.42, 0.25},
      secondary: {0.44, 0.22},
      accent: {0.55, 0.30},
      border: {0.78, 0.40},
      soft: 0.92,
      cap: 0.40
    },
    "dark_hero" => %{
      dark?: false,
      bg: 0.975,
      surface: 0.94,
      surface_alt: 0.90,
      grounds: :neutral,
      text: {0.22, 0.05},
      muted: {0.45, 0.20},
      primary: {0.45, 0.25},
      secondary: {0.46, 0.22},
      accent: {0.55, 0.30},
      border: {0.80, 0.40},
      soft: 0.92,
      cap: 0.42
    },
    "dark" => %{
      dark?: true,
      bg: 0.16,
      surface: 0.22,
      surface_alt: 0.27,
      grounds: :neutral,
      text: {0.94, 0.99},
      muted: {0.78, 0.95},
      primary: {0.75, 0.95},
      secondary: {0.77, 0.95},
      accent: {0.70, 0.95},
      border: {0.42, 0.70},
      soft: 0.28,
      cap: 0.38
    },
    "tinted" => %{
      dark?: false,
      bg: 0.96,
      surface: 0.91,
      surface_alt: 0.87,
      grounds: :tinted,
      text: {0.20, 0.05},
      muted: {0.44, 0.20},
      primary: {0.42, 0.25},
      secondary: {0.44, 0.22},
      accent: {0.55, 0.30},
      border: {0.76, 0.40},
      soft: 0.92,
      cap: 0.38
    }
  }

  # The stronger tint of the `tinted` scheme and the washed surfaces of
  # `light_warm_surface`, at the hue.
  @tinted_chroma %{
    bg: 0.02,
    surface: 0.03,
    surface_alt: 0.03,
    text: 0.02,
    muted: 0.02,
    border: 0.012
  }
  @washed_chroma %{surface: 0.03, surface_alt: 0.035}

  # The dark hero and footer of `dark_hero`: the hue at L 0.20, light text.
  @dark_hero %{
    bg: {0.20, 0.02},
    text: {0.95, 0.99},
    muted: {0.80, 0.95},
    button: {0.75, 0.95},
    secondary: {0.80, 0.95},
    border: {0.45, 0.70}
  }

  @shapes %{
    "sharp" => %{radius: "0px", radius_control: "0px", radius_pill: "0px"},
    "soft" => %{radius: "8px", radius_control: "6px", radius_pill: "8px"},
    "round" => %{radius: "16px", radius_control: "12px", radius_pill: "999px"}
  }

  @densities %{
    "airy" => %{section_pad: "96px", column: "1040px"},
    "standard" => %{section_pad: "64px", column: "1120px"},
    "compact" => %{section_pad: "48px", column: "1200px"}
  }

  @nudge_step 0.01
  @text_contrast 4.5
  @mark_contrast 3.0

  # The distinctness rule between primary, secondary, and accent.
  @min_delta_e 0.12
  @min_hue_gap 25
  @min_distinct_chroma 0.06

  # Chroma multipliers by role and harmony, and the chroma options the
  # placer may try when a role cannot be made distinct where it started.
  @secondary_chroma 0.85
  @monochrome_secondary_chroma 0.55
  @near_accent_chroma 1.15
  @soft_chroma_cap 0.045
  @soft_chroma_scale 0.4
  @strong_offset 0.10
  @tonal_offset 0.14
  @accent_reach 0.20
  @near_primary_offset 0.04
  @chroma_options [1.0, 0.85, 1.15, 0.7, 1.3]
  @accent_chroma_options @chroma_options ++ [1.5, 1.75, 2.0]
  @max_chroma 0.20

  @typedoc "The semantic colour roles, each as `#rrggbb`."
  @type colors :: %{
          bg: Color.hex(),
          surface: Color.hex(),
          surface_alt: Color.hex(),
          text: Color.hex(),
          muted: Color.hex(),
          border: Color.hex(),
          primary: Color.hex(),
          primary_soft: Color.hex(),
          primary_strong: Color.hex(),
          on_primary: Color.hex(),
          secondary: Color.hex(),
          secondary_soft: Color.hex(),
          secondary_strong: Color.hex(),
          on_secondary: Color.hex(),
          accent: Color.hex(),
          accent_soft: Color.hex(),
          accent_strong: Color.hex(),
          on_accent: Color.hex(),
          hero_bg: Color.hex(),
          hero_text: Color.hex(),
          hero_muted: Color.hex(),
          hero_secondary: Color.hex(),
          hero_button: Color.hex(),
          hero_on_button: Color.hex(),
          hero_border: Color.hex()
        }

  @typedoc "A derived theme: the resolved axes plus what the stylesheet consumes."
  @type t :: %{
          type_pairing: String.t(),
          heading_case: String.t(),
          palette_scheme: String.t(),
          hue: number(),
          harmony: String.t(),
          accent_hue: number() | nil,
          chroma: String.t(),
          shape: String.t(),
          rules: String.t(),
          elevation: String.t(),
          density: String.t(),
          hero_layout: String.t(),
          services_layout: String.t(),
          contact_layout: String.t(),
          texture: String.t(),
          colors: colors(),
          oklch: %{primary: Color.oklch(), secondary: Color.oklch(), accent: Color.oklch()},
          neutral_temperature: :warm | :cool,
          font_display: String.t(),
          font_body: String.t(),
          font_mono: String.t(),
          display_weight: String.t(),
          heading_transform: String.t(),
          radius: String.t(),
          radius_control: String.t(),
          radius_pill: String.t(),
          rule: String.t(),
          rule_color: String.t(),
          shadow: String.t(),
          section_pad: String.t(),
          column: String.t()
        }

  @doc "Every axis a theme has, in the design doc's order."
  @spec axes() :: [String.t()]
  def axes, do: @axes

  @doc "The values an enumerated axis may take. Nothing for `hue` or `accent_hue`."
  @spec values(String.t()) :: [String.t()] | nil
  def values(axis), do: Map.get(@enumerated_table, axis)

  @doc "The type library's keys, in the design doc's order."
  @spec pairings() :: [String.t()]
  def pairings, do: @pairing_keys

  @doc """
  What a pairing is: its display and body faces, whether it carries
  uppercase headings, and its character in the owner's terms.
  """
  @spec pairing(String.t()) :: map() | nil
  def pairing(key), do: Map.get(@pairing_table, key)

  @doc "The pairings whose display face carries `heading_case: upper`."
  @spec upper_pairings() :: [String.t()]
  def upper_pairings, do: for({key, %{upper?: true}} <- @pairings, do: key)

  @doc """
  The three hues of a theme's settings: the primary as chosen, and the
  secondary and accent the harmony derives from it, with `accent_hue`
  honoured when given. Also used by the composer to name a palette.

      iex> Shop.Website.Theme.harmony_hues(%{"hue" => 220, "harmony" => "triadic"})
      %{primary: 220.0, secondary: 340.0, accent: 100.0}

      iex> Shop.Website.Theme.harmony_hues(%{"hue" => 40, "harmony" => "monochrome", "accent_hue" => 300})
      %{primary: 40.0, secondary: 40.0, accent: 300.0}

  """
  @spec harmony_hues(map()) :: %{primary: float(), secondary: float(), accent: float()}
  def harmony_hues(settings) do
    hue = fetch(settings, "hue")
    offsets = Map.fetch!(@harmonies, normalize(fetch(settings, "harmony")))

    %{
      primary: Color.wrap_hue(hue),
      secondary: Color.wrap_hue(hue + offsets.secondary),
      accent: Color.wrap_hue(fetch(settings, "accent_hue") || hue + offsets.accent)
    }
  end

  @doc """
  Whether a hue's neutrals lean warm or cool: reds, oranges, yellows, and
  magentas take warm greys; greens, teals, blues, and violets take cool.

      iex> Shop.Website.Theme.neutral_temperature(40)
      :warm

      iex> Shop.Website.Theme.neutral_temperature(220)
      :cool

  """
  @spec neutral_temperature(number()) :: :warm | :cool
  def neutral_temperature(hue) do
    hue = Color.wrap_hue(hue)

    if Enum.any?(@warm_hues, fn {from, to} -> hue >= from and hue < to end),
      do: :warm,
      else: :cool
  end

  @doc """
  Derives a full theme from the chosen axes. Keys may be atoms or strings;
  `accent_hue` may be absent or nil, in which case the harmony places the
  accent.

  Returns `{:error, :invalid_theme}` when any axis is missing or outside
  its set, and `{:error, :unreadable}` when no move within bounds makes
  every pairing readable and the three colours distinct. `heading_case:
  upper` is honoured only with a pairing that carries it; otherwise the
  theme resolves to sentence case.
  """
  @spec derive(map()) :: {:ok, t()} | {:error, :invalid_theme | :unreadable}
  def derive(theme) when is_map(theme) do
    with {:ok, settings} <- validate(theme),
         {:ok, palette} <- derive_colors(settings) do
      {:ok, settings |> resolve_heading_case() |> tokens(palette)}
    end
  end

  def derive(_theme), do: {:error, :invalid_theme}

  @doc """
  The theme's axes as a string-keyed map, validated. What the site
  document stores, and what the composer compares.
  """
  @spec validate(map()) :: {:ok, map()} | {:error, :invalid_theme}
  def validate(theme) when is_map(theme) do
    settings = Map.new(@axes, fn axis -> {axis, normalize(fetch(theme, axis))} end)

    if Enum.all?(@axes, &valid?(&1, settings[&1])),
      do: {:ok, settings},
      else: {:error, :invalid_theme}
  end

  def validate(_theme), do: {:error, :invalid_theme}

  @doc """
  The axes of a derived theme as the site document stores them: string
  keys, values as validated. The inverse of `derive/1` for the axes.
  """
  @spec settings(t()) :: map()
  def settings(theme) when is_map(theme) do
    Map.new(@axes, fn axis -> {axis, Map.fetch!(theme, @axis_atoms[axis])} end)
  end

  @doc """
  Nudges an OKLCH colour's lightness from `start` toward `limit` in steps
  of #{@nudge_step} until `readable?` accepts its hex. Returns `:error`
  when nothing between the two is accepted.

  Public so the search itself can be tested against an impossible ask.
  """
  @spec fit_lightness({number(), number()}, number(), number(), (Color.hex() -> boolean())) ::
          {:ok, Color.hex()} | :error
  def fit_lightness({chroma, hue}, start, limit, readable?) do
    case search({chroma, hue}, start, limit, fn oklch -> readable?.(hex(oklch)) end) do
      {:ok, oklch} -> {:ok, hex(oklch)}
      :error -> :error
    end
  end

  @doc """
  Whether two OKLCH colours read as different colours: ΔE of at least
  #{@min_delta_e}, or hues #{@min_hue_gap}° apart with chroma of at least
  #{@min_distinct_chroma} on both.
  """
  @spec distinct?(Color.oklch(), Color.oklch()) :: boolean()
  def distinct?({_l1, c1, h1} = a, {_l2, c2, h2} = b) do
    Color.delta_e_ok(a, b) >= @min_delta_e or
      (Color.hue_gap(h1, h2) >= @min_hue_gap and min(c1, c2) >= @min_distinct_chroma)
  end

  @doc "The vividness budget of a scheme: the most chroma its three colours may carry between them."
  @spec chroma_cap(String.t()) :: float()
  def chroma_cap(scheme), do: Map.fetch!(@schemes, scheme).cap

  defp search({chroma, hue}, l, limit, accept?) do
    step = if limit >= l, do: @nudge_step, else: -@nudge_step
    search({chroma, hue}, l, limit, step, accept?)
  end

  defp search({chroma, hue}, l, limit, step, accept?) do
    past? = if step > 0, do: l > limit + 1.0e-9, else: l < limit - 1.0e-9

    cond do
      past? -> :error
      accept?.({l, chroma, hue}) -> {:ok, {l, chroma, hue}}
      true -> search({chroma, hue}, l + step, limit, step, accept?)
    end
  end

  # ---- Validation ---------------------------------------------------------

  defp valid?("hue", value), do: hue?(value)
  defp valid?("accent_hue", value), do: is_nil(value) or hue?(value)

  defp valid?(axis, value), do: value in Map.fetch!(@enumerated_table, axis)

  defp hue?(value), do: is_number(value) and value >= 0 and value <= 360

  defp normalize(value) when is_atom(value) and not is_nil(value) and not is_boolean(value),
    do: Atom.to_string(value)

  defp normalize(list) when is_list(list), do: Enum.map(list, &normalize/1)
  defp normalize(value), do: value

  defp fetch(theme, key), do: Map.get(theme, key) || Map.get(theme, @axis_atoms[key])

  defp resolve_heading_case(%{"heading_case" => "upper", "type_pairing" => pairing} = settings) do
    if @pairing_table[pairing].upper?,
      do: settings,
      else: Map.put(settings, "heading_case", "sentence")
  end

  defp resolve_heading_case(settings), do: settings

  # ---- Colour -------------------------------------------------------------

  # The palette in order: grounds first (they are fixed), then the neutral
  # foregrounds fitted against them, then the three colours placed one
  # after another so each is distinct from those before it, then the tonal
  # range of each, then the hero.
  defp derive_colors(settings) do
    scheme = Map.fetch!(@schemes, settings["palette_scheme"])
    hues = harmony_hues(settings)
    temperature = neutral_temperature(hues.primary)
    chromas = budgeted_chromas(settings, scheme)

    grounds = grounds(scheme, hues, chromas, temperature)
    ground_hexes = Map.values(grounds)
    neutral = neutral_spec(scheme, hues.primary, temperature)

    with {:ok, text} <- fit(scheme.text, neutral.text, text_on(ground_hexes)),
         {:ok, muted} <- fit(scheme.muted, neutral.muted, text_on(ground_hexes)),
         {:ok, border} <- fit(scheme.border, neutral.border, marks_on(ground_hexes)),
         {:ok, primary} <-
           place(
             primary_start(settings, scheme),
             {chromas.primary, hues.primary},
             ground_hexes,
             []
           ),
         {:ok, secondary} <-
           place(
             secondary_start(settings, scheme, primary),
             {chromas.secondary, hues.secondary},
             ground_hexes,
             [primary],
             max_chroma: chromas.secondary + headroom(scheme, [primary], chromas)
           ),
         ink = ink(scheme, neutral.text, hex(text)),
         {:ok, accent} <-
           place_accent(
             settings,
             scheme,
             primary,
             secondary,
             {chromas.accent, hues.accent},
             ground_hexes,
             {hex(text), ink},
             max_chroma: chromas.accent + headroom(scheme, [primary, secondary], chromas)
           ),
         {:ok, strong} <-
           strong_shades(scheme, primary, secondary, accent, ground_hexes, {hex(text), ink}) do
      page =
        Map.merge(grounds, %{
          text: hex(text),
          muted: hex(muted),
          border: hex(border),
          primary: hex(primary),
          primary_strong: hex(strong.primary),
          on_primary: grounds.bg,
          secondary: hex(secondary),
          secondary_strong: hex(strong.secondary),
          on_secondary: grounds.bg,
          accent: hex(accent),
          accent_strong: hex(strong.accent),
          on_accent: on_color(hex(accent), grounds.bg, {hex(text), ink})
        })

      with {:ok, hero} <- hero_colors(settings, page, chromas, secondary) do
        {:ok,
         %{
           colors: Map.merge(page, hero),
           oklch: %{primary: primary, secondary: secondary, accent: accent},
           neutral_temperature: temperature
         }}
      end
    end
  end

  # How much chroma the budget still allows once the colours already placed
  # have taken theirs and the rest have their planned share.
  defp headroom(scheme, placed, chromas) do
    taken = Enum.map(placed, fn {_l, c, _h} -> c end) |> Enum.sum()
    planned = Enum.drop(Enum.map([:primary, :secondary, :accent], &chromas[&1]), length(placed))
    max(scheme.cap - taken - Enum.sum(planned), 0.0)
  end

  # The deepest neutral of a light page or the brightest of a dark one, for
  # sitting on a colour too light for the text and too dark for the page.
  defp ink(%{dark?: true}, {chroma, hue}, _text), do: hex({0.98, chroma, hue})
  defp ink(_scheme, {chroma, hue}, _text), do: hex({0.12, chroma, hue})

  # The chroma each colour starts with, brought under the scheme's cap:
  # the secondary gives first (it is the larger area), then the accent,
  # never below the chroma the distinctness rule needs.
  defp budgeted_chromas(settings, scheme) do
    base = Map.fetch!(@chroma, settings["chroma"])
    monochrome? = settings["harmony"] == "monochrome"

    secondary =
      if monochrome?,
        do: base * @monochrome_secondary_chroma,
        else: max(base * @secondary_chroma, @min_distinct_chroma)

    accent = if near_accent?(settings), do: base * @near_accent_chroma, else: base
    over = max(base + secondary + accent - scheme.cap, 0.0)
    secondary_give = min(over, max(secondary - @min_distinct_chroma, 0.0))
    accent_give = min(over - secondary_give, max(accent - @min_distinct_chroma, 0.0))

    %{primary: base, secondary: secondary - secondary_give, accent: accent - accent_give}
  end

  # The accent sits near the primary in hue (monochrome and complementary),
  # so it must be told apart by tone: lighter and brighter on a light page.
  defp near_accent?(settings) do
    %{primary: primary, accent: accent} = harmony_hues(settings)
    Color.hue_gap(primary, accent) < @min_hue_gap
  end

  defp grounds(scheme, hues, chromas, temperature) do
    tint = ground_tints(scheme, hues.primary, temperature)

    %{
      bg: hex({scheme.bg, tint.bg.chroma, tint.bg.hue}),
      surface: hex({scheme.surface, tint.surface.chroma, tint.surface.hue}),
      surface_alt: hex({scheme.surface_alt, tint.surface_alt.chroma, tint.surface_alt.hue}),
      primary_soft: hex(soft(scheme, chromas.primary, hues.primary)),
      secondary_soft: hex(soft(scheme, chromas.secondary, hues.secondary)),
      accent_soft: hex(soft(scheme, chromas.accent, hues.accent))
    }
  end

  defp ground_tints(%{grounds: :tinted}, hue, _temperature) do
    Map.new([:bg, :surface, :surface_alt], &{&1, %{hue: hue, chroma: @tinted_chroma[&1]}})
  end

  defp ground_tints(%{grounds: :washed}, hue, temperature) do
    %{
      bg: %{hue: @neutral_hue[temperature], chroma: @neutral_chroma.bg},
      surface: %{hue: hue, chroma: @washed_chroma.surface},
      surface_alt: %{hue: hue, chroma: @washed_chroma.surface_alt}
    }
  end

  defp ground_tints(%{grounds: :neutral}, _hue, temperature) do
    Map.new(
      [:bg, :surface, :surface_alt],
      &{&1, %{hue: @neutral_hue[temperature], chroma: @neutral_chroma[&1]}}
    )
  end

  # A soft is the colour as a surface: a pale tint on a light page, a deep
  # one on a dark page, with only enough chroma to read as that colour.
  defp soft(scheme, chroma, hue) do
    {scheme.soft, min(@soft_chroma_cap, chroma * @soft_chroma_scale), hue}
  end

  defp neutral_spec(%{grounds: :tinted}, hue, _temperature) do
    %{
      text: {@tinted_chroma.text, hue},
      muted: {@tinted_chroma.muted, hue},
      border: {@tinted_chroma.border, hue}
    }
  end

  defp neutral_spec(_scheme, _hue, temperature) do
    hue = @neutral_hue[temperature]

    %{
      text: {@neutral_chroma.text, hue},
      muted: {@neutral_chroma.muted, hue},
      border: {@neutral_chroma.border, hue}
    }
  end

  # A primary whose accent shares its hue starts a step deeper, so the
  # accent has tonal room above it.
  defp primary_start(settings, scheme) do
    {start, limit} = scheme.primary

    if near_accent?(settings),
      do: {start + tonal_step(scheme, @near_primary_offset), limit},
      else: {start, limit}
  end

  # In monochrome the secondary is the primary's deeper, duller self; the
  # start is set off from where the primary landed so the two are apart.
  defp secondary_start(%{"harmony" => "monochrome"}, scheme, {primary_l, _c, _h}) do
    {_start, limit} = scheme.secondary
    {primary_l + tonal_step(scheme, @tonal_offset), limit}
  end

  defp secondary_start(_settings, scheme, _primary), do: scheme.secondary

  # A near-hue accent (monochrome, complementary) is the primary's lighter,
  # brighter self, held at mark contrast; it may come back toward the
  # primary only as far as the two stay distinct. Any other accent starts
  # where the scheme says and is fitted like a mark.
  defp place_accent(
         settings,
         scheme,
         {primary_l, _c, _h} = primary,
         secondary,
         spec,
         grounds,
         ons,
         opts
       ) do
    {start, limit} =
      if near_accent?(settings),
        do: {primary_l - tonal_step(scheme, @accent_reach), primary_l},
        else: scheme.accent

    place(
      {start, limit},
      spec,
      grounds,
      [primary, secondary],
      [
        contrast: @mark_contrast,
        chroma_options: @accent_chroma_options,
        extra: fn oklch -> on_color(hex(oklch), List.first(grounds), ons) != nil end
      ] ++ opts
    )
  end

  # Towards the foreground side of the scheme: darker on a light page,
  # lighter on a dark one.
  defp tonal_step(%{dark?: true}, offset), do: offset
  defp tonal_step(_scheme, offset), do: -offset

  # Places one colour: from its start lightness toward its limit, at its
  # chroma and then at the chroma options in turn, the first setting that
  # holds `contrast` on every ground, is distinct from every colour in
  # `apart_from`, and passes `extra` wins.
  defp place({start, limit}, {chroma, hue}, grounds, apart_from, opts \\ []) do
    contrast = Keyword.get(opts, :contrast, @text_contrast)
    extra = Keyword.get(opts, :extra, fn _oklch -> true end)
    max_chroma = min(Keyword.get(opts, :max_chroma, @max_chroma), @max_chroma)
    chroma_options = Keyword.get(opts, :chroma_options, @chroma_options)
    pairings = Enum.map(grounds, &{&1, contrast})

    accept? = fn oklch ->
      readable?(hex(oklch), pairings) and Enum.all?(apart_from, &distinct?(oklch, &1)) and
        extra.(oklch)
    end

    chroma_options
    |> Enum.map(&min(chroma * &1, max(max_chroma, chroma)))
    |> Enum.uniq()
    |> Enum.find_value({:error, :unreadable}, fn c ->
      case search({c, hue}, start, limit, accept?) do
        {:ok, oklch} -> {:ok, oklch}
        :error -> nil
      end
    end)
  end

  # The deeper shade of each colour, for hover and emphasis: pushed away
  # from the colour that sits on it by a tenth of lightness, then brought
  # back only as far as it must to keep its contrast on every ground.
  defp strong_shades(scheme, primary, secondary, accent, grounds, ons) do
    bg = List.first(grounds)

    with {:ok, p} <- strong(scheme, primary, grounds, @text_contrast, bg),
         {:ok, s} <- strong(scheme, secondary, grounds, @text_contrast, bg),
         {:ok, a} <-
           strong(scheme, accent, grounds, @mark_contrast, on_color(hex(accent), bg, ons)) do
      {:ok, %{primary: p, secondary: s, accent: a}}
    end
  end

  defp strong(scheme, {l, c, h}, grounds, contrast, on) do
    away = if scheme.dark?, do: @strong_offset, else: -@strong_offset
    # Away from `on`: when the accent's on-colour is the text, deeper means
    # toward the page ground instead.
    direction = if on == List.first(grounds), do: away, else: -away
    start = min(max(l + direction, 0.05), 0.98)
    pairings = Enum.map(grounds, &{&1, contrast}) ++ [{on, @text_contrast}]

    case search({c, h}, start, l, fn oklch -> readable?(hex(oklch), pairings) end) do
      {:ok, oklch} -> {:ok, oklch}
      :error -> {:error, :unreadable}
    end
  end

  # What sits on a colour: the page ground when it reads there, else the
  # text colour, else the ink, else nothing (the caller moves the colour).
  defp on_color(hex, bg, {text, ink}) do
    Enum.find([bg, text, ink], &(Color.contrast(hex, &1) >= @text_contrast))
  end

  # The hero surface: dark at the hue for `dark_hero`, painted in the primary
  # for a `band` hero, otherwise the page's own roles. A footer that wants
  # the dark treatment sits on the hero surface too (`Shop.Website.Recipes`).
  defp hero_colors(%{"palette_scheme" => "dark_hero", "hue" => hue}, _page, chromas, secondary) do
    temperature = neutral_temperature(hue)
    neutral = neutral_spec(%{grounds: :neutral}, hue, temperature)
    bg = hex({elem(@dark_hero.bg, 0), elem(@dark_hero.bg, 1), hue})
    {_l, _c, secondary_hue} = secondary

    with {:ok, text} <- fit(@dark_hero.text, neutral.text, text_on([bg])),
         {:ok, muted} <- fit(@dark_hero.muted, neutral.muted, text_on([bg])),
         {:ok, button} <- fit(@dark_hero.button, {chromas.primary, hue}, text_on([bg])),
         {:ok, hero_secondary} <-
           fit(@dark_hero.secondary, {chromas.secondary, secondary_hue}, text_on([bg])),
         {:ok, border} <- fit(@dark_hero.border, neutral.border, marks_on([bg])) do
      {:ok,
       %{
         hero_bg: bg,
         hero_text: hex(text),
         hero_muted: hex(muted),
         hero_secondary: hex(hero_secondary),
         hero_button: hex(button),
         hero_on_button: bg,
         hero_border: hex(border)
       }}
    end
  end

  defp hero_colors(%{"hero_layout" => "band"}, page, _chromas, _secondary) do
    {:ok,
     %{
       hero_bg: page.primary,
       hero_text: page.on_primary,
       hero_muted: page.on_primary,
       hero_secondary: page.on_primary,
       hero_button: page.on_primary,
       hero_on_button: page.primary,
       hero_border: page.on_primary
     }}
  end

  defp hero_colors(_settings, page, _chromas, _secondary) do
    {:ok,
     %{
       hero_bg: page.bg,
       hero_text: page.text,
       hero_muted: page.muted,
       hero_secondary: page.secondary,
       hero_button: page.primary,
       hero_on_button: page.on_primary,
       hero_border: page.border
     }}
  end

  defp text_on(backgrounds), do: Enum.map(backgrounds, &{&1, @text_contrast})
  defp marks_on(backgrounds), do: Enum.map(backgrounds, &{&1, @mark_contrast})

  defp readable?(hex, pairings) do
    Enum.all?(pairings, fn {against, ratio} -> Color.contrast(hex, against) >= ratio end)
  end

  defp fit({start, limit}, {chroma, hue}, pairings) do
    case search({chroma, hue}, start, limit, fn oklch -> readable?(hex(oklch), pairings) end) do
      {:ok, oklch} -> {:ok, oklch}
      :error -> {:error, :unreadable}
    end
  end

  defp hex({l, c, h}), do: Color.oklch_to_hex(l, c, h)

  # ---- Tokens -------------------------------------------------------------

  defp tokens(settings, palette) do
    pairing = Map.fetch!(@pairing_table, settings["type_pairing"])
    shape = Map.fetch!(@shapes, settings["shape"])
    density = Map.fetch!(@densities, settings["density"])
    dark? = Map.fetch!(@schemes, settings["palette_scheme"]).dark?
    colors = palette.colors

    settings
    |> Map.new(fn {axis, value} -> {@axis_atoms[axis], value} end)
    |> Map.merge(shape)
    |> Map.merge(density)
    |> Map.merge(palette)
    |> Map.merge(%{
      font_display: stack(pairing.display, pairing.serif?),
      font_body: stack(pairing.body, false),
      font_mono: mono_stack(pairing[:mono], pairing.body),
      display_weight: Integer.to_string(pairing.weight),
      heading_transform: if(settings["heading_case"] == "upper", do: "uppercase", else: "none"),
      rule: rule_width(settings["rules"]),
      rule_color: rule_color(settings["rules"], colors),
      shadow: shadow(settings["elevation"], colors, dark?)
    })
  end

  defp stack(family, true), do: ~s("#{family}", Georgia, "Times New Roman", serif)
  defp stack(family, false), do: ~s("#{family}", "Helvetica Neue", Arial, sans-serif)

  defp mono_stack(nil, body), do: stack(body, false)
  defp mono_stack(mono, _body), do: ~s("#{mono}", ui-monospace, Menlo, monospace)

  defp rule_width("none"), do: "0px"
  defp rule_width("hairline"), do: "1px"
  defp rule_width("heavy"), do: "3px"

  defp rule_color("none", _colors), do: "transparent"
  defp rule_color("hairline", colors), do: colors.border
  defp rule_color("heavy", colors), do: colors.text

  defp shadow("flat", _colors, _dark?), do: "none"
  defp shadow("soft", _colors, false), do: "0 8px 24px rgb(0 0 0 / 0.08)"
  defp shadow("soft", _colors, true), do: "0 8px 24px rgb(0 0 0 / 0.45)"
  defp shadow("hard", colors, _dark?), do: "6px 6px 0 " <> colors.text
end
