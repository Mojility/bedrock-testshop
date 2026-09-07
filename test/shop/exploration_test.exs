defmodule Shop.ExplorationTest do
  use ShopWeb.ConnCase, async: false
  alias Shop.Website.ComponentModel
  import Ecto.Query

  setup do
    css = Application.app_dir(:shop, "priv/static/assets/published/site.css")
    old_css = File.read(css)
    File.mkdir_p!(Path.dirname(css))
    File.write!(css, "body { color: black; }")

    on_exit(fn ->
      case old_css do
        {:ok, bytes} -> File.write!(css, bytes)
        _ -> File.rm(css)
      end
    end)

    dir = Application.app_dir(:shop, "priv/published_site")
    File.mkdir_p!(dir)
    original = Map.new(["scene.json", "media.json"], &{&1, File.read(Path.join(dir, &1))})
    scene = File.read!(Path.expand("../fixtures/website_scene.json", __DIR__)) |> Jason.decode!()
    {:ok, model} = Shop.Website.model()
    scene = Map.put(scene, "component_model_hash", ComponentModel.hash(model))
    photo = Ecto.UUID.generate()
    File.write!(Path.join(dir, "scene.json"), Jason.encode!(scene))

    File.write!(
      Path.join(dir, "media.json"),
      Jason.encode!(%{
        "photos" => %{photo => %{"medium" => %{"key" => "media/#{photo}/medium.webp"}}}
      })
    )

    on_exit(fn ->
      Enum.each(original, fn {name, value} ->
        case value do
          {:ok, bytes} -> File.write!(Path.join(dir, name), bytes)
          _ -> File.rm(Path.join(dir, name))
        end
      end)
    end)

    old = Application.get_env(:shop, :exploration)

    Application.put_env(:shop, :exploration, %{
      parent_origin: "https://console.example.ca",
      media_origin: "https://public.example.ca"
    })

    on_exit(fn ->
      if old,
        do: Application.put_env(:shop, :exploration, old),
        else: Application.delete_env(:shop, :exploration)
    end)

    :ok
  end

  test "embedded working copy has its own session and explicit parent", %{conn: conn} do
    conn = get(conn, "/")
    assert response(conn, 200)
    assert get_resp_header(conn, "x-frame-options") == []

    assert hd(get_resp_header(conn, "content-security-policy")) =~
             "frame-ancestors https://console.example.ca"

    opts = ShopWeb.Endpoint.session_options()
    assert opts[:key] == "__Host-shop_exploration"
    assert opts[:secure] and opts[:same_site] == "None" and opts[:extra] == "Partitioned"
    Application.delete_env(:shop, :exploration)
    assert ShopWeb.Endpoint.session_options()[:same_site] == "Lax"
  end

  test "local staff sign-in exists only in exploration mode", %{conn: conn} do
    conn = get(conn, "/users/log-in")
    assert redirected_to(conn) == "/app/leads"

    assert Shop.Repo.get_by!(Shop.Accounts.User, email: "workspace-owner@example.invalid").role ==
             "owner"

    Application.delete_env(:shop, :exploration)
    assert build_conn() |> get("/users/log-in") |> html_response(200)
  end

  test "public media uses the declared public origin and invalid entries remain denied", %{
    conn: conn
  } do
    {:ok, media} = Shop.Website.media()
    {id, _} = Enum.at(media["photos"], 0)

    if id do
      conn = get(conn, "/media/#{id}/medium")
      assert redirected_to(conn) == "https://public.example.ca/media/#{id}/medium"
    end

    assert build_conn() |> get("/media/#{Ecto.UUID.generate()}/medium") |> response(404)
  end

  test "runtime smoke exercises the real HTTP server and cleans synthetic records" do
    server = start_supervised!({Bandit, plug: ShopWeb.Endpoint, ip: {127, 0, 0, 1}, port: 0})
    {:ok, {_address, port}} = ThousandIsland.listener_info(server)
    result = Shop.Smoke.run!("http://127.0.0.1:#{port}")
    assert "staff_lead_read" in result.checks

    refute Shop.Repo.exists?(
             from u in Shop.Accounts.User, where: like(u.email, "smoke-%@example.invalid")
           )

    refute Shop.Repo.exists?(from l in Shop.Leads.Lead, where: like(l.name, "Smoke %"))
  end

  test "exploration runtime ignores production database and notification settings" do
    values = %{
      "CUSTOMER_EXPLORATION" => "true",
      "EXPLORATION_HOST" => "work.example.ca",
      "EXPLORATION_PARENT_ORIGIN" => "https://console.example.ca",
      "SECRET_KEY_BASE" => String.duplicate("x", 64),
      "DATABASE_URL" => "ecto://production:secret@production.invalid/live",
      "MAIL_ADAPTER" => "logger",
      "PHX_SERVER" => "false"
    }

    old = Map.new(values, fn {key, _} -> {key, System.get_env(key)} end)

    on_exit(fn ->
      Enum.each(old, fn {key, value} ->
        if value, do: System.put_env(key, value), else: System.delete_env(key)
      end)
    end)

    System.put_env(values)
    cfg = Config.Reader.read!(Path.expand("../../config/runtime.exs", __DIR__), env: :prod)[:shop]
    assert cfg[Shop.Repo][:socket_dir] == "/var/run/postgresql"
    assert cfg[Shop.Repo][:url] == nil
    assert cfg[Shop.Repo][:username] == "developer"
    assert cfg[Shop.Mailer][:adapter] == Shop.DisabledMailAdapter
    assert cfg[:lead_notifications] == false
    assert cfg[ShopWeb.Endpoint][:server] == false
    System.put_env("EXPLORATION_PARENT_ORIGIN", "http://unsafe.invalid")

    assert_raise RuntimeError, fn ->
      Config.Reader.read!(Path.expand("../../config/runtime.exs", __DIR__), env: :prod)
    end
  end

  test "smoke refuses production execution and remote targets" do
    assert_raise RuntimeError, "Smoke requires loopback", fn ->
      Shop.Smoke.run!("https://example.ca")
    end

    Application.delete_env(:shop, :exploration)

    assert_raise RuntimeError, "Smoke requires an isolated working copy", fn ->
      Shop.Smoke.run!()
    end
  end
end
