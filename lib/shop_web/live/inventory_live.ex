defmodule ShopWeb.InventoryLive do
  use ShopWeb, :live_view

  alias Shop.Inventory
  alias Shop.Inventory.Item

  def mount(_params, _session, socket) do
    items = Inventory.list_items(socket.assigns.current_scope)
    movements = Inventory.list_movements(socket.assigns.current_scope)

    {:ok,
     socket
     |> assign(:page_title, "Inventory")
     |> assign(:items_for_form, items)
     |> assign(:item_form, to_form(Item.changeset(%Item{}, %{})))
     |> assign(:movement_form, movement_form())
     |> stream(:items, items)
     |> stream(:movements, movements)}
  end

  def handle_event("create-item", %{"item" => attrs}, socket) do
    case Inventory.create_item(socket.assigns.current_scope, attrs) do
      {:ok, _item} ->
        {:noreply,
         socket
         |> put_flash(:info, "Part added.")
         |> assign(:item_form, to_form(Item.changeset(%Item{}, %{})))
         |> refresh_items()}

      {:error, changeset} ->
        {:noreply, assign(socket, :item_form, to_form(changeset, action: :insert))}
    end
  end

  def handle_event("record-movement", %{"movement" => attrs}, socket) do
    item_id = attrs["item_id"]

    case Inventory.record_movement(socket.assigns.current_scope, item_id, attrs) do
      {:ok, _movement} ->
        {:noreply,
         socket
         |> put_flash(:info, "Quantity recorded.")
         |> assign(:movement_form, movement_form())
         |> refresh_items()}

      {:error, _reason} ->
        {:noreply,
         socket
         |> put_flash(:error, "Choose a part, enter a non-zero whole quantity, and explain why.")
         |> assign(:movement_form, to_form(attrs, as: :movement))}
    end
  end

  def render(assigns) do
    ~H"""
    <Layouts.app flash={@flash} current_scope={@current_scope}>
      <section id="inventory" class="space-y-8">
        <header>
          <h1 class="text-3xl font-bold">Inventory</h1>
          <p class="mt-2 text-base-content/70">
            Track each part and record every receipt, use, or correction so quantities remain explainable.
          </p>
        </header>

        <div class="grid gap-6 sm:grid-cols-2">
          <.form
            for={@item_form}
            id="inventory-item-form"
            phx-submit="create-item"
            class="space-y-4 rounded-box border border-base-300 p-6"
          >
            <h2 class="text-xl font-semibold">Add a part</h2>
            <.input field={@item_form[:sku]} label="SKU" required maxlength="80" />
            <.input field={@item_form[:name]} label="Part name" required maxlength="160" />
            <.input
              field={@item_form[:unit]}
              label="Unit"
              placeholder="pieces"
              required
              maxlength="40"
            />
            <.button variant="primary" phx-disable-with="Adding…">Add part</.button>
          </.form>

          <.form
            for={@movement_form}
            id="inventory-movement-form"
            phx-submit="record-movement"
            class="space-y-4 rounded-box border border-base-300 p-6"
          >
            <h2 class="text-xl font-semibold">Record a quantity change</h2>
            <.input
              field={@movement_form[:item_id]}
              type="select"
              label="Part"
              prompt="Choose a part"
              options={Enum.map(@items_for_form, &{"#{&1.name} (#{&1.sku})", &1.id})}
              required
            />
            <.input
              field={@movement_form[:quantity]}
              type="number"
              label="Quantity change (positive received, negative used)"
              required
            />
            <.input field={@movement_form[:reason]} label="Reason" required maxlength="500" />
            <input
              type="hidden"
              name={@movement_form[:operation_id].name}
              value={@movement_form[:operation_id].value}
            />
            <.button variant="primary" phx-disable-with="Recording…">Record change</.button>
          </.form>
        </div>

        <div>
          <h2 class="text-xl font-semibold">Parts on hand</h2>
          <p class="mt-1 text-sm text-base-content/70">
            Balances are calculated from the complete movement history.
          </p>
        </div>
        <div id="inventory-items" phx-update="stream" class="space-y-3">
          <div id="inventory-empty" class="hidden only:block rounded-box bg-base-200 p-6">
            No parts yet. Add the first part above, then record what is on hand.
          </div>
          <article
            :for={{id, item} <- @streams.items}
            id={id}
            class="rounded-box border border-base-300 p-5"
          >
            <div class="flex flex-wrap items-start justify-between gap-3">
              <div>
                <h3 class="font-semibold">{item.name}</h3><p class="text-sm text-base-content/70">
                  SKU {item.sku}
                </p>
              </div>
              <p class="text-lg font-bold">
                <span class="sr-only">Quantity on hand: </span>{item.quantity_on_hand} {item.unit}
              </p>
            </div>
          </article>
        </div>

        <div>
          <h2 class="text-xl font-semibold">Recent quantity history</h2>
          <p class="mt-1 text-sm text-base-content/70">
            The latest 100 changes, including who recorded them and why.
          </p>
        </div>
        <ol id="inventory-movements" phx-update="stream" class="space-y-3">
          <li id="inventory-movements-empty" class="hidden only:block rounded-box bg-base-200 p-6">
            No quantity changes have been recorded yet.
          </li>
          <li
            :for={{id, movement} <- @streams.movements}
            id={id}
            class="rounded-box border border-base-300 p-5"
          >
            <div class="flex flex-wrap justify-between gap-3">
              <p class="font-semibold">{movement.item.name} ({movement.item.sku})</p>
              <p class="font-bold">
                {if movement.quantity > 0, do: "+", else: ""}{movement.quantity} {movement.item.unit}
              </p>
            </div>
            <p class="mt-2">{movement.reason}</p>
            <p class="mt-1 text-sm text-base-content/70">
              {movement.actor.email} ·
              <time datetime={DateTime.to_iso8601(movement.inserted_at)}>{Calendar.strftime(
                movement.inserted_at,
                "%b %-d, %Y · %H:%M UTC"
              )}</time>
            </p>
          </li>
        </ol>
      </section>
    </Layouts.app>
    """
  end

  defp refresh_items(socket) do
    items = Inventory.list_items(socket.assigns.current_scope)
    movements = Inventory.list_movements(socket.assigns.current_scope)

    socket
    |> assign(:items_for_form, items)
    |> stream(:items, items, reset: true)
    |> stream(:movements, movements, reset: true)
  end

  defp movement_form do
    to_form(
      %{
        "item_id" => "",
        "quantity" => "",
        "reason" => "",
        "operation_id" => Ecto.UUID.generate()
      },
      as: :movement
    )
  end
end
