defmodule Shop.Repo.Migrations.CreateInventory do
  use Ecto.Migration

  def change do
    create table(:inventory_items, primary_key: false) do
      add :id, :binary_id, primary_key: true
      add :sku, :string, null: false
      add :name, :string, null: false
      add :unit, :string, null: false
      timestamps(type: :utc_datetime_usec)
    end

    create unique_index(:inventory_items, ["lower(sku)"], name: :inventory_items_sku_index)

    create table(:inventory_movements, primary_key: false) do
      add :id, :binary_id, primary_key: true

      add :item_id, references(:inventory_items, type: :binary_id, on_delete: :restrict),
        null: false

      add :actor_id, references(:users, type: :binary_id, on_delete: :restrict), null: false
      add :quantity, :bigint, null: false
      add :reason, :string, null: false
      add :operation_id, :binary_id, null: false
      timestamps(type: :utc_datetime_usec, updated_at: false)
    end

    create index(:inventory_movements, [:item_id])
    create unique_index(:inventory_movements, [:operation_id])
    create constraint(:inventory_movements, :quantity_cannot_be_zero, check: "quantity <> 0")
  end
end
