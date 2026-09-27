defmodule Shop.Repo.Migrations.AddSurveySiteAddress do
  use Ecto.Migration

  def change do
    alter table(:leads) do
      add :survey_address, :string
    end
  end
end
