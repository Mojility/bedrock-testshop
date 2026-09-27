defmodule Shop.Leads do
  @moduledoc "Enquiries and sales pipeline follow-up owned by this business database."
  import Ecto.Query
  alias Shop.Accounts.Staff
  alias Shop.Leads.{Activity, Lead}
  alias Shop.Repo

  # Keep the original terminal values valid for trusted legacy workflows while the
  # staff UI uses the more descriptive pipeline stages.
  @statuses ~w(new contacted closed conversation survey quote job_closed lost)

  def submit(attrs) do
    result = %Lead{} |> Lead.changeset(attrs) |> Repo.insert()
    if match?({:ok, _}, result), do: broadcast()
    result
  end

  def list(scope) do
    Staff.authorize!(scope)
    Repo.all(from l in Lead, order_by: [desc: l.inserted_at], limit: 200)
  end

  def stats(scope) do
    Staff.authorize!(scope)

    Repo.one(
      from l in Lead,
        where: l.source == "site",
        select: %{
          leads: count(l.id),
          awaiting_response: filter(count(l.id), l.status == "new"),
          surveys: filter(count(l.id), not is_nil(l.surveyed_at)),
          quotes: filter(count(l.id), not is_nil(l.quoted_at)),
          closed_jobs: filter(count(l.id), not is_nil(l.job_closed_at))
        }
    )
  end

  def subscribe(scope) do
    Staff.authorize!(scope)
    Phoenix.PubSub.subscribe(Shop.PubSub, "leads")
  end

  def follow_up(scope, id, attrs) do
    user = Staff.authorize!(scope)

    with {:ok, uuid} <- Ecto.UUID.cast(id),
         status when status in @statuses <- attrs["status"] do
      uuid
      |> transact_follow_up(user, attrs, status, DateTime.utc_now())
      |> finish_follow_up()
    else
      _ -> {:error, :invalid_input}
    end
  end

  defp transact_follow_up(uuid, user, attrs, status, now) do
    Repo.transaction(fn ->
      with {:ok, {updated, from_status}} <- update_lead(Repo, uuid, attrs, status, now),
           {:ok, _activity} <-
             record_activity(Repo, %{change: {updated, from_status}}, uuid, user, attrs) do
        updated
      else
        {:error, reason} -> Repo.rollback(reason)
      end
    end)
  end

  defp update_lead(repo, uuid, attrs, status, now) do
    lead = repo.one!(from l in Lead, where: l.id == ^uuid, lock: "FOR UPDATE")

    case lead
         |> Ecto.Changeset.cast(attrs, [:status, :notes])
         |> Ecto.Changeset.validate_required([:status])
         |> Ecto.Changeset.validate_inclusion(:status, @statuses)
         |> Ecto.Changeset.validate_length(:notes, max: 4000)
         |> put_stage_times(status, now)
         |> repo.update() do
      {:ok, updated} -> {:ok, {updated, lead.status}}
      {:error, changeset} -> {:error, changeset}
    end
  end

  defp record_activity(repo, %{change: {updated, from_status}}, uuid, user, attrs) do
    %Activity{}
    |> Ecto.Changeset.change(%{
      lead_id: uuid,
      user_id: user.id,
      from_status: from_status,
      to_status: updated.status,
      reason: attrs["notes"]
    })
    |> repo.insert()
  end

  defp finish_follow_up({:ok, lead}) do
    broadcast()
    {:ok, lead}
  end

  defp finish_follow_up({:error, reason}), do: {:error, reason}

  # Trusted cutover input only. Replays preserve ids/times and never replace follow-up.
  def import_legacy(rows) when is_list(rows) do
    Repo.transact(fn ->
      Enum.each(rows, &import_row/1)
      {:ok, length(rows)}
    end)
  end

  defp put_stage_times(changeset, status, now) do
    changeset
    |> maybe_timestamp(:responded_at, status != "new", now)
    |> maybe_timestamp(:surveyed_at, status == "survey", now)
    |> maybe_timestamp(:quoted_at, status == "quote", now)
    |> maybe_timestamp(:job_closed_at, status == "job_closed", now)
    |> Ecto.Changeset.put_change(:seen_at, Ecto.Changeset.get_field(changeset, :seen_at) || now)
  end

  defp maybe_timestamp(changeset, field, true, now) do
    if Ecto.Changeset.get_field(changeset, field) do
      changeset
    else
      Ecto.Changeset.put_change(changeset, field, now)
    end
  end

  defp maybe_timestamp(changeset, _field, false, _now), do: changeset

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

  defp broadcast, do: Phoenix.PubSub.broadcast(Shop.PubSub, "leads", :leads_updated)
end
