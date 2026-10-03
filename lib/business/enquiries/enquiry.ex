defmodule Business.Enquiries.Enquiry do
  @moduledoc "A staff-recorded customer request for work on a requested calendar date."
  use Ecto.Schema
  import Ecto.Changeset

  @primary_key {:id, :binary_id, autogenerate: true}
  @foreign_key_type :binary_id

  schema "job_enquiries" do
    field :customer_name, :string
    field :request, :string
    field :location, :string
    field :requested_date, :date
    field :source, :string
    field :status, :string, default: "waiting"
    field :lock_version, :integer, default: 1
    belongs_to :created_by, Business.Accounts.User
    timestamps(type: :utc_datetime_usec)
  end

  def create_changeset(enquiry, attrs) do
    enquiry
    |> cast(attrs, [:customer_name, :request, :location, :requested_date, :source, :status])
    |> trim([:customer_name, :request, :location])
    |> validate_required([:customer_name, :request, :location, :requested_date, :source, :status])
    |> validate_length(:customer_name, max: 120)
    |> validate_length(:request, max: 4_000)
    |> validate_length(:location, max: 200)
    |> validate_inclusion(:source, ~w(phone email))
    |> validate_inclusion(:status, ~w(waiting booked declined))
    |> check_constraint(:source, name: :valid_job_enquiry_source)
    |> check_constraint(:status, name: :valid_job_enquiry_status)
  end

  def status_changeset(enquiry, attrs) do
    enquiry
    |> cast(attrs, [:status, :lock_version])
    |> validate_required([:status, :lock_version])
    |> validate_inclusion(:status, ~w(waiting booked declined))
    |> check_constraint(:status, name: :valid_job_enquiry_status)
    |> optimistic_lock(:lock_version)
  end

  defp trim(changeset, fields) do
    Enum.reduce(fields, changeset, fn field, current ->
      update_change(current, field, &String.trim/1)
    end)
  end
end
