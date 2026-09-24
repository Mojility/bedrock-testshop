defmodule Shop.Inventory.Event do
  @moduledoc "An append-only inventory movement."
  use Ecto.Schema
  import Ecto.Changeset

  @primary_key {:id, :binary_id, autogenerate: true}
  @foreign_key_type :binary_id

  schema "inventory_events" do
    field :operation_id, Ecto.UUID
    field :kind, :string
    field :quantity, :decimal
    field :unit_cost, :decimal
    field :reason, :string
    belongs_to :part, Shop.Inventory.Part
    belongs_to :actor, Shop.Accounts.User
    belongs_to :reverses_event, __MODULE__
    timestamps(type: :utc_datetime, updated_at: false)
  end

  def changeset(event, attrs) do
    event
    |> cast(attrs, [:operation_id, :kind, :quantity, :unit_cost, :reason, :reverses_event_id])
    |> validate_required([:operation_id, :kind, :quantity, :reason])
    |> validate_inclusion(:kind, ~w(receipt removal adjustment reversal))
    |> validate_number(:quantity, not_equal_to: 0)
    |> validate_number(:unit_cost, greater_than_or_equal_to: 0)
    |> validate_length(:reason, min: 2, max: 500)
    |> foreign_key_constraint(:part_id)
    |> foreign_key_constraint(:actor_id)
    |> foreign_key_constraint(:reverses_event_id)
    |> unique_constraint(:operation_id)
    |> unique_constraint(:reverses_event_id)
    |> check_constraint(:kind, name: :inventory_events_kind_check)
    |> check_constraint(:quantity, name: :inventory_events_quantity_not_zero)
    |> check_constraint(:unit_cost, name: :inventory_events_unit_cost_nonnegative)
  end
end
