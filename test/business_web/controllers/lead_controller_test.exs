defmodule BusinessWeb.LeadControllerTest do
  use BusinessWeb.ConnCase, async: false

  alias Business.Leads.Lead
  alias Business.Leads.RateLimiter

  setup do
    dir = Application.app_dir(:business, "priv/published_site")
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
    assert [%{name: "Jo"}] = Business.Repo.all(Lead)
    assert get(recycle(conn), "/?sent=1").resp_body =~ "lead-sent"
  end

  test "unpublished page retains validation and stores valid enquiries", %{conn: conn} do
    File.rm!(Application.app_dir(:business, "priv/published_site/scene.json"))
    invalid = post(conn, "/leads", %{lead: %{name: "Jo", phone: "", email: "", message: ""}})
    document = invalid |> html_response(422) |> LazyHTML.from_document()

    assert document
           |> LazyHTML.query("#lead-form input[name='lead[name]'][value='Jo']")
           |> Enum.any?()

    assert document
           |> LazyHTML.query(
             "#lead_phone[aria-invalid='true'][aria-describedby='lead-contact-help lead_phone-errors'][autofocus]"
           )
           |> Enum.any?()

    assert document |> LazyHTML.query("#lead_phone-errors[role='alert']") |> Enum.any?()
    assert document |> LazyHTML.query("#lead-form input[name='_csrf_token']") |> Enum.any?()
    assert Business.Repo.aggregate(Lead, :count) == 0

    submitted = post(build_conn(), "/leads", %{lead: %{name: "Jo", phone: "555"}})
    assert redirected_to(submitted) == "/?sent=1#lead-sent"
    assert [%{name: "Jo"}] = Business.Repo.all(Lead)

    assert get(build_conn(), "/?sent=1")
           |> html_response(200)
           |> LazyHTML.from_document()
           |> LazyHTML.query("#lead-sent[role='status']")
           |> Enum.any?()
  end

  test "malformed published scene cannot fall back to holding-page submissions", %{conn: conn} do
    File.write!(Application.app_dir(:business, "priv/published_site/scene.json"), "invalid")
    assert post(conn, "/leads", %{lead: %{name: "Jo", phone: "555"}}).status == 503
    assert Business.Repo.aggregate(Lead, :count) == 0
  end

  test "incompatible published scene refuses submissions", %{conn: conn} do
    path = Application.app_dir(:business, "priv/published_site/scene.json")
    scene = path |> File.read!() |> Jason.decode!()
    File.write!(path, Jason.encode!(Map.put(scene, "component_model_hash", "incompatible")))
    assert post(conn, "/leads", %{lead: %{name: "Jo", phone: "555"}}).status == 503
    assert Business.Repo.aggregate(Lead, :count) == 0
  end

  test "unpublished page rate limits submissions and retains their context", %{conn: conn} do
    File.rm!(Application.app_dir(:business, "priv/published_site/scene.json"))
    conn = %{conn | remote_ip: {10, 20, 30, 41}}

    for _ <- 1..RateLimiter.limit() do
      assert post(conn, "/leads", %{lead: %{name: "Jo", phone: "555"}}).status == 302
    end

    document =
      conn
      |> post("/leads", %{lead: %{name: "Later enquiry", phone: "555"}})
      |> html_response(429)
      |> LazyHTML.from_document()

    assert document |> LazyHTML.query("#lead-form-refused[role='alert']") |> Enum.any?()

    assert document
           |> LazyHTML.query("#lead_name[value='Later enquiry']")
           |> Enum.any?()

    assert Business.Repo.aggregate(Lead, :count) == RateLimiter.limit()
  end

  test "unpublished submissions require CSRF", %{conn: conn} do
    File.rm!(Application.app_dir(:business, "priv/published_site/scene.json"))
    conn = Plug.Conn.put_private(conn, :plug_skip_csrf_protection, false)

    assert_raise Plug.CSRFProtection.InvalidCSRFTokenError, fn ->
      post(conn, "/leads", %{lead: %{name: "Jo", phone: "555"}})
    end

    assert Business.Repo.aggregate(Lead, :count) == 0
  end

  test "invalid input renders errors without creating a lead", %{conn: conn} do
    assert post(conn, "/leads", %{lead: %{name: "Jo"}}).status == 422
    assert Business.Repo.aggregate(Lead, :count) == 0
  end

  test "rate limiting refuses excess submissions without storing them", %{conn: conn} do
    conn = %{conn | remote_ip: {10, 20, 30, 40}}

    for _ <- 1..RateLimiter.limit() do
      assert post(conn, "/leads", %{lead: %{name: "Jo", phone: "555"}}).status == 302
    end

    assert post(conn, "/leads", %{lead: %{name: "Jo", phone: "555"}}).status == 429
    assert Business.Repo.aggregate(Lead, :count) == RateLimiter.limit()
  end

  test "CSRF is required on public submissions", %{conn: conn} do
    conn = Plug.Conn.put_private(conn, :plug_skip_csrf_protection, false)

    assert_raise Plug.CSRFProtection.InvalidCSRFTokenError, fn ->
      post(conn, "/leads", %{lead: %{name: "Jo", phone: "555"}})
    end

    assert Business.Repo.aggregate(Lead, :count) == 0
  end
end
