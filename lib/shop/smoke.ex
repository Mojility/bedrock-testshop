defmodule Shop.Smoke do
  @moduledoc "Exercises a running isolated system: reads, assets, CSRF, lead writes and staff authentication."
  import Ecto.Query
  alias Shop.Accounts.UserToken

  @doc "Runs bounded checks against a loopback server and removes only its own synthetic records."
  def run!(base \\ "http://127.0.0.1:4000") do
    unless Application.get_env(:shop, :exploration),
      do: raise("Smoke requires an isolated working copy")

    unless URI.parse(base).host in ["127.0.0.1", "localhost"],
      do: raise("Smoke requires loopback")

    marker = "Smoke " <> Ecto.UUID.generate()

    {:ok, user} =
      Shop.Accounts.register_user(%{email: "smoke-#{Ecto.UUID.generate()}@example.invalid"})

    try do
      {ready, _} = request(base, "/health/ready", %{})
      check!(ready.status == 200, "readiness")
      {home, cookies} = request(base, "/", %{})
      check!(home.status == 200 and String.contains?(home.body, "lead-form"), "public_page")
      csrf = csrf!(home.body)
      styles = check_styles!(base, home.body, cookies)

      {private, _} = request(base, "/app/leads", cookies)

      check!(
        private.status == 302 and header(private, "location") == "/users/log-in",
        "private_access"
      )

      {blocked, _} =
        request(base, "/leads", %{}, form: %{"lead[name]" => marker, "lead[phone]" => "555-0100"})

      check!(blocked.status == 403, "csrf_denial")

      {submitted, cookies} =
        request(base, "/leads", cookies,
          form: %{"_csrf_token" => csrf, "lead[name]" => marker, "lead[phone]" => "555-0100"}
        )

      check!(submitted.status in [200, 302, 303], "lead_submission")

      check!(
        Shop.Repo.exists?(from l in Shop.Leads.Lead, where: l.name == ^marker),
        "lead_persistence"
      )

      {token, record} = UserToken.build_email_token(user, "login")
      Shop.Repo.insert!(record)

      {signed_in, cookies} =
        request(base, "/users/log-in", cookies,
          form: %{"_csrf_token" => csrf, "user[token]" => token}
        )

      check!(
        signed_in.status == 302 and header(signed_in, "location") == "/app/leads",
        "staff_sign_in"
      )

      {staff, _} = request(base, "/app/leads", cookies)
      check!(staff.status == 200 and String.contains?(staff.body, marker), "staff_lead_read")

      %{
        checks:
          ~w(readiness public_page stylesheets csrf_denial private_access lead_submission lead_persistence staff_sign_in staff_lead_read),
        stylesheets_checked: length(styles)
      }
    after
      Shop.Repo.delete_all(from l in Shop.Leads.Lead, where: l.name == ^marker)
      Shop.Repo.delete_all(from t in UserToken, where: t.user_id == ^user.id)
      Shop.Repo.delete!(user)
    end
  end

  defp check_styles!(base, body, cookies) do
    styles = Regex.scan(~r/<link[^>]+href="([^"]+)"[^>]*>/, body, capture: :all_but_first)
    styles = Enum.map(styles, &hd/1) |> Enum.filter(&String.ends_with?(&1, ".css"))
    check!(styles != [], "stylesheets_present")

    Enum.each(styles, fn path ->
      check!(
        String.starts_with?(path, "/") and not String.starts_with?(path, "//"),
        "local_assets"
      )

      {response, _} = request(base, path, cookies)
      check!(response.status == 200 and byte_size(response.body) > 0, "stylesheet_delivery")
    end)

    styles
  end

  defp request(base, path, cookies, options \\ []) do
    headers = [
      {"connection", "close"},
      {"cookie", Enum.map_join(cookies, "; ", fn {k, v} -> k <> "=" <> v end)}
    ]

    response =
      Req.request!(
        [
          url: base <> path,
          method: if(options[:form], do: :post, else: :get),
          headers: headers,
          redirect: false,
          retry: false,
          decode_body: false,
          receive_timeout: 10_000
        ] ++ options
      )

    cookies =
      Enum.reduce(Req.Response.get_header(response, "set-cookie"), cookies, fn value, acc ->
        [name, content] =
          value |> String.split(";", parts: 2) |> hd() |> String.split("=", parts: 2)

        Map.put(acc, name, content)
      end)

    {response, cookies}
  end

  defp csrf!(body) do
    case Regex.run(~r/name="_csrf_token"[^>]*value="([^"]+)"/, body) do
      [_, token] -> token
      _ -> raise "smoke_failed:csrf_form"
    end
  end

  defp header(response, key), do: response |> Req.Response.get_header(key) |> List.first()
  defp check!(true, _), do: :ok
  defp check!(false, name), do: raise("smoke_failed:" <> name)
end
