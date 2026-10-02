# Invoke with MIX_ENV=prod CUSTOMER_EXPLORATION=true mix run --no-start scripts/smoke.exs.
# The other process already serves HTTP; this one starts only the application dependencies.
endpoint = Application.fetch_env!(:business, BusinessWeb.Endpoint)
Application.put_env(:business, BusinessWeb.Endpoint, Keyword.put(endpoint, :server, false))

try do
  {:ok, _} = Application.ensure_all_started(:business)

  if expected = System.get_env("SMOKE_EXISTING_LEAD") do
    Application.put_env(:business, :smoke_existing_lead, Jason.decode!(expected))
  end

  result = Business.Smoke.run!()
  IO.puts(Jason.encode!(Map.put(result, :status, "passed")))
rescue
  error ->
    IO.puts(
      Jason.encode!(%{
        status: "failed",
        reason: "smoke_failed",
        check: Business.Smoke.failure_check(error)
      })
    )

    System.halt(1)
end
