defmodule Shop.Inventory.Item do
  @moduledoc "A part tracked by SKU and an explicit unit."
  use Ecto.Schema
  import Ecto.Changeset

  @primary_key {:id, :binary_id, autogenerate: true}
  @foreign_key_type :binary_id

  schema "inventory_items" do
    field :sku, :string
    field :name, :string
    field :unit, :string
    field :quantity_on_hand, :integer, virtual: true, default: 0
    timestamps(type: :utc_datetime_usec)
  end

  def changeset(item, attrs) do
    item
    |> cast(attrs, [:sku, :name, :unit])
    |> update_change(:sku, &(&1 |> String.trim() |> String.upcase()))
    |> update_change(:name, &String.trim/1)
    |> update_change(:unit, &String.trim/1)
    |> validate_required([:sku, :name, :unit])
    |> validate_length(:sku, max: 80)
    |> validate_length(:name, max: 160)
    |> validate_length(:unit, max: 40)
    |> unique_constraint(:sku, name: :inventory_items_sku_index)
  end
end
