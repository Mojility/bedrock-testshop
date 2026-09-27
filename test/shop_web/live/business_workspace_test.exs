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

  test "staff use lead details for follow-up, survey booking, history, and dismissal", %{
    conn: conn
  } do
    user = user_fixture()

    {:ok, earlier} =
      Leads.submit(%{
        "name" => "Earlier Jo",
        "email" => "jo@example.com",
        "message" => "Earlier enquiry"
      })

    {:ok, lead} =
      Leads.submit(%{
        "name" => "Jo",
        "email" => "jo@example.com",
        "message" => "Current enquiry"
      })

    {:ok, view, _} = live(log_in_user(conn, user), "/app/leads/#{lead.id}")
    assert has_element?(view, "#contact-history-#{earlier.id}", "Earlier enquiry")
    assert has_element?(view, "#lead-state", "New")

    view
    |> form("#follow-up-form",
      lead: %{notes: "Good initial call", survey_date: "2026-10-10"}
    )
    |> render_submit()

    assert has_element?(view, "#lead-state", "Site survey")
    assert has_element?(view, "#activity-history", "Good initial call")

    view
    |> form("#dismiss-form", lead: %{notes: "Outside service area"})
    |> render_submit()

    assert has_element?(view, "#lead-state", "Dismissed — not an opportunity")
    refute has_element?(view, "#follow-up-form")
  end

  test "lead detail keeps invalid follow-up recoverable", %{conn: conn} do
    {:ok, lead} = Leads.submit(%{"name" => "Jo", "phone" => "555"})
    {:ok, view, _} = live(log_in_user(conn, user_fixture()), "/app/leads/#{lead.id}")

    view
    |> form("#follow-up-form", lead: %{notes: "", survey_date: ""})
    |> render_submit()

    assert render(view) =~ "Add follow-up notes and choose a valid survey date."
    assert has_element?(view, "#lead-state", "New")
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
