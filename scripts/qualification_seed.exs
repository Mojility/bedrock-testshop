# Only the disposable caller-qualification snapshot invokes this script.
unless Application.get_env(:business, :exploration), do: raise("Requires isolated exploration")
Logger.configure(level: :warning)

lead =
  %Business.Leads.Lead{
    source: "synthetic-import",
    legacy_id: Ecto.UUID.generate(),
    inserted_at: ~U[2026-09-01 12:00:00.000000Z],
    seen_at: ~U[2026-09-02 13:00:00.000000Z],
    status: "contacted",
    notes: "Awaiting preferred service date"
  }
  |> Business.Leads.Lead.changeset(%{
    name: "Retained synthetic enquiry",
    phone: "555-0101",
    email: "retained@example.invalid",
    message: "Replace the kitchen light"
  })
  |> Business.Repo.insert!()

lead
|> Map.take(~w(id name phone email message source status notes legacy_id inserted_at seen_at)a)
|> Jason.encode!()
|> then(&File.write!(System.fetch_env!("SMOKE_EXPECTATION_PATH"), &1))

IO.puts("Synthetic enquiry persisted before listener startup")
