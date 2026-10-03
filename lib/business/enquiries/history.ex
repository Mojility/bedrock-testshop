defmodule Business.Enquiries.History do
  @moduledoc "An append-only record of staff changes to a job enquiry."
  use Ecto.Schema

  @primary_key {:id, :binary_id, autogenerate: true}
  @foreign_key_type :binary_id

  schema "job_enquiry_history" do
    field :action, :string
    field :from_status, :string
    field :to_status, :string
    belongs_to :job_enquiry, Business.Enquiries.Enquiry
    belongs_to :actor, Business.Accounts.User
    timestamps(type: :utc_datetime_usec, updated_at: false)
  end
end
