defmodule Shop.Repo.Migrations.AddLeadPipelineOperations do
  use Ecto.Migration

  def up do
    alter table(:leads) do
      add :survey_date, :date
      add :trashed_at, :utc_datetime_usec
    end

    create index(:leads, [:trashed_at])

    drop constraint(:users, :valid_staff_role)

    create constraint(:users, :valid_staff_role,
             check: "role IN ('owner', 'office_manager', 'staff', 'unassigned')"
           )
  end

  def down do
    drop constraint(:users, :valid_staff_role)

    create constraint(:users, :valid_staff_role,
             check: "role IN ('owner', 'staff', 'unassigned')"
           )

    alter table(:leads) do
      remove :survey_date
      remove :trashed_at
    end
  end
end
