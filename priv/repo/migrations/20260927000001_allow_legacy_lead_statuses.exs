defmodule Shop.Repo.Migrations.AllowLegacyLeadStatuses do
  use Ecto.Migration

  def up do
    replace_status_constraint(
      "status IN ('new', 'contacted', 'closed', 'conversation', 'survey', 'quote', 'job_closed', 'lost')"
    )
  end

  def down do
    execute("UPDATE leads SET status = 'conversation' WHERE status = 'contacted'")
    execute("UPDATE leads SET status = 'lost' WHERE status = 'closed'")

    replace_status_constraint(
      "status IN ('new', 'conversation', 'survey', 'quote', 'job_closed', 'lost')"
    )
  end

  defp replace_status_constraint(check) do
    drop constraint(:leads, :valid_lead_status)
    create constraint(:leads, :valid_lead_status, check: check)
  end
end
