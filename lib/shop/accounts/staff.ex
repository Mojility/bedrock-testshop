defmodule Shop.Accounts.Staff do
  @moduledoc "Local staff access. Owner bootstrap is a trusted deployment operation, never a public route."
  import Ecto.Query
  alias Shop.{Accounts, Repo}
  alias Shop.Accounts.{Scope, User, UserToken}

  def authorize!(%Scope{user: %User{id: id}}, roles \\ ["owner", "staff"]) do
    case Repo.get(User, id) do
      %User{disabled_at: nil, role: role} = user ->
        if role in roles, do: user, else: raise(Ecto.NoResultsError, queryable: User)

      _ ->
        raise Ecto.NoResultsError, queryable: User
    end
  end

  def bootstrap_owner(email) do
    Repo.transact(fn ->
      Repo.query!("LOCK TABLE users IN EXCLUSIVE MODE")

      if Repo.exists?(from u in User, where: u.role == "owner") do
        {:error, :owner_already_exists}
      else
        user = Repo.get_by(User, email: email) || %User{}

        user
        |> User.email_changeset(%{email: email}, validate_unique: false)
        |> Ecto.Changeset.put_change(:role, "owner")
        |> Repo.insert_or_update()
      end
    end)
  end

  def list(scope) do
    authorize!(scope, ["owner"])
    Repo.all(from u in User, order_by: u.email)
  end

  def invite(scope, email) do
    authorize!(scope, ["owner"])

    case Repo.get_by(User, email: email) do
      %User{role: "unassigned", disabled_at: nil} = user ->
        user |> Ecto.Changeset.change(role: "staff") |> Repo.update()

      _ ->
        Accounts.register_user(%{email: email})
    end
  end

  def revoke(scope, id) do
    authorize!(scope, ["owner"])

    Repo.transact(fn ->
      case Repo.get(User, id) do
        %User{role: "staff"} = user ->
          tokens = Repo.all(from t in UserToken, where: t.user_id == ^id)
          Repo.delete_all(from t in UserToken, where: t.user_id == ^id)

          {:ok, disabled} =
            user |> Ecto.Changeset.change(disabled_at: DateTime.utc_now()) |> Repo.update()

          {:ok, {disabled, tokens}}

        _ ->
          {:error, :cannot_revoke_owner}
      end
    end)
  end
end
