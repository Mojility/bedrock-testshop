defmodule Shop.Website do
  alias Phoenix.HTML.Safe

  @moduledoc "The customer's scene renderer. No management application is required."
  alias Shop.Website.{
    ComponentModel,
    Components,
    Content,
    Document,
    Media,
    Theme,
    Tokens,
    Validator
  }

  def read_scene, do: read_json("priv/published_site/scene.json")
  def model, do: read_json("priv/website/components.json")
  def media, do: read_json("priv/published_site/media.json")

  def render(scene, opts \\ []) do
    with %{
           "version" => 1,
           "document" => document,
           "theme" => axes,
           "component_model_hash" => expected
         } <- scene,
         {:ok, model} <- Keyword.get_lazy(opts, :model, &model/0),
         true <- expected == ComponentModel.hash(model),
         {:ok, manifest} <- Keyword.get_lazy(opts, :media, &media/0),
         {:ok, theme} <- Theme.derive(axes) do
      document = Map.put(document, "component_model", model)
      extensions = Document.components(document)
      tree = Document.tree(document)
      true = map_size(tree) <= 1000 and byte_size(Jason.encode!(scene)) <= 262_144
      true = Enum.all?(Map.keys(tree), &rooted?(tree, &1, 0))
      native = Keyword.get_lazy(opts, :native_components, &Components.native/0)

      true =
        Enum.all?(native, fn {name, render} ->
          Map.has_key?(extensions, name) and is_function(render, 1)
        end)

      true =
        Enum.all?(extensions, fn {name, entry} ->
          not entry.native or Map.has_key?(native, name)
        end)

      :ok =
        Validator.validate(tree, Tokens.derive(theme), document["facts"] || %{},
          components: extensions,
          photo_ids: Map.keys(manifest["photos"] || %{})
        )

      html =
        ShopWeb.WebsiteHTML.show(%{
          document: document,
          theme: theme,
          photos: Media.photos(manifest, Keyword.get(opts, :preview_media, false)),
          lead_form: Keyword.get(opts, :lead_form, Phoenix.Component.to_form(%{}, as: :lead)),
          csrf_token: Keyword.get(opts, :csrf_token, false),
          sent: Keyword.get(opts, :sent, false),
          refused: Keyword.get(opts, :refused, false),
          native_components: native,
          content: Keyword.get_lazy(opts, :content, &Content.load/0)
        })
        |> Safe.to_iodata()
        |> IO.iodata_to_binary()

      {:ok, html}
    else
      _ -> {:error, :incompatible_scene}
    end
  rescue
    _ -> {:error, :invalid_scene}
  end

  defp rooted?(_, nil, _), do: true
  defp rooted?(_, _, depth) when depth > 6, do: false

  defp rooted?(tree, id, depth) do
    case tree[id] do
      nil -> false
      node -> rooted?(tree, node.parent_id, depth + 1)
    end
  end

  # All callers supply fixed application-owned paths; scene input cannot select a filesystem path.
  # sobelow_skip ["Traversal.FileModule"]
  defp read_json(path) do
    with {:ok, bytes} <- File.read(Application.app_dir(:shop, path)), do: Jason.decode(bytes)
  end
end
