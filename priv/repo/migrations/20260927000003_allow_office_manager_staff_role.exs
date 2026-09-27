defmodule Shop.Repo.Migrations.AllowOfficeManagerStaffRole do
  use Ecto.Migration

  def up do
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
  end
end
