defmodule ShopWeb.PageControllerTest do
  use ShopWeb.ConnCase

  import Shop.AccountsFixtures

  test "GET / names the shop and offers to log in", %{conn: conn} do
    conn = get(conn, ~p"/")
    html = html_response(conn, 200)
    assert html =~ Shop.name()
    assert html =~ ~p"/users/log-in"
  end

  test "GET / greets a signed-in user", %{conn: conn} do
    user = user_fixture()
    conn = conn |> log_in_user(user) |> get(~p"/")
    html = html_response(conn, 200)
    assert html =~ user.email
    assert html =~ ~p"/users/log-out"
  end
end
