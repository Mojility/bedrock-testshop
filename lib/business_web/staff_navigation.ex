defmodule BusinessWeb.StaffNavigation do
  @moduledoc "Staff destinations shared by every operations page; routes still enforce authorization."

  @destinations [
    %{id: "leads", label: "Leads", path: "/app/leads", roles: ["owner", "staff"]},
    %{
      id: "enquiries",
      label: "Week view",
      path: "/app/enquiries",
      roles: ["owner", "staff"]
    },
    %{id: "team", label: "Team", path: "/app/team", roles: ["owner"]}
  ]

  def for_scope(%{user: %{role: role}}),
    do: Enum.filter(@destinations, &(role in &1.roles))

  def for_scope(_), do: []
end
