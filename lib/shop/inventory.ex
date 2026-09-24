defmodule Shop.Inventory do
  @moduledoc "Event-sourced stock management for staff."
  import Ecto.Query

  alias Ecto.Multi
  alias Shop.Accounts.{Scope, Staff, User}
  alias Shop.Inventory.{Event, Part}
  alias Shop.Repo

  def list_parts(%Scope{} = scope, search \\ "") do
    Staff.authorize!(scope)
    term = "%#{String.trim(search)}%"

    Repo.all(
      from p in Part,
        left_join: e in assoc(p, :events),
        where: ilike(p.sku, ^term) or ilike(p.name, ^term),
        group_by: p.id,
        order_by: [asc: p.sku],
        select_merge: %{quantity_on_hand: coalesce(sum(e.quantity), 0)}
    )
  end

  def get_part!(%Scope{} = scope, id) do
    Staff.authorize!(scope)

    Part
    |> Repo.get!(id)
    |> Repo.preload(events: from(e in Event, order_by: [desc: e.inserted_at], preload: [:actor]))
    |> with_balance()
  end

  def change_part(%Scope{} = scope, attrs \\ %{}) do
    Staff.authorize!(scope)
    Part.changeset(%Part{}, attrs)
  end

  def create_part(%Scope{} = scope, attrs) do
    Staff.authorize!(scope)
    %Part{} |> Part.changeset(attrs) |> Repo.insert()
  end

  def change_event(%Scope{} = scope, attrs \\ %{}) do
    %User{} = user = Staff.authorize!(scope)
    Event.changeset(%Event{actor_id: user.id, operation_id: Ecto.UUID.generate()}, attrs)
  end

  def record_event(%Scope{} = scope, part_id, attrs) do
    %User{} = user = Staff.authorize!(scope)

    Repo.transact(fn ->
      part = Repo.one!(from p in Part, where: p.id == ^part_id, lock: "FOR UPDATE")
      attrs = normalize_event(attrs)

      %Event{part_id: part.id, actor_id: user.id}
      |> Event.changeset(Map.put_new(attrs, "operation_id", Ecto.UUID.generate()))
      |> Repo.insert()
    end)
  end

  def reverse_event(%Scope{} = scope, event_id, reason, operation_id \\ Ecto.UUID.generate()) do
    %User{} = user = Staff.authorize!(scope)

    Multi.new()
    |> Multi.run(:original, fn repo, _ ->
      case repo.one(from e in Event, where: e.id == ^event_id, lock: "FOR UPDATE") do
        nil -> {:error, :not_found}
        event -> {:ok, event}
      end
    end)
    |> Multi.insert(:reversal, fn %{original: event} ->
      Event.changeset(
        %Event{part_id: event.part_id, actor_id: user.id},
        %{
          operation_id: operation_id,
          kind: "reversal",
          quantity: Decimal.negate(event.quantity),
          reason: reason,
          reverses_event_id: event.id
        }
      )
    end)
    |> Repo.transaction()
    |> case do
      {:ok, %{reversal: reversal}} -> {:ok, reversal}
      {:error, _step, reason, _changes} -> {:error, reason}
    end
  end

  defp normalize_event(%{"kind" => "receipt"} = attrs), do: positive(attrs)
  defp normalize_event(%{"kind" => "removal"} = attrs), do: negative(attrs)
  defp normalize_event(attrs), do: attrs

  defp positive(%{"quantity" => quantity} = attrs), do: %{attrs | "quantity" => absolute(quantity)}
  defp positive(attrs), do: attrs
  defp negative(%{"quantity" => quantity} = attrs), do: %{attrs | "quantity" => "-" <> absolute(quantity)}
  defp negative(attrs), do: attrs

  defp absolute(value) when is_binary(value), do: String.trim_leading(String.trim(value), "-")
  defp absolute(value), do: value |> Decimal.new() |> Decimal.abs() |> Decimal.to_string()

  defp with_balance(part) do
    %{part | quantity_on_hand: Enum.reduce(part.events, Decimal.new(0), &Decimal.add(&1.quantity, &2))}
  end
end
