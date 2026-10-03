defmodule Business.Repo.Migrations.CreateJobEnquiries do
  use Ecto.Migration

  def change do
    create table(:job_enquiries, primary_key: false) do
      add :id, :binary_id, primary_key: true
      add :customer_name, :string, null: false
      add :request, :text, null: false
      add :location, :string, null: false
      add :requested_date, :date, null: false
      add :source, :string, null: false
      add :status, :string, null: false, default: "waiting"
      add :created_by_id, references(:users, type: :binary_id, on_delete: :restrict), null: false
      add :lock_version, :integer, null: false, default: 1
      timestamps(type: :utc_datetime_usec)
    end

    create constraint(:job_enquiries, :valid_job_enquiry_source,
             check: "source IN ('phone', 'email')"
           )

    create constraint(:job_enquiries, :valid_job_enquiry_status,
             check: "status IN ('waiting', 'booked', 'declined')"
           )

    create index(:job_enquiries, [:requested_date])

    create table(:job_enquiry_history, primary_key: false) do
      add :id, :binary_id, primary_key: true

      add :job_enquiry_id,
          references(:job_enquiries, type: :binary_id, on_delete: :delete_all), null: false

      add :actor_id, references(:users, type: :binary_id, on_delete: :restrict), null: false
      add :action, :string, null: false
      add :from_status, :string
      add :to_status, :string, null: false
      timestamps(type: :utc_datetime_usec, updated_at: false)
    end

    create index(:job_enquiry_history, [:job_enquiry_id, :inserted_at])
  end
end
