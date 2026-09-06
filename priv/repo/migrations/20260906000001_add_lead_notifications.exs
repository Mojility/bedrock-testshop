defmodule Shop.Repo.Migrations.AddLeadNotifications do
  use Ecto.Migration

  def change do
    alter table(:leads), do: add(:notified_at, :utc_datetime_usec)
  end
end
