defmodule Business.Leads.Lead do
  @moduledoc """
  A customer enquiry, whether received through the website, by phone, or by email.
  Staff-recorded enquiries include the requested work, location and requested date.
  """
  use Ecto.Schema

  import Ecto.Changeset

  @primary_key {:id, :binary_id, autogenerate: true}
  @foreign_key_type :binary_id

  @type t :: %__MODULE__{}

  schema "leads" do
    field :name, :string
    field :phone, :string
    field :email, :string
    field :message, :string
    field :location, :string
    field :requested_date, :date
    field :source, :string, default: "site"
    field :notified_at, :utc_datetime_usec
    field :seen_at, :utc_datetime_usec
    field :status, :string, default: "new"
    field :notes, :string
    field :legacy_id, :binary_id
    field :lock_version, :integer, default: 1
    belongs_to :created_by, Business.Accounts.User

    timestamps(type: :utc_datetime_usec, updated_at: false)
  end

  def changeset(lead, attrs) do
    lead
    |> cast(attrs, [:name, :phone, :email, :message])
    |> trim([:name, :phone, :email, :message])
    |> validate_required([:name], message: "tell us your name")
    |> validate_length(:name, max: 120)
    |> validate_length(:phone, max: 40)
    |> validate_length(:email, max: 160)
    |> validate_length(:message, max: 4_000)
    |> validate_format(:email, ~r/^[^\s@]+@[^\s@]+\.[^\s@]+$/,
      message: "does not look like an email"
    )
    |> validate_a_way_to_reach_them()
  end

  def enquiry_changeset(lead, attrs) do
    lead
    |> cast(attrs, [:name, :message, :location, :requested_date, :source, :status])
    |> trim([:name, :message, :location])
    |> validate_required([:name, :message, :location, :requested_date, :source, :status])
    |> validate_length(:name, max: 120)
    |> validate_length(:message, max: 4_000)
    |> validate_length(:location, max: 200)
    |> validate_inclusion(:source, ~w(phone email))
    |> validate_inclusion(:status, ~w(waiting booked declined))
    |> check_constraint(:status, name: :valid_lead_status)
  end

  def status_changeset(lead, attrs) do
    lead
    |> cast(attrs, [:status, :lock_version])
    |> validate_required([:status, :lock_version])
    |> validate_inclusion(:status, ~w(waiting booked declined))
    |> check_constraint(:status, name: :valid_lead_status)
    |> optimistic_lock(:lock_version)
  end

  def follow_up_changeset(lead, attrs) do
    lead
    |> cast(attrs, [:status, :notes])
    |> validate_required([:status])
    |> validate_inclusion(:status, ~w(new contacted closed waiting booked declined))
    |> validate_length(:notes, max: 4000)
  end

  @spec seen?(t()) :: boolean()
  def seen?(%__MODULE__{seen_at: %DateTime{}}), do: true
  def seen?(%__MODULE__{}), do: false

  defp validate_a_way_to_reach_them(changeset) do
    if blank?(get_field(changeset, :phone)) and blank?(get_field(changeset, :email)) do
      add_error(changeset, :phone, "leave a phone number or an email so we can reply")
    else
      changeset
    end
  end

  defp trim(changeset, fields) do
    Enum.reduce(fields, changeset, fn field, current ->
      update_change(current, field, fn
        value when is_binary(value) -> String.trim(value)
        value -> value
      end)
    end)
  end

  defp blank?(value), do: value in [nil, ""]
end
