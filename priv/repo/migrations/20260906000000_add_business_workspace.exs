defmodule Shop.Repo.Migrations.AddBusinessWorkspace do
  use Ecto.Migration

  def change do
    alter table(:users) do
      add :role, :string, null: false, default: "staff"
      add :disabled_at, :utc_datetime_usec
    end

    create constraint(:users, :valid_staff_role, check: "role IN ('owner', 'staff')")

    create table(:leads, primary_key: false) do
      add :id, :binary_id, primary_key: true
      add :name, :string, null: false
      add :phone, :string
      add :email, :string
      add :message, :text
      add :source, :string, null: false, default: "site"
      add :seen_at, :utc_datetime_usec
      add :status, :string, null: false, default: "new"
      add :notes, :text
      add :legacy_id, :binary_id
      timestamps(type: :utc_datetime_usec, updated_at: false)
    end

    create unique_index(:leads, [:legacy_id])
    create index(:leads, [:inserted_at])

    create constraint(:leads, :valid_lead_status,
             check: "status IN ('new', 'contacted', 'closed')"
           )
  end
end
