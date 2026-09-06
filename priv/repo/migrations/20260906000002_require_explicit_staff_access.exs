defmodule Shop.Repo.Migrations.RequireExplicitStaffAccess do
  use Ecto.Migration

  def up do
    drop constraint(:users, :valid_staff_role)

    create constraint(:users, :valid_staff_role,
             check: "role IN ('owner', 'staff', 'unassigned')"
           )

    alter table(:users), do: modify(:role, :string, null: false, default: "unassigned")
    execute "UPDATE users SET role = 'unassigned' WHERE role = 'staff'"
  end

  def down do
    raise "Review staff access explicitly before rolling back this migration"
  end
end
