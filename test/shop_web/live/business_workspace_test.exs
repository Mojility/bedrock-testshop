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

    assert has_element?(
             view,
             "nav[aria-label='Staff navigation'] a[aria-current='page'][href='/app/leads']"
           )

    assert has_element?(view, "#leads[aria-labelledby='leads-title'] h1", "Leads")
    assert has_element?(view, "#lead-card-#{lead.id} dt", "Received")

    view
    |> form("#follow-up-#{lead.id}", lead: %{status: "contacted", notes: "Called today"})
    |> render_submit()

    assert has_element?(view, "#lead-card-#{lead.id}", "Contacted")
    assert Shop.Repo.get!(Leads.Lead, lead.id).notes == "Called today"
    refute has_element?(view, "a[href='/app/team']")
  end

  test "owner invites staff and revokes access", %{conn: conn} do
    {:ok, owner} = Staff.bootstrap_owner("owner@example.com")
    {:ok, view, _} = live(log_in_user(conn, owner), "/app/leads")

    {:ok, view, _} =
      view
      |> element("nav a[href='/app/team']")
      |> render_click()
      |> follow_redirect(conn |> log_in_user(owner))

    assert has_element?(view, "nav a[aria-current='page'][href='/app/team']")
    assert has_element?(view, "#invite-staff[aria-labelledby='invite-staff-title']")
    assert has_element?(view, "#staff-access[aria-labelledby='staff-access-title']")
    view |> form("#invite-form", invite: %{email: "staff@example.com"}) |> render_submit()
    staff = Accounts.get_user_by_email("staff@example.com")
    assert has_element?(view, "#users-#{staff.id}")
    view |> element("#users-#{staff.id} button") |> render_click()
    assert has_element?(view, "#users-#{staff.id}", "Access revoked")
    refute Accounts.get_user_by_email(staff.email)
  end

  test "staff cannot enter owner workflows despite a direct URL", %{conn: conn} do
    assert_raise Ecto.NoResultsError, fn ->
      live(log_in_user(conn, user_fixture()), "/app/team")
    end
  end

  test "empty workspace explains where records will come from", %{conn: conn} do
    {:ok, view, _} = live(log_in_user(conn, user_fixture()), "/app/leads")
    assert has_element?(view, "#leads-empty", "No enquiries yet")
    assert has_element?(view, "button[aria-label='Use light theme']")
    assert has_element?(view, "button[aria-label='Use dark theme']")
  end
end
