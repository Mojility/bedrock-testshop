defmodule Shop.Inventory do
  @moduledoc "Parts and the durable movements that explain their quantities."
  import Ecto.Query
  alias Shop.Accounts.{Scope, Staff, User}
  alias Shop.Inventory.{Item, Movement}
  alias Shop.Repo

  def list_items(scope) do
    Staff.authorize!(scope)

    Repo.all(
      from i in Item,
        left_join: m in Movement,
        on: m.item_id == i.id,
        group_by: i.id,
        order_by: [asc: i.name],
        select: %{i | quantity_on_hand: coalesce(sum(m.quantity), 0)}
    )
  end

  def list_movements(scope) do
    Staff.authorize!(scope)

    Repo.all(
      from m in Movement,
        preload: [:actor, :item],
        order_by: [desc: m.inserted_at],
        limit: 100
    )
  end

  def create_item(scope, attrs) do
    Staff.authorize!(scope)
    %Item{} |> Item.changeset(attrs) |> Repo.insert()
  end

  def record_movement(%Scope{user: %User{id: actor_id}} = scope, item_id, attrs) do
    Staff.authorize!(scope)

    with {:ok, item_id} <- Ecto.UUID.cast(item_id),
         %Item{} <- Repo.get(Item, item_id) do
      attrs = put_operation_id(attrs)

      %Movement{item_id: item_id, actor_id: actor_id}
      |> Movement.changeset(attrs)
      |> Repo.insert()
    else
      _ -> {:error, :not_found}
    end
  end

  def reverse_movement(%Scope{user: %User{id: actor_id}} = scope, movement_id, reason) do
    Staff.authorize!(scope)

    Repo.transaction(fn ->
      case Repo.get(Movement, movement_id) do
        nil -> Repo.rollback(:not_found)
        original -> insert_reversal(original, actor_id, reason)
      end
    end)
  end

  defp insert_reversal(original, actor_id, reason) do
    %Movement{item_id: original.item_id, actor_id: actor_id}
    |> Movement.changeset(%{
      quantity: -original.quantity,
      reason: "Correction: #{reason}",
      operation_id: Ecto.UUID.generate()
    })
    |> Repo.insert()
    |> unwrap_reversal()
  end

  defp unwrap_reversal({:ok, reversal}), do: reversal
  defp unwrap_reversal({:error, changeset}), do: Repo.rollback(changeset)

  defp put_operation_id(attrs) do
    if Map.get(attrs, "operation_id") || Map.get(attrs, :operation_id) do
      attrs
    else
      Map.put(attrs, "operation_id", Ecto.UUID.generate())
    end
  end
end
