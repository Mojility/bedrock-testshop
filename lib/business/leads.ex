defmodule Business.Leads do
  @moduledoc "Enquiries and follow-up owned by this business database."
  import Ecto.Query
  alias Business.Accounts.Staff
  alias Business.Leads.Lead
  alias Business.Repo

  def submit(attrs) do
    result = %Lead{} |> Lead.changeset(attrs) |> Repo.insert()
    if match?({:ok, _}, result), do: broadcast()
    result
  end

  def list(scope) do
    Staff.authorize!(scope)
    Repo.all(from l in Lead, order_by: [desc: l.inserted_at], limit: 200)
  end

  def subscribe(scope) do
    Staff.authorize!(scope)
    Phoenix.PubSub.subscribe(Business.PubSub, "leads")
  end

  def follow_up(scope, id, attrs) do
    Staff.authorize!(scope)

    case Ecto.UUID.cast(id) do
      {:ok, uuid} ->
        lead = Repo.get!(Lead, uuid)

        result =
          lead
          |> Lead.follow_up_changeset(attrs)
          |> Ecto.Changeset.put_change(:seen_at, lead.seen_at || DateTime.utc_now())
          |> Repo.update()

        if match?({:ok, _}, result), do: broadcast()
        result

      :error ->
        {:error, :invalid_id}
    end
  end

  # Trusted cutover input only. Replays preserve ids/times and never replace follow-up.
  def import_legacy(rows) when is_list(rows) do
    Repo.transact(fn ->
      Enum.each(rows, &import_row/1)

      {:ok, length(rows)}
    end)
  end

  defp import_row(row) do
    {:ok, id} = Ecto.UUID.cast(row["id"])
    {:ok, inserted, _} = DateTime.from_iso8601(row["inserted_at"])

    seen =
      case row["seen_at"] do
        nil ->
          nil

        value ->
          {:ok, at, _} = DateTime.from_iso8601(value)
          at
      end

    changeset =
      %Lead{
        legacy_id: id,
        source: row["source"] || "site",
        inserted_at: inserted,
        seen_at: seen,
        notified_at: DateTime.utc_now()
      }
      |> Lead.changeset(row)

    case Repo.insert(changeset, on_conflict: :nothing, conflict_target: :legacy_id) do
      {:ok, _} -> :ok
      {:error, reason} -> Repo.rollback(reason)
    end
  end

  defp broadcast, do: Phoenix.PubSub.broadcast(Business.PubSub, "leads", :leads_updated)
end
