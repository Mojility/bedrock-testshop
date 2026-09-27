defmodule Shop.Leads.Activity do
  @moduledoc "An append-only record of a staff member changing a lead's pipeline stage."
  use Ecto.Schema

  @primary_key {:id, :binary_id, autogenerate: true}
  @foreign_key_type :binary_id

  schema "lead_activities" do
    field :from_status, :string
    field :to_status, :string
    field :reason, :string
    belongs_to :lead, Shop.Leads.Lead
    belongs_to :user, Shop.Accounts.User
    timestamps(type: :utc_datetime_usec, updated_at: false)
  end
end
