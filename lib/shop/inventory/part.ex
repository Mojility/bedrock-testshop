defmodule Shop.Inventory.Part do
  @moduledoc "A stocked part whose quantity is derived from its immutable events."
  use Ecto.Schema
  import Ecto.Changeset

  @primary_key {:id, :binary_id, autogenerate: true}
  @foreign_key_type :binary_id

  schema "inventory_parts" do
    field :sku, :string
    field :name, :string
    field :unit, :string, default: "each"
    field :valuation_strategy, :string, default: "fifo"
    field :quantity_on_hand, :decimal, virtual: true, default: Decimal.new(0)
    has_many :events, Shop.Inventory.Event
    timestamps(type: :utc_datetime)
  end

  def changeset(part, attrs) do
    part
    |> cast(attrs, [:sku, :name, :unit, :valuation_strategy])
    |> update_change(:sku, &(&1 |> String.trim() |> String.upcase()))
    |> update_change(:name, &String.trim/1)
    |> update_change(:unit, &String.trim/1)
    |> validate_required([:sku, :name, :unit, :valuation_strategy])
    |> validate_length(:sku, max: 80)
    |> validate_length(:name, max: 200)
    |> validate_length(:unit, max: 40)
    |> validate_inclusion(:valuation_strategy, ~w(fifo average other))
    |> unique_constraint(:sku, name: :inventory_parts_sku_index)
  end
end
