defmodule ShopWeb.WebsitePreviewControllerTest do
  use ShopWeb.ConnCase, async: false

  setup do
    old = Application.fetch_env(:shop, :website_preview_secret)

    on_exit(fn ->
      case old do
        {:ok, value} -> Application.put_env(:shop, :website_preview_secret, value)
        :error -> Application.delete_env(:shop, :website_preview_secret)
      end
    end)

    Application.put_env(:shop, :website_preview_secret, String.duplicate("s", 32))

    scene =
      File.read!(Path.expand("../../fixtures/website_scene.json", __DIR__)) |> Jason.decode!()

    %{body: %{scene: scene, media: %{"version" => 1, "photos" => %{}}}}
  end

  test "preview requires its own credential and renders the real runtime", %{
    conn: conn,
    body: body
  } do
    assert conn |> post("/api/website/preview", body) |> json_response(401)
    conn = build_conn() |> put_req_header("authorization", "Bearer " <> String.duplicate("s", 32))
    response = conn |> post("/api/website/preview", body) |> json_response(200)
    assert response["html"] =~ "Scene test"
  end
end
