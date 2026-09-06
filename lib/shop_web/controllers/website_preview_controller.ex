defmodule ShopWeb.WebsitePreviewController do
  use ShopWeb, :controller

  def render_scene(conn, %{"scene" => scene, "media" => media}) do
    secret = Application.get_env(:shop, :website_preview_secret)

    authorized =
      case get_req_header(conn, "authorization") do
        ["Bearer " <> supplied] when is_binary(secret) and byte_size(secret) >= 32 ->
          Plug.Crypto.secure_compare(supplied, secret)

        _ ->
          false
      end

    cond do
      not authorized ->
        conn |> put_status(401) |> json(%{error: "unauthorized"})

      byte_size(Jason.encode!(conn.body_params)) > 524_288 ->
        conn |> put_status(413) |> json(%{error: "too_large"})

      true ->
        case Shop.Website.render(scene,
               media: {:ok, media},
               csrf_token: false,
               preview_media: true
             ) do
          {:ok, html} ->
            conn |> put_resp_header("cache-control", "no-store") |> json(%{html: html})

          {:error, _} ->
            conn |> put_status(422) |> json(%{error: "incompatible_scene"})
        end
    end
  end

  def render_scene(conn, _), do: conn |> put_status(400) |> json(%{error: "invalid_request"})
end
