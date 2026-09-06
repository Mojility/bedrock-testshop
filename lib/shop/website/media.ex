defmodule Shop.Website.Media do
  def url(%{id: id}, variant), do: "/media/#{id}/#{variant}"
  def variant(%{variants: variants}, name), do: variants[to_string(name)]

  def photos(manifest),
    do:
      Map.new(manifest["photos"] || %{}, fn {id, variants} ->
        {id, %{id: id, variants: variants, alt: variants["alt"], caption: variants["caption"]}}
      end)
end
