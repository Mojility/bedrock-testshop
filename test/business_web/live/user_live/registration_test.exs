defmodule BusinessWeb.UserLive.RegistrationTest do
  use BusinessWeb.ConnCase, async: true

  test "staff accounts cannot be self-registered", %{conn: conn} do
    assert get(conn, "/users/register").status == 404
  end
end
