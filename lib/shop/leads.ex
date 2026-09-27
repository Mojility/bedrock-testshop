defmodule Shop.Leads do
  @moduledoc "Enquiries and sales pipeline follow-up owned by this business database."
  import Ecto.Query
  alias Shop.Accounts.Staff
  alias Shop.Leads.{Activity, Lead}
  alias Shop.Repo

  def submit(attrs) do
    result = %Lead{} |> Lead.changeset(attrs) |> Repo.insert()
    if match?({:ok, _}, result), do: broadcast()
    result
  end

  def list(scope, trash? \\ false) do
    Staff.authorize!(scope)

    visibility =
      if trash? do
        dynamic([lead], not is_nil(lead.trashed_at))
      else
        dynamic([lead], is_nil(lead.trashed_at) and lead.status != "lost")
      end

    Repo.all(
      from lead in Lead,
        where: ^visibility,
        order_by: [desc: lead.inserted_at],
        limit: 200
    )
  end

  def get!(scope, id) do
    Staff.authorize!(scope)
    lead = Repo.get!(Lead, id) |> Repo.preload(activities: [:user])

    matching_contact =
      case {lead.email, lead.phone} do
        {email, phone} when is_binary(email) and is_binary(phone) ->
          dynamic([other], other.email == ^email or other.phone == ^phone)

        {email, _phone} when is_binary(email) ->
          dynamic([other], other.email == ^email)

        {_email, phone} when is_binary(phone) ->
          dynamic([other], other.phone == ^phone)
      end

    history =
      Repo.all(
        from other in Lead,
          where: other.id != ^lead.id,
          where: ^matching_contact,
          order_by: [desc: other.inserted_at]
      )

    {lead, history}
  end

  def stats(scope) do
    Staff.authorize!(scope)

    Repo.one(
      from l in Lead,
        where: l.source == "site" and is_nil(l.trashed_at),
        select: %{
          leads: count(l.id),
          awaiting_response: filter(count(l.id), l.status == "new"),
          conversations: filter(count(l.id), not is_nil(l.responded_at)),
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

    with {:ok, status} <- follow_up_status(attrs) do
      do_follow_up(user, id, attrs, status)
    end
  end

  defp follow_up_status(%{"status" => status})
       when status not in ["contacted", "closed", "conversation", "survey"],
       do: {:error, :invalid_status}

  defp follow_up_status(%{"survey_date" => date}) when date not in [nil, ""], do: {:ok, "survey"}
  defp follow_up_status(%{"status" => "survey"}), do: {:ok, "survey"}
  defp follow_up_status(%{"status" => "closed"}), do: {:ok, "closed"}
  defp follow_up_status(_attrs), do: {:ok, "conversation"}

  defp validate_follow_up_notes(changeset, status) when status in ["conversation", "survey"],
    do: Ecto.Changeset.validate_required(changeset, [:notes])

  defp validate_follow_up_notes(changeset, _status), do: changeset

  defp validate_survey_booking(changeset, "survey"),
    do: Ecto.Changeset.validate_required(changeset, [:survey_date, :survey_address])

  defp validate_survey_booking(changeset, _status), do: changeset

  defp do_follow_up(user, id, attrs, status) do
    Repo.transaction(fn ->
      lead =
        Repo.one!(from l in Lead, where: l.id == ^id and is_nil(l.trashed_at), lock: "FOR UPDATE")

      now = DateTime.utc_now()

      changeset =
        lead
        |> Ecto.Changeset.cast(attrs, [:notes, :survey_date, :survey_address])
        |> Ecto.Changeset.update_change(:survey_address, fn
          address when is_binary(address) -> String.trim(address)
          address -> address
        end)
        |> validate_follow_up_notes(status)
        |> validate_survey_booking(status)
        |> Ecto.Changeset.validate_length(:notes, max: 4000)
        |> Ecto.Changeset.validate_length(:survey_address, max: 500)
        |> Ecto.Changeset.put_change(:status, status)
        |> put_stage_times(status, now)

      with {:ok, updated} <- Repo.update(changeset),
           {:ok, _} <- record_activity(updated, lead.status, user, attrs["notes"]) do
        updated
      else
        {:error, reason} -> Repo.rollback(reason)
      end
    end)
    |> finish()
  end

  def dismiss(scope, id, notes) do
    user = Staff.authorize!(scope)
    change_status(id, user, "lost", notes || "Dismissed — not an opportunity")
  end

  def trash(scope, id) do
    Staff.authorize!(scope)

    Lead
    |> Repo.get!(id)
    |> Ecto.Changeset.change(trashed_at: DateTime.utc_now())
    |> Repo.update()
    |> finish()
  end

  def restore(scope, id) do
    Staff.authorize!(scope, ["owner", "office_manager"])

    Lead
    |> Repo.get!(id)
    |> Ecto.Changeset.change(trashed_at: nil)
    |> Repo.update()
    |> finish()
  end

  def empty_trash(scope) do
    Staff.authorize!(scope, ["owner", "office_manager"])
    {count, _} = Repo.delete_all(from l in Lead, where: not is_nil(l.trashed_at))
    broadcast()
    {:ok, count}
  end

  defp change_status(id, user, status, reason) do
    Repo.transaction(fn ->
      lead =
        Repo.one!(from l in Lead, where: l.id == ^id and is_nil(l.trashed_at), lock: "FOR UPDATE")

      {:ok, updated} =
        Repo.update(
          Ecto.Changeset.change(lead,
            status: status,
            notes: reason,
            responded_at: lead.responded_at || DateTime.utc_now()
          )
        )

      {:ok, _} = record_activity(updated, lead.status, user, reason)
      updated
    end)
    |> finish()
  end

  defp record_activity(lead, from_status, user, reason) do
    %Activity{}
    |> Ecto.Changeset.change(%{
      lead_id: lead.id,
      user_id: user.id,
      from_status: from_status,
      to_status: lead.status,
      reason: reason
    })
    |> Repo.insert()
  end

  defp put_stage_times(changeset, status, now) do
    changeset
    |> Ecto.Changeset.put_change(
      :responded_at,
      Ecto.Changeset.get_field(changeset, :responded_at) || now
    )
    |> maybe_timestamp(:surveyed_at, status == "survey", now)
    |> Ecto.Changeset.put_change(:seen_at, Ecto.Changeset.get_field(changeset, :seen_at) || now)
  end

  defp maybe_timestamp(changeset, field, true, now),
    do:
      Ecto.Changeset.put_change(
        changeset,
        field,
        Ecto.Changeset.get_field(changeset, field) || now
      )

  defp maybe_timestamp(changeset, _field, false, _now), do: changeset

  defp finish({:ok, value}) do
    broadcast()
    {:ok, value}
  end

  defp finish({:error, reason}), do: {:error, reason}

  def import_legacy(rows) when is_list(rows) do
    Repo.transact(fn ->
      Enum.each(rows, &import_row/1)
      {:ok, length(rows)}
    end)
  end

  defp import_row(row) do
    {:ok, id} = Ecto.UUID.cast(row["id"])
    {:ok, inserted, _} = DateTime.from_iso8601(row["inserted_at"])
    seen = if row["seen_at"], do: elem(DateTime.from_iso8601(row["seen_at"]), 1)

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
