# Invoke with MIX_ENV=prod CUSTOMER_EXPLORATION=true mix run --no-start scripts/smoke.exs.
# The other process already serves HTTP; this one starts only the application dependencies.
endpoint = Application.fetch_env!(:shop, ShopWeb.Endpoint)
Application.put_env(:shop, ShopWeb.Endpoint, Keyword.put(endpoint, :server, false))
try do
  {:ok, _} = Application.ensure_all_started(:shop)
  result = Shop.Smoke.run!()
  IO.puts(Jason.encode!(Map.put(result, :status, "passed")))
rescue
  _ ->
    IO.puts(~s({"status":"failed","reason":"smoke_failed"}))
    System.halt(1)
end
