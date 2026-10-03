defmodule Business.Enquiries do
  @moduledoc "Staff-recorded job enquiries, their requested dates, and status history."
  import Ecto.Query

  alias Business.Accounts.Staff
  alias Business.Enquiries.{Enquiry, History}
  alias Business.Repo

  def change(%Enquiry{} = enquiry, attrs \\ %{}), do: Enquiry.create_changeset(enquiry, attrs)

  def list_week(scope, %Date{} = week_start) do
    Staff.authorize!(scope)
    week_end = Date.add(week_start, 7)

    Repo.all(
      from e in Enquiry,
        where: e.requested_date >= ^week_start and e.requested_date < ^week_end,
        order_by: [asc: e.requested_date, asc: e.inserted_at]
    )
  end

  def create(scope, attrs) do
    actor = Staff.authorize!(scope)
    changeset = Enquiry.create_changeset(%Enquiry{created_by_id: actor.id}, attrs)

    Repo.transaction(fn ->
      enquiry = insert_or_rollback(changeset)

      %History{}
      |> Ecto.Changeset.change(%{
        job_enquiry_id: enquiry.id,
        actor_id: actor.id,
        action: "recorded",
        to_status: enquiry.status
      })
      |> insert_or_rollback()

      enquiry
    end)
    |> tap_success(&broadcast/1)
  end

  def update_status(scope, id, attrs) do
    actor = Staff.authorize!(scope)

    with {:ok, uuid} <- Ecto.UUID.cast(id),
         %Enquiry{} = enquiry <- Repo.get(Enquiry, uuid) do
      Repo.transaction(fn ->
        updated = enquiry |> Enquiry.status_changeset(attrs) |> update_or_rollback()

        %History{}
        |> Ecto.Changeset.change(%{
          job_enquiry_id: updated.id,
          actor_id: actor.id,
          action: "status_changed",
          from_status: enquiry.status,
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
    Phoenix.PubSub.subscribe(Business.PubSub, "job_enquiries")
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

  defp tap_success({:ok, enquiry} = result, callback) do
    callback.(enquiry)
    result
  end

  defp tap_success(result, _callback), do: result

  defp broadcast(_),
    do: Phoenix.PubSub.broadcast(Business.PubSub, "job_enquiries", :enquiries_updated)
end
