defmodule BusinessWeb.BusinessWorkspaceTest do
  use BusinessWeb.ConnCase, async: false
  import Phoenix.LiveViewTest
  import Business.AccountsFixtures
  alias Business.{Accounts, Leads, Repo}
  alias Business.Accounts.Staff
  alias Business.Enquiries.{Enquiry, History}

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
    assert Business.Repo.get!(Leads.Lead, lead.id).notes == "Called today"
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

  test "staff record and book an emailed enquiry in the week view", %{conn: conn} do
    staff = user_fixture()

    requested_date =
      Date.utc_today()
      |> then(&Date.add(&1, 1 - Date.day_of_week(&1) + 6))

    {:ok, view, _} = live(log_in_user(conn, staff), "/app/leads")

    {:ok, view, _} =
      view
      |> element("nav a[href='/app/enquiries']")
      |> render_click()
      |> follow_redirect(log_in_user(conn, staff))

    assert has_element?(view, "nav a[aria-current='page'][href='/app/enquiries']")

    view
    |> form("#enquiry-form",
      enquiry: %{
        customer_name: "Morgan",
        request: "Panel upgrade",
        location: "Minden",
        requested_date: Date.to_iso8601(requested_date),
        source: "email",
        status: "waiting"
      }
    )
    |> render_submit()

    enquiry = Repo.one!(Enquiry)
    assert enquiry.status == "waiting"
    assert has_element?(view, "#week-enquiries", "Panel upgrade")

    view
    |> form("#status-#{enquiry.id}", enquiry: %{status: "booked"})
    |> render_submit()

    assert Repo.get!(Enquiry, enquiry.id).status == "booked"
    assert Repo.aggregate(History, :count) == 2
    assert has_element?(view, "#week-enquiries", "Booked")
  end

  test "job enquiries require local authentication", %{conn: conn} do
    assert {:error, {:redirect, %{to: "/users/log-in"}}} = live(conn, "/app/enquiries")
  end
end
