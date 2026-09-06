defmodule ShopWeb.PageControllerTest do
  use ShopWeb.ConnCase, async: false

  import Shop.AccountsFixtures

  alias Shop.Website.ComponentModel

  test "GET / names the shop and offers to log in", %{conn: conn} do
    conn = get(conn, ~p"/")
    html = html_response(conn, 200)
    assert html =~ Shop.name()

    if match?({:ok, _}, Shop.Website.read_scene()),
      do: assert(html =~ "lead-form"),
      else: assert(html =~ ~p"/users/log-in")
  end

  test "GET /app/leads greets a signed-in user", %{conn: conn} do
    user = user_fixture()
    conn = conn |> log_in_user(user) |> get(~p"/app/leads")
    html = html_response(conn, 200)
    assert html =~ user.email
    assert html =~ ~p"/users/log-out"
  end

  test "browser CSP forbids inline scripts and unsafe embedding", %{conn: conn} do
    response = get(conn, "/users/log-in")
    [policy] = get_resp_header(response, "content-security-policy")
    assert policy =~ "script-src 'self';"
    assert policy =~ "object-src 'none'"
    assert policy =~ "base-uri 'self'"
    assert policy =~ "form-action 'self'"
    assert policy =~ "style-src 'self' 'unsafe-inline'"
    document = response |> html_response(200) |> LazyHTML.from_document()
    assert document |> LazyHTML.query("script:not([src])") |> Enum.empty?()
  end

  test "published renderer escapes hostile text and fails closed on incompatible scenes", %{
    conn: conn
  } do
    path = Application.app_dir(:shop, "priv/published_site/scene.json")
    original = File.read(path)
    media_path = Application.app_dir(:shop, "priv/published_site/media.json")
    original_media = File.read(media_path)
    File.mkdir_p!(Path.dirname(path))

    on_exit(fn ->
      case original_media do
        {:ok, bytes} -> File.write!(media_path, bytes)
        _ -> File.rm(media_path)
      end

      case original do
        {:ok, bytes} -> File.write!(path, bytes)
        _ -> File.rm(path)
      end
    end)

    scene =
      File.read!(Path.expand("../../fixtures/website_scene.json", __DIR__)) |> Jason.decode!()

    {:ok, model} = Shop.Website.model()
    scene = Map.put(scene, "component_model_hash", ComponentModel.hash(model))
    File.write!(media_path, Jason.encode!(%{"photos" => %{}}))
    hostile = "<script>alert('not executable')</script>"
    scene = put_in(scene, ["document", "page", "title"], hostile)
    File.write!(path, Jason.encode!(scene))
    document = get(conn, "/") |> html_response(200) |> LazyHTML.from_document()
    assert document |> LazyHTML.query("title") |> LazyHTML.text() == hostile
    assert document |> LazyHTML.query("script") |> Enum.empty?()

    File.write!(path, Jason.encode!(Map.put(scene, "version", 9)))
    assert get(conn, "/").status == 503
    File.write!(path, "invalid JSON")
    assert get(conn, "/").status == 503
    File.rm!(path)
    assert get(conn, "/").status == 200
  end
end
