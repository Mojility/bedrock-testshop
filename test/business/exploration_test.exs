defmodule Business.ExplorationTest do
  use BusinessWeb.ConnCase, async: false
  alias Business.Website.ComponentModel
  import Ecto.Query

  setup do
    Business.SmokeFault.reset_loopback_rate_limit()
    on_exit(&Business.SmokeFault.reset_loopback_rate_limit/0)

    for path <- ["priv/static/assets/published/site.css", "priv/static/assets/css/app.css"] do
      css = Application.app_dir(:business, path)
      old_css = File.read(css)
      File.mkdir_p!(Path.dirname(css))
      File.write!(css, "body { color: black; }")

      on_exit(fn ->
        case old_css do
          {:ok, bytes} -> File.write!(css, bytes)
          _ -> File.rm(css)
        end
      end)
    end

    dir = Application.app_dir(:business, "priv/published_site")
    File.mkdir_p!(dir)
    original = Map.new(["scene.json", "media.json"], &{&1, File.read(Path.join(dir, &1))})
    scene = File.read!(Path.expand("../fixtures/website_scene.json", __DIR__)) |> Jason.decode!()
    {:ok, model} = Business.Website.model()
    assert scene["component_model_hash"] == ComponentModel.hash(model)
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

    old = Application.get_env(:business, :exploration)

    Application.put_env(:business, :exploration, %{
      parent_origin: "https://console.example.ca",
      media_origin: "https://public.example.ca"
    })

    on_exit(fn ->
      if old,
        do: Application.put_env(:business, :exploration, old),
        else: Application.delete_env(:business, :exploration)
    end)

    :ok
  end

  test "embedded working copy has its own session and explicit parent", %{conn: conn} do
    conn = get(conn, "/")
    assert response(conn, 200)
    assert get_resp_header(conn, "x-frame-options") == []

    assert hd(get_resp_header(conn, "content-security-policy")) =~
             "frame-ancestors https://console.example.ca"

    opts = BusinessWeb.Endpoint.session_options()
    assert opts[:key] == "__Host-business_exploration"
    assert opts[:secure] and opts[:same_site] == "None" and opts[:extra] == "Partitioned"
    Application.delete_env(:business, :exploration)
    assert BusinessWeb.Endpoint.session_options()[:same_site] == "Lax"
  end

  test "preview allows both explicit console origins without admitting other sites", %{conn: conn} do
    config = Application.fetch_env!(:business, :exploration)

    Application.put_env(
      :business,
      :exploration,
      Map.put(config, :platform_origin, "https://example.ca")
    )

    conn = get(conn, "/")
    [policy] = get_resp_header(conn, "content-security-policy")

    ancestors =
      policy |> String.split("; ") |> Enum.find(&String.starts_with?(&1, "frame-ancestors"))

    assert ancestors == "frame-ancestors https://console.example.ca https://example.ca"
    assert get_resp_header(conn, "x-frame-options") == []
  end

  test "local staff sign-in exists only in exploration mode", %{conn: conn} do
    conn = get(conn, "/users/log-in")
    assert redirected_to(conn) == "/app/leads"

    assert Business.Repo.get_by!(Business.Accounts.User, email: "workspace-owner@example.invalid").role ==
             "owner"

    Application.delete_env(:business, :exploration)
    assert build_conn() |> get("/users/log-in") |> html_response(200)
  end

  test "public media uses the declared public origin and invalid entries remain denied", %{
    conn: conn
  } do
    {:ok, media} = Business.Website.media()
    {id, _} = Enum.at(media["photos"], 0)

    if id do
      conn = get(conn, "/media/#{id}/medium")
      assert redirected_to(conn) == "https://public.example.ca/media/#{id}/medium"
    end

    assert build_conn() |> get("/media/#{Ecto.UUID.generate()}/medium") |> response(404)
  end

  test "runtime smoke exercises the real HTTP server and cleans synthetic records" do
    server = start_supervised!({Bandit, plug: BusinessWeb.Endpoint, ip: {127, 0, 0, 1}, port: 0})
    {:ok, {_address, port}} = ThousandIsland.listener_info(server)
    result = Business.Smoke.run!("http://127.0.0.1:#{port}")
    assert "staff_lead_read" in result.checks

    refute Business.Repo.exists?(
             from u in Business.Accounts.User, where: like(u.email, "smoke-%@example.invalid")
           )

    refute Business.Repo.exists?(from l in Business.Leads.Lead, where: like(l.name, "Smoke %"))
  end

  test "unpublished baseline passes every smoke capability check" do
    File.rm!(Application.app_dir(:business, "priv/published_site/scene.json"))
    server = start_supervised!({Bandit, plug: BusinessWeb.Endpoint, ip: {127, 0, 0, 1}, port: 0})
    {:ok, {_address, port}} = ThousandIsland.listener_info(server)
    result = Business.Smoke.run!("http://127.0.0.1:#{port}")
    assert "lead_form" in result.checks
    assert "lead_persistence" in result.checks
    assert "csrf_denial" in result.checks
    assert "staff_lead_read" in result.checks
  end

  test "invalid published scene fails smoke and cleans only its synthetic records" do
    {:ok, retained} = Business.Leads.submit(%{name: "Existing enquiry", phone: "555"})
    File.write!(Application.app_dir(:business, "priv/published_site/scene.json"), "invalid")
    server = start_supervised!({Bandit, plug: BusinessWeb.Endpoint, ip: {127, 0, 0, 1}, port: 0})
    {:ok, {_address, port}} = ThousandIsland.listener_info(server)

    error =
      assert_raise RuntimeError, "smoke_failed:public_page", fn ->
        Business.Smoke.run!("http://127.0.0.1:#{port}")
      end

    assert Business.Smoke.failure_check(error) == "public_page"
    assert Business.Repo.get!(Business.Leads.Lead, retained.id) == retained
    refute Business.Repo.exists?(from l in Business.Leads.Lead, where: like(l.name, "Smoke %"))

    refute Business.Repo.exists?(
             from u in Business.Accounts.User, where: like(u.email, "smoke-%@example.invalid")
           )
  end

  test "a 200 home page without lead capture still fails smoke" do
    server =
      start_supervised!({Bandit, plug: Business.SmokeWithoutLeads, ip: {127, 0, 0, 1}, port: 0})

    {:ok, {_address, port}} = ThousandIsland.listener_info(server)

    error =
      assert_raise RuntimeError, "smoke_failed:lead_form", fn ->
        Business.Smoke.run!("http://127.0.0.1:#{port}")
      end

    assert Business.Smoke.failure_check(error) == "lead_form"
  end

  test "missing stylesheet delivery still fails smoke" do
    File.rm!(Application.app_dir(:business, "priv/static/assets/published/site.css"))
    server = start_supervised!({Bandit, plug: BusinessWeb.Endpoint, ip: {127, 0, 0, 1}, port: 0})
    {:ok, {_address, port}} = ThousandIsland.listener_info(server)

    error =
      assert_raise RuntimeError, "smoke_failed:stylesheet_delivery", fn ->
        Business.Smoke.run!("http://127.0.0.1:#{port}")
      end

    assert Business.Smoke.failure_check(error) == "stylesheet_delivery"
  end

  test "smoke failure diagnostics never include arbitrary exception details" do
    assert Business.Smoke.failure_check(%RuntimeError{message: "smoke_failed:lead_form"}) ==
             "lead_form"

    assert Business.Smoke.failure_check(%RuntimeError{
             message: "smoke_failed:private customer detail"
           }) == "unexpected_failure"

    assert Business.Smoke.failure_check(%ArgumentError{message: "secret"}) == "unexpected_failure"
  end

  test "exploration runtime ignores production database and notification settings" do
    values = %{
      "CUSTOMER_EXPLORATION" => "true",
      "EXPLORATION_HOST" => "work.example.ca",
      "EXPLORATION_PARENT_ORIGIN" => "https://console.example.ca",
      "EXPLORATION_PLATFORM_ORIGIN" => "https://example.ca",
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

    cfg =
      Config.Reader.read!(Path.expand("../../config/runtime.exs", __DIR__), env: :prod)[:business]

    assert cfg[Business.Repo][:socket_dir] == "/var/run/postgresql"
    assert cfg[Business.Repo][:url] == nil
    assert cfg[Business.Repo][:username] == "developer"
    assert cfg[Business.Mailer][:adapter] == Business.DisabledMailAdapter
    assert cfg[:exploration].platform_origin == "https://example.ca"
    assert cfg[:lead_notifications] == false
    assert cfg[BusinessWeb.Endpoint][:server] == false

    for origin <- [
          "http://unsafe.invalid",
          "https://example.ca https://evil.ca",
          "https://*.example.ca",
          "https://user@example.ca",
          "https://example.ca/path",
          "https://example.ca?x=1",
          "https://example.ca#frame"
        ] do
      System.put_env("EXPLORATION_PLATFORM_ORIGIN", origin)

      assert_raise RuntimeError, fn ->
        Config.Reader.read!(Path.expand("../../config/runtime.exs", __DIR__), env: :prod)
      end
    end

    System.delete_env("EXPLORATION_PLATFORM_ORIGIN")

    cfg =
      Config.Reader.read!(Path.expand("../../config/runtime.exs", __DIR__), env: :prod)[:business]

    assert cfg[:exploration].platform_origin == nil
    System.put_env("EXPLORATION_PARENT_ORIGIN", "http://unsafe.invalid")

    assert_raise RuntimeError, fn ->
      Config.Reader.read!(Path.expand("../../config/runtime.exs", __DIR__), env: :prod)
    end
  end

  test "smoke refuses production execution and remote targets" do
    assert_raise RuntimeError, "Smoke requires loopback", fn ->
      Business.Smoke.run!("https://example.ca")
    end

    Application.delete_env(:business, :exploration)

    assert_raise RuntimeError, "Smoke requires an isolated working copy", fn ->
      Business.Smoke.run!()
    end
  end
end
