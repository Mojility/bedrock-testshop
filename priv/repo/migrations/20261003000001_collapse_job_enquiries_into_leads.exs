defmodule Business.Repo.Migrations.CollapseJobEnquiriesIntoLeads do
  use Ecto.Migration

  def up do
    alter table(:leads) do
      add :location, :string
      add :requested_date, :date
      add :created_by_id, references(:users, type: :binary_id, on_delete: :restrict)
      add :lock_version, :integer, null: false, default: 1
    end

    drop constraint(:leads, :valid_lead_status)

    create constraint(:leads, :valid_lead_status,
             check: "status IN ('new', 'contacted', 'closed', 'waiting', 'booked', 'declined')"
           )

    execute("""
    INSERT INTO leads
      (id, name, message, source, status, location, requested_date, created_by_id,
       lock_version, inserted_at)
    SELECT id, customer_name, request, source, status, location, requested_date, created_by_id,
           lock_version, inserted_at
    FROM job_enquiries
    ON CONFLICT (id) DO NOTHING
    """)

    create index(:leads, [:requested_date])

    create table(:lead_history, primary_key: false) do
      add :id, :binary_id, primary_key: true
      add :lead_id, references(:leads, type: :binary_id, on_delete: :delete_all), null: false
      add :actor_id, references(:users, type: :binary_id, on_delete: :restrict), null: false
      add :action, :string, null: false
      add :from_status, :string
      add :to_status, :string, null: false
      timestamps(type: :utc_datetime_usec, updated_at: false)
    end

    execute("""
    INSERT INTO lead_history
      (id, lead_id, actor_id, action, from_status, to_status, inserted_at)
    SELECT id, job_enquiry_id, actor_id, action, from_status, to_status, inserted_at
    FROM job_enquiry_history
    """)

    create index(:lead_history, [:lead_id, :inserted_at])
    drop table(:job_enquiry_history)
    drop table(:job_enquiries)
  end

  def down do
    raise "collapsing enquiries into leads preserves data and cannot be reversed safely"
  end
end
