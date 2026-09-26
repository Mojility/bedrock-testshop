defmodule Shop.Inventory.Movement do
  @moduledoc "An attributable change to a part's quantity."
  use Ecto.Schema
  import Ecto.Changeset

  @primary_key {:id, :binary_id, autogenerate: true}
  @foreign_key_type :binary_id

  schema "inventory_movements" do
    field :quantity, :integer
    field :reason, :string
    field :operation_id, Ecto.UUID
    belongs_to :item, Shop.Inventory.Item
    belongs_to :actor, Shop.Accounts.User
    timestamps(type: :utc_datetime_usec, updated_at: false)
  end

  def changeset(movement, attrs) do
    movement
    |> cast(attrs, [:quantity, :reason, :operation_id])
    |> update_change(:reason, &String.trim/1)
    |> validate_required([:quantity, :reason, :operation_id])
    |> validate_number(:quantity, not_equal_to: 0)
    |> validate_length(:reason, max: 500)
    |> unique_constraint(:operation_id)
    |> check_constraint(:quantity, name: :quantity_cannot_be_zero)
  end
end
