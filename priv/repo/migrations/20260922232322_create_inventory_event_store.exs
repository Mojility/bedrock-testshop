defmodule Shop.Repo.Migrations.CreateInventoryEventStore do
  use Ecto.Migration

  def change do
    create table(:inventory_parts, primary_key: false) do
      add :id, :binary_id, primary_key: true
      add :sku, :string, null: false
      add :name, :string, null: false
      add :unit, :string, null: false, default: "each"
      add :valuation_strategy, :string, null: false, default: "fifo"
      timestamps(type: :utc_datetime)
    end

    create unique_index(:inventory_parts, ["lower(sku)"], name: :inventory_parts_sku_index)

    create constraint(:inventory_parts, :inventory_parts_valuation_strategy_check,
             check: "valuation_strategy IN ('fifo', 'average', 'other')"
           )

    create table(:inventory_events, primary_key: false) do
      add :id, :binary_id, primary_key: true
      add :part_id, references(:inventory_parts, type: :binary_id, on_delete: :restrict), null: false
      add :actor_id, references(:users, type: :binary_id, on_delete: :restrict), null: false
      add :operation_id, :binary_id, null: false
      add :kind, :string, null: false
      add :quantity, :decimal, precision: 18, scale: 4, null: false
      add :unit_cost, :decimal, precision: 14, scale: 2
      add :reason, :string, null: false
      add :reverses_event_id, references(:inventory_events, type: :binary_id, on_delete: :restrict)
      timestamps(type: :utc_datetime, updated_at: false)
    end

    create index(:inventory_events, [:part_id, :inserted_at])
    create index(:inventory_events, [:actor_id])
    create unique_index(:inventory_events, [:operation_id])
    create unique_index(:inventory_events, [:reverses_event_id], where: "reverses_event_id IS NOT NULL")

    create constraint(:inventory_events, :inventory_events_kind_check,
             check: "kind IN ('receipt', 'removal', 'adjustment', 'reversal')"
           )

    create constraint(:inventory_events, :inventory_events_quantity_not_zero,
             check: "quantity <> 0"
           )

    create constraint(:inventory_events, :inventory_events_unit_cost_nonnegative,
             check: "unit_cost IS NULL OR unit_cost >= 0"
           )
  end
end
