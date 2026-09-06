defmodule Shop.Leads.Lead do
  @moduledoc """
  Someone who asked to be contacted through a shop's website: who they are,
  how to reach them, and what they need. Written once; the only thing that
  changes afterwards is `seen_at`, the moment the owner first looked at it
  in the console.
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
    field :source, :string, default: "site"
    field :notified_at, :utc_datetime_usec
    field :seen_at, :utc_datetime_usec
    field :status, :string, default: "new"
    field :notes, :string
    field :legacy_id, :binary_id

    timestamps(type: :utc_datetime_usec, updated_at: false)
  end

  @doc false
  def changeset(lead, attrs) do
    lead
    |> cast(attrs, [:name, :phone, :email, :message])
    |> update_change(:name, &trim/1)
    |> update_change(:phone, &trim/1)
    |> update_change(:email, &trim/1)
    |> update_change(:message, &trim/1)
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

  @doc "Whether the owner has looked at this lead yet."
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

  defp blank?(value), do: value in [nil, ""]

  defp trim(value) when is_binary(value), do: String.trim(value)
  defp trim(value), do: value
end
