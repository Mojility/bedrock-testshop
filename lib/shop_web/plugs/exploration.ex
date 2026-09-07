defmodule ShopWeb.Plugs.Exploration do
  @moduledoc "Browser policy and local staff access for an explicitly isolated working copy."
  import Plug.Conn
  def init(opts), do: opts

  def call(conn, _) do
    case Application.get_env(:shop, :exploration) do
      nil ->
        conn

      config ->
        conn =
          conn
          |> delete_resp_header("x-frame-options")
          |> put_resp_header("cache-control", "no-store")

        ancestors =
          [config.parent_origin, Map.get(config, :platform_origin)]
          |> Enum.reject(&is_nil/1)
          |> Enum.uniq()
          |> Enum.join(" ")

        policy =
          "default-src 'self'; script-src 'self'; style-src 'self' 'unsafe-inline'; img-src 'self' data: #{config.media_origin}; font-src 'self'; connect-src 'self'; object-src 'none'; base-uri 'self'; form-action 'self'; frame-ancestors #{ancestors}"

        conn = put_resp_header(conn, "content-security-policy", policy)

        if conn.method == "GET" and conn.request_path == "/users/log-in" do
          # Only enable behind private access control. Never runs in production mode.
          user =
            Shop.Repo.get_by(Shop.Accounts.User, email: "workspace-owner@example.invalid") ||
              create_owner!()

          conn |> ShopWeb.UserAuth.log_in_user(user) |> halt()
        else
          conn
        end
    end
  end

  defp create_owner! do
    {:ok, user} = Shop.Accounts.register_user(%{email: "workspace-owner@example.invalid"})
    user |> Ecto.Changeset.change(role: "owner") |> Shop.Repo.update!()
  end
end
