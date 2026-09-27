defmodule ShopWeb.StaffNavigation do
  @moduledoc "Staff destinations shared by operations pages; routes still enforce authorization."

  @destinations [
    %{
      id: "leads",
      label: "Sales pipeline",
      path: "/app/leads",
      roles: ["owner", "office_manager", "staff"]
    },
    %{id: "team", label: "Team", path: "/app/team", roles: ["owner"]}
  ]

  def for_scope(%{user: %{role: role}}), do: Enum.filter(@destinations, &(role in &1.roles))
  def for_scope(_), do: []
end
