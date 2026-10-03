defmodule Business.Enquiries do
  @moduledoc "Staff-recorded leads, their requested dates, and status history."
  import Ecto.Query

  alias Business.Accounts.Staff
  alias Business.Enquiries.History
  alias Business.Leads.Lead
  alias Business.Repo

  def change(%Lead{} = lead, attrs \\ %{}), do: Lead.enquiry_changeset(lead, attrs)

  def list_week(scope, %Date{} = week_start) do
    Staff.authorize!(scope)
    week_end = Date.add(week_start, 7)

    Repo.all(
      from lead in Lead,
        where: lead.requested_date >= ^week_start and lead.requested_date < ^week_end,
        order_by: [asc: lead.requested_date, asc: lead.inserted_at]
    )
  end

  def create(scope, attrs) do
    actor = Staff.authorize!(scope)
    changeset = Lead.enquiry_changeset(%Lead{created_by_id: actor.id}, attrs)

    Repo.transaction(fn ->
      lead = insert_or_rollback(changeset)

      %History{}
      |> Ecto.Changeset.change(%{
        lead_id: lead.id,
        actor_id: actor.id,
        action: "recorded",
        to_status: lead.status
      })
      |> insert_or_rollback()

      lead
    end)
    |> tap_success(&broadcast/1)
  end

  def update_status(scope, id, attrs) do
    actor = Staff.authorize!(scope)

    with {:ok, uuid} <- Ecto.UUID.cast(id),
         %Lead{} = lead <- Repo.get(Lead, uuid) do
      Repo.transaction(fn ->
        updated = lead |> Lead.status_changeset(attrs) |> update_or_rollback()

        %History{}
        |> Ecto.Changeset.change(%{
          lead_id: updated.id,
          actor_id: actor.id,
          action: "status_changed",
          from_status: lead.status,
          to_status: updated.status
        })
        |> insert_or_rollback()

        updated
      end)
      |> tap_success(&broadcast/1)
    else
      :error -> {:error, :invalid_id}
      nil -> {:error, :not_found}
    end
  rescue
    Ecto.StaleEntryError -> {:error, :stale}
  end

  def subscribe(scope) do
    Staff.authorize!(scope)
    Phoenix.PubSub.subscribe(Business.PubSub, "leads")
  end

  defp insert_or_rollback(changeset) do
    case Repo.insert(changeset) do
      {:ok, record} -> record
      {:error, changeset} -> Repo.rollback(changeset)
    end
  end

  defp update_or_rollback(changeset) do
    case Repo.update(changeset) do
      {:ok, record} -> record
      {:error, changeset} -> Repo.rollback(changeset)
    end
  end

  defp tap_success({:ok, lead} = result, callback) do
    callback.(lead)
    result
  end

  defp tap_success(result, _callback), do: result

  defp broadcast(_), do: Phoenix.PubSub.broadcast(Business.PubSub, "leads", :leads_updated)
end
