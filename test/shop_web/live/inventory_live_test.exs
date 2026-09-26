defmodule ShopWeb.InventoryLiveTest do
  use ShopWeb.ConnCase, async: false

  import Phoenix.LiveViewTest
  import Shop.AccountsFixtures

  alias Shop.Accounts.Scope
  alias Shop.Inventory

  test "inventory requires local authentication", %{conn: conn} do
    assert {:error, {:redirect, %{to: "/users/log-in"}}} = live(conn, "/app/inventory")
  end

  test "staff can find inventory, add a part, and record its quantity", %{conn: conn} do
    user = user_fixture()
    conn = log_in_user(conn, user)

    {:ok, leads_view, _html} = live(conn, "/app/leads")
    assert has_element?(leads_view, "a[href='/app/inventory']")

    {:ok, view, _html} = live(conn, "/app/inventory")

    view
    |> form("#inventory-item-form", item: %{sku: "bolt-10", name: "10 mm Bolt", unit: "pieces"})
    |> render_submit()

    assert has_element?(view, "#inventory-items article", "10 mm Bolt")
    [item] = Inventory.list_items(Scope.for_user(user))

    view
    |> form("#inventory-movement-form",
      movement: %{
        item_id: item.id,
        quantity: "25",
        reason: "Opening count"
      }
    )
    |> render_submit()

    assert has_element?(view, "#inventory-items article", "25 pieces")
    assert has_element?(view, "#inventory-movements li", "Opening count")
  end

  test "a repeated operation is not applied twice" do
    user = user_fixture()
    scope = Scope.for_user(user)
    {:ok, item} = Inventory.create_item(scope, %{sku: "WASHER", name: "Washer", unit: "pieces"})
    operation_id = Ecto.UUID.generate()
    attrs = %{"quantity" => "4", "reason" => "Received", "operation_id" => operation_id}

    assert {:ok, _movement} = Inventory.record_movement(scope, item.id, attrs)
    assert {:error, _changeset} = Inventory.record_movement(scope, item.id, attrs)
    assert [%{quantity_on_hand: quantity_on_hand}] = Inventory.list_items(scope)
    assert Decimal.equal?(quantity_on_hand, 4)
  end
end
