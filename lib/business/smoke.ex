defmodule Business.Smoke do
  @moduledoc "Exercises a running isolated system: reads, assets, CSRF, lead writes and staff authentication."
  import Ecto.Query
  alias Business.Accounts.UserToken
  alias Business.Leads.Lead

  @retained_fields ~w(id name phone email message source status notes legacy_id inserted_at seen_at)a

  @doc "Runs bounded checks against a loopback server and removes only its own synthetic records."
  def run!(base \\ "http://127.0.0.1:4000") do
    unless Application.get_env(:business, :exploration),
      do: raise("Smoke requires an isolated working copy")

    unless URI.parse(base).host in ["127.0.0.1", "localhost"],
      do: raise("Smoke requires loopback")

    marker = "Smoke " <> Ecto.UUID.generate()

    {:ok, user} =
      Business.Accounts.register_user(%{email: "smoke-#{Ecto.UUID.generate()}@example.invalid"})

    try do
      existing = existing_lead!(marker)
      check_retained!(existing)
      {ready, _} = request(base, "/health/ready", %{})
      check!(ready.status == 200, "readiness")
      {home, cookies} = request(base, "/", %{})
      check!(home.status == 200, "public_page")
      check!(enquiry_form?(home.body), "lead_form")
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
      check!(not Business.Repo.exists?(from l in Lead, where: l.name == ^marker), "csrf_denial")

      attrs = %{
        name: marker,
        phone: "555-0100",
        email: "smoke@example.invalid",
        message: "Request a synthetic lighting repair"
      }

      form =
        attrs
        |> Map.new(fn {key, value} -> {"lead[#{key}]", value} end)
        |> Map.put("_csrf_token", csrf)

      {submitted, cookies} =
        request(base, "/leads", cookies, form: form)

      check!(submitted.status in [200, 302, 303], "lead_submission")

      lead = Business.Repo.get_by(Lead, name: marker)
      check!(lead != nil, "lead_persistence")
      check!(Map.take(lead, Map.keys(attrs)) == attrs, "lead_fields")

      {token, record} = UserToken.build_email_token(user, "login")
      Business.Repo.insert!(record)

      {signed_in, cookies} =
        request(base, "/users/log-in", cookies,
          form: %{"_csrf_token" => csrf, "user[token]" => token}
        )

      check!(
        signed_in.status == 302 and header(signed_in, "location") == "/app/leads",
        "staff_sign_in"
      )

      {staff, _} = request(base, "/app/leads", cookies)
      check_retained!(existing)

      check!(
        staff.status == 200 and rendered_fields?(staff.body, Map.values(attrs)),
        "staff_lead_read"
      )

      check!(
        rendered_fields?(
          staff.body,
          Map.take(existing, ~w(name phone email message notes inserted_at)) |> Map.values()
        ),
        "staff_retained_read"
      )

      staff_styles = check_styles!(base, staff.body, cookies)

      %{
        checks:
          ~w(readiness public_page lead_form stylesheets csrf_denial private_access lead_submission lead_persistence lead_fields staff_sign_in staff_lead_read retained_lead_fields staff_retained_read),
        stylesheets_checked: length(styles) + length(staff_styles)
      }
    after
      names = [marker, "Retained " <> marker]
      Business.Repo.delete_all(from l in Lead, where: l.name in ^names)
      Business.Repo.delete_all(from t in UserToken, where: t.user_id == ^user.id)
      Business.Repo.delete!(user)
    end
  end

  @failure_checks ~w(readiness public_page lead_form csrf_form stylesheets_present local_assets
                     stylesheet_delivery private_access csrf_denial lead_submission
                     lead_persistence lead_fields staff_sign_in staff_lead_read
                     retained_lead_fields staff_retained_read)

  @doc "Returns a bounded check name; exception messages and customer data are never exposed."
  def failure_check(%RuntimeError{message: "smoke_failed:" <> check})
      when check in @failure_checks, do: check

  def failure_check(_), do: "unexpected_failure"

  defp existing_lead!(marker) do
    case Application.get_env(:business, :smoke_existing_lead) do
      nil ->
        %Lead{
          source: "synthetic-import",
          inserted_at: ~U[2026-09-01 12:00:00.000000Z],
          seen_at: ~U[2026-09-02 13:00:00.000000Z],
          status: "contacted",
          notes: "Awaiting preferred service date"
        }
        |> Lead.changeset(%{
          name: "Retained " <> marker,
          phone: "555-0101",
          email: "retained@example.invalid",
          message: "Replace the kitchen light"
        })
        |> Business.Repo.insert!()
        |> retained_fields()

      expected when is_map(expected) ->
        expected
    end
  end

  defp check_retained!(expected) do
    lead = Business.Repo.get(Lead, expected["id"])
    check!(lead != nil and retained_fields(lead) == expected, "retained_lead_fields")
  end

  defp retained_fields(lead) do
    lead |> Map.take(@retained_fields) |> Jason.encode!() |> Jason.decode!()
  end

  defp enquiry_form?(body) do
    body
    |> then(&Regex.scan(~r/<form\b([^>]*)>(.*?)<\/form>/s, &1, capture: :all_but_first))
    |> Enum.any?(fn [attributes, contents] ->
      Regex.match?(~r/(?:^|\s)action="\/leads"/, attributes) and
        Regex.match?(~r/(?:^|\s)method="post"/, attributes) and
        enquiry_controls?(contents)
    end)
  end

  defp enquiry_controls?(contents) do
    Enum.all?(~w(name phone email message), fn field ->
      Regex.match?(~r/<(?:input|textarea)\b[^>]*\sname="lead\[#{field}\]"/, contents)
    end) and
      Regex.match?(~r/<button\b(?![^>]*\stype="(?:button|reset)")[^>]*>/, contents) and
      not Regex.match?(
        ~r/<(?:fieldset|input|textarea|button)\b[^>]*\bdisabled(?:[\s=>])/,
        contents
      )
  end

  defp rendered_fields?(body, fields) do
    Enum.all?(fields, fn field ->
      String.contains?(body, field |> Phoenix.HTML.html_escape() |> Phoenix.HTML.safe_to_string())
    end)
  end

  defp check_styles!(base, body, cookies) do
    styles = Regex.scan(~r/<link[^>]+href="([^"]+)"[^>]*>/, body, capture: :all_but_first)

    styles =
      styles
      |> Enum.map(&hd/1)
      |> Enum.filter(fn href -> String.ends_with?(URI.parse(href).path || "", ".css") end)

    check!(styles != [], "stylesheets_present")

    Enum.each(styles, fn path ->
      check!(
        String.starts_with?(path, "/") and not String.starts_with?(path, "//"),
        "local_assets"
      )

      {response, _} = request(base, path, cookies)

      check!(
        response.status == 200 and String.trim(response.body) != "" and
          String.starts_with?(header(response, "content-type") || "", "text/css"),
        "stylesheet_delivery"
      )
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
