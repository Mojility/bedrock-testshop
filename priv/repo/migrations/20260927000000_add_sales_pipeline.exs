defmodule Shop.Repo.Migrations.AddSalesPipeline do
  use Ecto.Migration

  def up do
    drop constraint(:leads, :valid_lead_status)

    alter table(:leads) do
      add :responded_at, :utc_datetime_usec
      add :surveyed_at, :utc_datetime_usec
      add :quoted_at, :utc_datetime_usec
      add :job_closed_at, :utc_datetime_usec
    end

    execute(
      "UPDATE leads SET status = 'conversation', responded_at = COALESCE(seen_at, inserted_at) WHERE status = 'contacted'"
    )

    execute(
      "UPDATE leads SET status = 'lost', responded_at = COALESCE(seen_at, inserted_at) WHERE status = 'closed'"
    )

    create constraint(:leads, :valid_lead_status,
             check:
               "status IN ('new', 'contacted', 'closed', 'conversation', 'survey', 'quote', 'job_closed', 'lost')"
           )

    create table(:lead_activities, primary_key: false) do
      add :id, :binary_id, primary_key: true
      add :lead_id, references(:leads, type: :binary_id, on_delete: :delete_all), null: false
      add :user_id, references(:users, type: :binary_id, on_delete: :restrict), null: false
      add :from_status, :string, null: false
      add :to_status, :string, null: false
      add :reason, :text
      timestamps(type: :utc_datetime_usec, updated_at: false)
    end

    create index(:lead_activities, [:lead_id, :inserted_at])
  end

  def down do
    drop table(:lead_activities)
    drop constraint(:leads, :valid_lead_status)

    execute(
      "UPDATE leads SET status = 'contacted' WHERE status IN ('conversation', 'survey', 'quote', 'job_closed')"
    )

    execute("UPDATE leads SET status = 'closed' WHERE status = 'lost'")

    alter table(:leads) do
      remove :responded_at
      remove :surveyed_at
      remove :quoted_at
      remove :job_closed_at
    end

    create constraint(:leads, :valid_lead_status,
             check: "status IN ('new', 'contacted', 'closed')"
           )
  end
end
