defmodule Business.Repo do
  use Ecto.Repo,
    otp_app: :business,
    adapter: Ecto.Adapters.Postgres
end
