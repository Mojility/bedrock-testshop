defmodule ShopWeb.MediaControllerTest do
  use ShopWeb.ConnCase, async: false

  test "serves only published variants with renewable, Canadian credentials", %{conn: conn} do
    dir = Application.app_dir(:shop, "priv/published_site")
    File.mkdir_p!(dir)
    manifest = Path.join(dir, "media.json")
    original = File.read(manifest)

    credentials =
      Path.join(System.tmp_dir!(), "media-credentials-#{System.unique_integer([:positive])}")

    config =
      Map.new(
        [:media_bucket, :media_request, :aws_credentials_file],
        &{&1, Application.get_env(:shop, &1)}
      )

    on_exit(fn ->
      Enum.each(config, fn {key, value} -> Application.put_env(:shop, key, value) end)

      case original do
        {:ok, bytes} -> File.write!(manifest, bytes)
        _ -> File.rm(manifest)
      end

      File.rm(credentials)
    end)

    File.write!(
      manifest,
      Jason.encode!(%{
        "photos" => %{"photo" => %{"large" => %{"key" => "media/photo/large.webp"}}}
      })
    )

    File.write!(
      credentials,
      Jason.encode!(%{
        "AccessKeyId" => "synthetic",
        "SecretAccessKey" => "synthetic",
        "SessionToken" => "synthetic",
        "Expiration" => DateTime.to_iso8601(DateTime.add(DateTime.utc_now(), 3600))
      })
    )

    Application.put_env(:shop, :media_bucket, "customer-bucket")
    Application.put_env(:shop, :aws_credentials_file, credentials)

    Application.put_env(:shop, :media_request, fn opts ->
      assert opts[:url] ==
               "https://customer-bucket.s3.ca-central-1.amazonaws.com/media/photo/large.webp"

      assert opts[:aws_sigv4][:region] == "ca-central-1"
      assert opts[:redirect] == false
      {:ok, %{status: 200, body: "synthetic-image"}}
    end)

    assert response(get(conn, "/media/photo/large"), 200) == "synthetic-image"
    assert get(conn, "/media/photo/original").status == 404
    assert get(conn, "/media/unpublished/large").status == 404

    photo = %{
      id: "unpublished",
      variants: %{"large" => %{"key" => "media/photo/large.webp"}},
      preview: true
    }

    preview = Shop.Website.Media.url(photo, :large)
    preview_conn = get(conn, preview)
    assert response(preview_conn, 200) == "synthetic-image"
    assert get_resp_header(preview_conn, "cache-control") == ["private, no-store"]
    assert get(conn, String.replace(preview, "/unpublished/", "/other/")).status == 404
    assert get(conn, preview <> "tampered").status == 404

    expired =
      Phoenix.Token.sign(
        ShopWeb.Endpoint,
        "website-media-preview",
        %{id: "unpublished", variant: "large", entry: photo.variants["large"]},
        signed_at: System.system_time(:second) - 901
      )

    assert get(conn, "/media/unpublished/large?preview=" <> expired).status == 404
  end
end
