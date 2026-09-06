defmodule Shop.Website.Color do
  @moduledoc """
  The colour arithmetic behind `Shop.Website.Theme`: OKLCH to sRGB, and
  WCAG 2 contrast between two sRGB colours. Written out in Elixir rather
  than pulled in as a dependency, so the theme engine has nothing to audit.

  Conversion follows Björn Ottosson's reference: OKLCH to OKLab, OKLab to
  LMS, LMS to linear sRGB, then the sRGB transfer curve. Out-of-gamut
  channels are clamped; the theme engine checks contrast on the clamped
  result, so a clipped colour never passes on paper only.
  """

  @typedoc "A colour as `#rrggbb`."
  @type hex :: String.t()

  @typedoc "A colour in OKLCH: lightness 0..1, chroma 0..~0.4, hue in degrees."
  @type oklch :: {number(), number(), number()}

  @doc """
  The perceptual distance ΔE between two OKLCH colours: the Euclidean
  distance in OKLab, where about 0.02 is a just-noticeable difference and
  0.12 reads as a different colour.

      iex> Shop.Website.Color.delta_e_ok({0.5, 0.1, 40}, {0.5, 0.1, 40})
      0.0

      iex> Shop.Website.Color.delta_e_ok({0.5, 0.0, 0}, {0.62, 0.0, 0}) |> Float.round(2)
      0.12

  """
  @spec delta_e_ok(oklch(), oklch()) :: float()
  def delta_e_ok({l1, c1, h1}, {l2, c2, h2}) do
    {a1, b1} = to_ab(c1, h1)
    {a2, b2} = to_ab(c2, h2)
    :math.sqrt(:math.pow(l1 - l2, 2) + :math.pow(a1 - a2, 2) + :math.pow(b1 - b2, 2))
  end

  @doc """
  The shortest way round the wheel between two hues, 0..180 degrees.

      iex> Shop.Website.Color.hue_gap(350, 10)
      20.0

  """
  @spec hue_gap(number(), number()) :: float()
  def hue_gap(a, b) do
    gap = abs(wrap_hue(a) - wrap_hue(b))
    min(gap, 360 - gap) * 1.0
  end

  @doc "A hue brought into 0..360."
  @spec wrap_hue(number()) :: float()
  def wrap_hue(degrees), do: :math.fmod(:math.fmod(degrees, 360) + 360, 360)

  defp to_ab(c, h) do
    radians = h * :math.pi() / 180
    {c * :math.cos(radians), c * :math.sin(radians)}
  end

  @doc """
  The sRGB hex for an OKLCH colour: lightness 0..1, chroma 0..~0.4, hue in
  degrees.

      iex> Shop.Website.Color.oklch_to_hex(0, 0, 0)
      "#000000"

      iex> Shop.Website.Color.oklch_to_hex(1, 0, 0)
      "#ffffff"

  """
  @spec oklch_to_hex(number(), number(), number()) :: hex()
  def oklch_to_hex(l, c, h) do
    {r, g, b} = oklch_to_srgb(l, c, h)
    "#" <> pair(r) <> pair(g) <> pair(b)
  end

  @doc "The sRGB channels, each 0..255, for an OKLCH colour."
  @spec oklch_to_srgb(number(), number(), number()) :: {0..255, 0..255, 0..255}
  def oklch_to_srgb(l, c, h) do
    radians = h * :math.pi() / 180
    a = c * :math.cos(radians)
    b = c * :math.sin(radians)

    l_ = l + 0.3963377774 * a + 0.2158037573 * b
    m_ = l - 0.1055613458 * a - 0.0638541728 * b
    s_ = l - 0.0894841775 * a - 1.2914855480 * b

    lms_l = l_ * l_ * l_
    lms_m = m_ * m_ * m_
    lms_s = s_ * s_ * s_

    red = 4.0767416621 * lms_l - 3.3077115913 * lms_m + 0.2309699292 * lms_s
    green = -1.2684380046 * lms_l + 2.6097574011 * lms_m - 0.3413193965 * lms_s
    blue = -0.0041960863 * lms_l - 0.7034186147 * lms_m + 1.7076147010 * lms_s

    {to_channel(red), to_channel(green), to_channel(blue)}
  end

  @doc """
  The WCAG 2 contrast ratio between two colours, 1.0 (identical) to 21.0
  (black on white). Order does not matter.

      iex> Shop.Website.Color.contrast("#000000", "#ffffff")
      21.0

  """
  @spec contrast(hex(), hex()) :: float()
  def contrast(hex_a, hex_b) do
    la = relative_luminance(hex_a)
    lb = relative_luminance(hex_b)
    {lighter, darker} = if la >= lb, do: {la, lb}, else: {lb, la}
    Float.round((lighter + 0.05) / (darker + 0.05), 2)
  end

  @doc "The WCAG relative luminance of an sRGB colour, 0.0 (black) to 1.0 (white)."
  @spec relative_luminance(hex()) :: float()
  def relative_luminance("#" <> <<r::binary-size(2), g::binary-size(2), b::binary-size(2)>>) do
    0.2126 * linear(r) + 0.7152 * linear(g) + 0.0722 * linear(b)
  end

  defp linear(pair) do
    c = String.to_integer(pair, 16) / 255

    if c <= 0.03928, do: c / 12.92, else: :math.pow((c + 0.055) / 1.055, 2.4)
  end

  defp to_channel(value) do
    value = value |> max(0.0) |> min(1.0)

    encoded =
      if value <= 0.0031308,
        do: 12.92 * value,
        else: 1.055 * :math.pow(value, 1 / 2.4) - 0.055

    round(encoded * 255)
  end

  defp pair(channel) do
    channel |> Integer.to_string(16) |> String.downcase() |> String.pad_leading(2, "0")
  end
end
