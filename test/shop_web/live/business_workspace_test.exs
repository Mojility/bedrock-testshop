defmodule ShopWeb.BusinessWorkspaceTest do
  use ShopWeb.ConnCase, async: false
  import Phoenix.LiveViewTest
  import Shop.AccountsFixtures
  alias Shop.{Accounts, Leads}
  alias Shop.Accounts.Staff

  test "leads require local authentication", %{conn: conn} do
    assert {:error, {:redirect, %{to: "/users/log-in"}}} = live(conn, "/app/leads")
  end

  test "staff read and follow up on enquiries inside their own system", %{conn: conn} do
    {:ok, lead} =
      Leads.submit(%{"name" => "Jo", "email" => "jo@example.com", "message" => "Please call"})

    {:ok, view, _} = live(log_in_user(conn, user_fixture()), "/app/leads")
    assert has_element?(view, "#leads-#{lead.id}", "Jo")

    assert has_element?(view, "#pipeline-stats")
    assert has_element?(view, "#response-alert")

    view
    |> form("#follow-up-#{lead.id}", lead: %{status: "survey", notes: "Survey booked"})
    |> render_submit()

    assert has_element?(view, "#leads-#{lead.id} .badge", "Site survey")
    refute has_element?(view, "#response-alert")

    saved = Shop.Repo.get!(Leads.Lead, lead.id)
    assert saved.notes == "Survey booked"
    assert saved.responded_at
    assert saved.surveyed_at

    activity = Shop.Repo.get_by!(Leads.Activity, lead_id: lead.id)
    assert activity.from_status == "new"
    assert activity.to_status == "survey"
    assert activity.user_id
    refute has_element?(view, "a[href='/app/team']")
  end

  test "owner invites staff and revokes access", %{conn: conn} do
    {:ok, owner} = Staff.bootstrap_owner("owner@example.com")
    {:ok, view, _} = live(log_in_user(conn, owner), "/app/team")
    view |> form("#invite-form", invite: %{email: "staff@example.com"}) |> render_submit()
    staff = Accounts.get_user_by_email("staff@example.com")
    assert has_element?(view, "#users-#{staff.id}")
    view |> element("#users-#{staff.id} button") |> render_click()
    assert has_element?(view, "#users-#{staff.id}", "Access revoked")
    refute Accounts.get_user_by_email(staff.email)
  end
end
