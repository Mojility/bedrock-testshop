defmodule Business.SmokeContractTest do
  use BusinessWeb.ConnCase, async: false
  alias Business.Leads.Lead
  import Ecto.Query

  setup do
    Business.SmokeFault.reset_loopback_rate_limit()

    files = %{
      "priv/published_site/scene.json" => File.read!("test/fixtures/website_scene.json"),
      "priv/published_site/media.json" => ~s({"photos":{}}),
      "priv/static/assets/published/site.css" => "body { color: #123; }",
      "priv/static/assets/css/app.css" => "body { color: #123; }"
    }

    files = Map.new(files, fn {path, bytes} -> {Application.app_dir(:business, path), bytes} end)
    originals = Map.new(files, fn {path, _} -> {path, File.read(path)} end)

    Enum.each(files, fn {path, bytes} ->
      File.mkdir_p!(Path.dirname(path))
      File.write!(path, bytes)
    end)

    original_exploration = Application.get_env(:business, :exploration)

    Application.put_env(:business, :exploration, %{
      parent_origin: "https://console.example.ca",
      media_origin: "https://public.example.ca"
    })

    lead =
      %Lead{
        source: "synthetic-import",
        legacy_id: Ecto.UUID.generate(),
        inserted_at: ~U[2026-09-01 12:00:00.000000Z],
        seen_at: ~U[2026-09-02 13:00:00.000000Z],
        status: "contacted",
        notes: "Awaiting preferred service date"
      }
      |> Lead.changeset(%{
        name: "Retained synthetic enquiry",
        phone: "555-0101",
        email: "retained@example.invalid",
        message: "Replace the kitchen light"
      })
      |> Business.Repo.insert!()

    expected =
      lead
      |> Map.take(
        ~w(id name phone email message source status notes legacy_id inserted_at seen_at)a
      )
      |> Jason.encode!()
      |> Jason.decode!()

    Application.put_env(:business, :smoke_existing_lead, expected)

    on_exit(fn ->
      Business.SmokeFault.reset_loopback_rate_limit()

      Enum.each(originals, fn {path, result} ->
        case result do
          {:ok, bytes} -> File.write!(path, bytes)
          _ -> File.rm(path)
        end
      end)

      Application.delete_env(:business, :smoke_existing_lead)

      if original_exploration,
        do: Application.put_env(:business, :exploration, original_exploration),
        else: Application.delete_env(:business, :exploration)
    end)

    %{lead: lead}
  end

  test "digested CSS query strings reach a real stylesheet and retained fields survive", %{
    lead: lead
  } do
    base = serve(:digested_css, lead.id)
    Business.Smoke.run!(base)
    assert Business.Repo.get!(Lead, lead.id) == lead
  end

  for {fault, check} <- [
        empty_css: "stylesheet_delivery",
        html_css: "stylesheet_delivery",
        staff_css: "stylesheet_delivery",
        private_access: "private_access",
        csrf: "csrf_denial",
        sign_in: "staff_sign_in",
        persistence: "lead_persistence",
        corrupt_submission: "lead_fields",
        corrupt_retained: "retained_lead_fields",
        missing_retained: "retained_lead_fields",
        staff_read: "staff_lead_read",
        retained_read: "staff_retained_read",
        lead_form: "lead_form"
      ] do
    test "qualification rejects #{fault} through HTTP and cleans its own records", %{lead: lead} do
      base = serve(unquote(fault), lead.id)

      error =
        assert_raise RuntimeError, "smoke_failed:#{unquote(check)}", fn ->
          Business.Smoke.run!(base)
        end

      assert Business.Smoke.failure_check(error) == unquote(check)

      if unquote(fault) in [:lead_form, :staff_read, :retained_read] do
        assert_receive {:capability_loss, unquote(fault), body}
        document = LazyHTML.from_document(body)

        case unquote(fault) do
          :lead_form ->
            assert document |> LazyHTML.query("#lead-form") |> Enum.any?()
            assert document |> LazyHTML.query("form[action='/leads']") |> Enum.empty?()
            assert document |> LazyHTML.query("input[name='lead[name]']") |> Enum.empty?()

          :staff_read ->
            assert document |> LazyHTML.query("#leads-list > li") |> Enum.empty?()

          :retained_read ->
            assert document |> LazyHTML.query("#leads-#{lead.id} > *") |> Enum.empty?()
            assert document |> LazyHTML.query("#leads-list [id^='lead-card-']") |> Enum.any?()
        end

        # Losing HTTP content must not masquerade as losing stored business data.
        assert Business.Repo.get!(Lead, lead.id) == lead
        Business.SmokeFault.reset_loopback_rate_limit()
        Business.Smoke.run!(serve(:none, lead.id))
        assert Business.Repo.get!(Lead, lead.id) == lead
      end

      refute Business.Repo.exists?(from(l in Lead, where: like(l.name, "Smoke %")))

      refute Business.Repo.exists?(
               from(u in Business.Accounts.User, where: like(u.email, "smoke-%@example.invalid"))
             )
    end
  end

  defp serve(fault, id) do
    server =
      start_supervised!(
        {Bandit,
         plug: {Business.SmokeFault, %{fault: fault, lead_id: id, observer: self()}},
         ip: {127, 0, 0, 1},
         port: 0}
      )

    {:ok, {_address, port}} = ThousandIsland.listener_info(server)
    "http://127.0.0.1:#{port}"
  end
end
