defmodule Shop.BusinessWorkspaceTest do
  use Shop.DataCase, async: false
  alias Shop.{Accounts, Leads, Repo}
  alias Shop.Accounts.{Scope, Staff}
  import Shop.AccountsFixtures
  import Swoosh.TestAssertions

  test "owner bootstrap is single-use; staff cannot invite or revoke; revocation blocks stale scopes and tokens" do
    {:ok, owner} = Staff.bootstrap_owner("owner@example.com")
    scope = Scope.for_user(owner)
    assert owner.role == "owner"
    assert {:error, :owner_already_exists} = Staff.bootstrap_owner("intruder@example.com")
    {:ok, staff} = Staff.invite(scope, "staff@example.com")
    staff_scope = Scope.for_user(staff)
    token = Accounts.generate_user_session_token(staff)
    assert_raise Ecto.NoResultsError, fn -> Staff.invite(staff_scope, "another@example.com") end
    assert {:error, :cannot_revoke_owner} = Staff.revoke(scope, owner.id)
    assert {:ok, {_, [_]}} = Staff.revoke(scope, staff.id)
    assert is_nil(Accounts.get_user_by_session_token(token))
    assert is_nil(Accounts.get_user_by_email(staff.email))
    assert_raise Ecto.NoResultsError, fn -> Leads.list(staff_scope) end
  end

  test "existing unassigned accounts require an explicit staff grant" do
    {:ok, owner} = Staff.bootstrap_owner("owner@example.com")
    user = user_fixture() |> Ecto.Changeset.change(role: "unassigned") |> Repo.update!()
    assert_raise Ecto.NoResultsError, fn -> Leads.list(Scope.for_user(user)) end
    assert {:ok, %{id: id, role: "staff"}} = Staff.invite(Scope.for_user(owner), user.email)
    assert id == user.id
    assert [] = Leads.list(Scope.for_user(user))
  end

  test "enquiries validate contact, ignore submitted privileges, and support authenticated follow-up" do
    assert {:error, _} = Leads.submit(%{"name" => "Jo"})

    {:ok, lead} =
      Leads.submit(%{
        "name" => "Jo",
        "phone" => "555",
        "status" => "closed",
        "notes" => "injected"
      })

    assert lead.status == "new"
    assert is_nil(lead.notes)
    scope = Scope.for_user(user_fixture())
    assert [%{id: id}] = Leads.list(scope)
    assert id == lead.id

    assert {:ok, updated} =
             Leads.follow_up(scope, id, %{
               "status" => "contacted",
               "notes" => "Called; quotation on Friday"
             })

    assert updated.seen_at
    assert updated.notes =~ "Friday"
    assert {:error, _} = Leads.follow_up(scope, id, %{"status" => "invalid"})
  end

  test "legacy import preserves timestamps and is replay-safe without overwriting follow-up" do
    id = Ecto.UUID.generate()

    row = %{
      "id" => id,
      "name" => "Jo",
      "phone" => "555",
      "inserted_at" => "2026-09-01T12:00:00.000000Z",
      "seen_at" => "2026-09-02T12:00:00.000000Z"
    }

    assert {:ok, 1} = Leads.import_legacy([row])
    scope = Scope.for_user(user_fixture())
    [lead] = Leads.list(scope)
    assert lead.legacy_id == id
    assert DateTime.to_iso8601(lead.seen_at) == row["seen_at"]
    {:ok, _} = Leads.follow_up(scope, lead.id, %{"status" => "closed"})
    assert {:ok, 1} = Leads.import_legacy([row])
    assert [%{status: "closed"}] = Leads.list(scope)
    assert Repo.aggregate(Leads.Lead, :count) == 1
  end

  test "pending notifications wait for a confirmed owner and survive until delivered" do
    {:ok, owner} = Staff.bootstrap_owner("owner@example.com")
    {:ok, lead} = Leads.submit(%{"name" => "Jo", "phone" => "555"})
    assert {:ok, :checked} = Leads.Notifier.deliver_pending()
    assert is_nil(Repo.get!(Leads.Lead, lead.id).notified_at)
    owner |> Accounts.User.confirm_changeset() |> Repo.update!()
    assert {:ok, :checked} = Leads.Notifier.deliver_pending(fn _ -> {:error, :offline} end)
    assert is_nil(Repo.get!(Leads.Lead, lead.id).notified_at)
    assert {:ok, :checked} = Leads.Notifier.deliver_pending()
    assert Repo.get!(Leads.Lead, lead.id).notified_at
    assert_email_sent(subject: "New enquiry for #{Shop.name()}")
  end
end
