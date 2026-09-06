defmodule ShopWeb.MediaController do
  use ShopWeb, :controller

  # Only four raster MIME types are allowed, with nosniff; SVG and HTML are never served.
  # Tests cover hostile manifest MIME types and rejected object keys/preview signatures.
  # sobelow_skip ["XSS.ContentType", "XSS.SendResp"]
  def show(conn, %{"id" => id, "variant" => variant} = params) do
    with %{"key" => key} = entry <- media_entry(id, variant, params),
         true <- variant in ["thumb", "medium", "large"],
         true <-
           is_binary(key) and String.starts_with?(key, "media/") and
             not String.contains?(key, ["..", "\\", "?"]),
         bucket when is_binary(bucket) <- Application.get_env(:shop, :media_bucket),
         true <- Regex.match?(~r/^[a-z0-9][a-z0-9.-]+$/, bucket),
         {:ok, credentials} <- Shop.RuntimeCredentials.read(),
         {:ok, %{status: 200, body: bytes}} <- request(bucket, key, credentials) do
      conn
      |> put_resp_content_type(content_type(entry))
      |> put_resp_header(
        "cache-control",
        if(params["preview"], do: "private, no-store", else: "public, max-age=3600")
      )
      |> put_resp_header("x-content-type-options", "nosniff")
      |> send_resp(200, bytes)
    else
      nil -> send_resp(conn, 404, "Not found")
      false -> send_resp(conn, 404, "Not found")
      {:ok, %{status: 404}} -> send_resp(conn, 404, "Not found")
      _ -> send_resp(conn, 503, "Photo temporarily unavailable")
    end
  end

  defp media_entry(id, variant, %{"preview" => token}) do
    case Phoenix.Token.verify(ShopWeb.Endpoint, "website-media-preview", token, max_age: 900) do
      {:ok, %{id: ^id, variant: ^variant, entry: entry}} -> entry
      _ -> nil
    end
  end

  defp media_entry(id, variant, _) do
    case Shop.Website.media() do
      {:ok, manifest} -> get_in(manifest, ["photos", id, variant])
      _ -> nil
    end
  end

  defp request(bucket, key, credentials) do
    request = Application.get_env(:shop, :media_request, &Req.get/1)

    request.(
      url:
        "https://#{bucket}.s3.ca-central-1.amazonaws.com/" <>
          Enum.map_join(
            String.split(key, "/"),
            "/",
            &URI.encode(&1, fn char -> URI.char_unreserved?(char) end)
          ),
      aws_sigv4: Keyword.put(credentials, :service, :s3),
      redirect: false,
      retry: false,
      decode_body: false,
      receive_timeout: 10_000
    )
  end

  defp content_type(entry) do
    case entry["content_type"] do
      type when type in ["image/webp", "image/jpeg", "image/png", "image/avif"] -> type
      _ -> "image/webp"
    end
  end
end
