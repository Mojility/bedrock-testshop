defmodule ShopWeb.LeadControllerTest do
  use ShopWeb.ConnCase, async: false

  alias Shop.Leads.Lead
  alias Shop.Leads.RateLimiter

  setup do
    dir = Application.app_dir(:shop, "priv/published_site")
    File.mkdir_p!(dir)
    paths = [Path.join(dir, "scene.json"), Path.join(dir, "media.json")]
    originals = Enum.map(paths, &{&1, File.read(&1)})

    on_exit(fn ->
      Enum.each(originals, fn
        {path, {:ok, bytes}} -> File.write!(path, bytes)
        {path, _} -> File.rm(path)
      end)
    end)

    File.cp!("test/fixtures/website_scene.json", hd(paths))
    File.write!(List.last(paths), Jason.encode!(%{"photos" => %{}}))
    :ok
  end

  test "visitor enquiry stays in customer database and returns to thank you", %{conn: conn} do
    conn = post(conn, "/leads", %{lead: %{name: "Jo", phone: "555"}})
    assert redirected_to(conn) == "/?sent=1#lead-sent"
    assert [%{name: "Jo"}] = Shop.Repo.all(Lead)
    assert get(recycle(conn), "/?sent=1").resp_body =~ "lead-sent"
  end

  test "invalid input renders errors without creating a lead", %{conn: conn} do
    assert post(conn, "/leads", %{lead: %{name: "Jo"}}).status == 422
    assert Shop.Repo.aggregate(Lead, :count) == 0
  end

  test "rate limiting refuses excess submissions without storing them", %{conn: conn} do
    conn = %{conn | remote_ip: {10, 20, 30, 40}}

    for _ <- 1..RateLimiter.limit() do
      assert post(conn, "/leads", %{lead: %{name: "Jo", phone: "555"}}).status == 302
    end

    assert post(conn, "/leads", %{lead: %{name: "Jo", phone: "555"}}).status == 429
    assert Shop.Repo.aggregate(Lead, :count) == RateLimiter.limit()
  end

  test "CSRF is required on public submissions", %{conn: conn} do
    conn = Plug.Conn.put_private(conn, :plug_skip_csrf_protection, false)

    assert_raise Plug.CSRFProtection.InvalidCSRFTokenError, fn ->
      post(conn, "/leads", %{lead: %{name: "Jo", phone: "555"}})
    end

    assert Shop.Repo.aggregate(Lead, :count) == 0
  end
end
