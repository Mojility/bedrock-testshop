defmodule ShopWeb.PublicFontTest do
  use ShopWeb.ConnCase, async: false

  setup do
    name = "cors-test-#{System.unique_integer([:positive])}"

    paths = [
      "/assets/published/fonts/#{name}.woff2",
      "/assets/published/fonts/#{name}.txt",
      "/assets/published/#{name}.css",
      "/assets/#{name}.woff2"
    ]

    files = Enum.map(paths, &Application.app_dir(:shop, "priv/static" <> &1))

    Enum.each(files, fn path ->
      File.mkdir_p!(Path.dirname(path))
      File.write!(path, "synthetic-public-asset")
    end)

    on_exit(fn -> Enum.each(files, &File.rm!/1) end)
    %{paths: paths}
  end

  test "sandboxed previews can read published fonts without credentials", %{
    conn: conn,
    paths: [font | _]
  } do
    for method <- [:get, :head] do
      response = conn |> put_req_header("origin", "null") |> dispatch(@endpoint, method, font)
      assert response.status == 200
      assert get_resp_header(response, "access-control-allow-origin") == ["*"]
      assert get_resp_header(response, "access-control-allow-credentials") == []
    end
  end

  test "cached published fonts retain cross-origin access", %{conn: conn, paths: [font | _]} do
    original = get(conn, font)
    [etag] = get_resp_header(original, "etag")

    cached =
      conn
      |> put_req_header("origin", "null")
      |> put_req_header("if-none-match", etag)
      |> get(font)

    assert cached.status == 304
    assert get_resp_header(cached, "access-control-allow-origin") == ["*"]
    assert get_resp_header(cached, "access-control-allow-credentials") == []
  end

  test "other static assets, media and authenticated pages keep their CORS boundary", %{
    conn: conn,
    paths: [_font | other_assets]
  } do
    for path <- other_assets ++ ["/media/unpublished/large", "/users/log-in"] do
      response = conn |> put_req_header("origin", "null") |> get(path)
      assert response.status in [200, 404]
      assert get_resp_header(response, "access-control-allow-origin") == []
      assert get_resp_header(response, "access-control-allow-credentials") == []
    end
  end
end
