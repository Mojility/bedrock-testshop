defmodule Shop.Website.Media do
  def url(%{id: id, variants: variants, preview: true}, variant) do
    name = to_string(variant)
    entry = Map.fetch!(variants, name)

    token =
      Phoenix.Token.sign(ShopWeb.Endpoint, "website-media-preview", %{
        id: id,
        variant: name,
        entry: entry
      })

    "/media/#{id}/#{name}?preview=#{URI.encode_www_form(token)}"
  end

  def url(%{id: id}, variant), do: "/media/#{id}/#{variant}"
  def variant(%{variants: variants}, name), do: variants[to_string(name)]

  def photos(manifest, preview \\ false),
    do:
      Map.new(manifest["photos"] || %{}, fn {id, variants} ->
        {id,
         %{
           id: id,
           variants: variants,
           preview: preview,
           alt: variants["alt"],
           caption: variants["caption"]
         }}
      end)
end
