defmodule ShopWeb.InventoryLive do
  use ShopWeb, :live_view

  alias Shop.Inventory

  def mount(params, _session, socket) do
    scope = socket.assigns.current_scope
    search = Map.get(params, "q", "")
    parts = Inventory.list_parts(scope, search)

    {:ok,
     socket
     |> assign(:page_title, "Inventory")
     |> assign(:search, search)
     |> assign(:parts_empty?, parts == [])
     |> assign(:part_form, to_form(Inventory.change_part(scope)))
     |> assign(:selected_part, nil)
     |> assign(:event_form, nil)
     |> stream(:parts, parts)}
  end

  def handle_params(%{"id" => id}, _uri, socket) do
    part = Inventory.get_part!(socket.assigns.current_scope, id)

    {:noreply,
     socket
     |> assign(:selected_part, part)
     |> assign(:event_form, to_form(Inventory.change_event(socket.assigns.current_scope)))}
  end

  def handle_params(_params, _uri, socket), do: {:noreply, assign(socket, :selected_part, nil)}

  def handle_event("search", %{"search" => %{"query" => query}}, socket) do
    parts = Inventory.list_parts(socket.assigns.current_scope, query)

    {:noreply,
     socket
     |> assign(:search, query)
     |> assign(:parts_empty?, parts == [])
     |> stream(:parts, parts, reset: true)}
  end

  def handle_event("validate_part", %{"part" => attrs}, socket) do
    form =
      socket.assigns.current_scope
      |> Inventory.change_part(attrs)
      |> Map.put(:action, :validate)
      |> to_form()

    {:noreply, assign(socket, :part_form, form)}
  end

  def handle_event("create_part", %{"part" => attrs}, socket) do
    case Inventory.create_part(socket.assigns.current_scope, attrs) do
      {:ok, part} ->
        {:noreply,
         socket
         |> stream_insert(:parts, part)
         |> assign(:parts_empty?, false)
         |> assign(:part_form, to_form(Inventory.change_part(socket.assigns.current_scope)))
         |> put_flash(:info, "Part added to inventory.")}

      {:error, changeset} ->
        {:noreply, assign(socket, :part_form, to_form(changeset))}
    end
  end

  def handle_event("validate_event", %{"event" => attrs}, socket) do
    form =
      socket.assigns.current_scope
      |> Inventory.change_event(attrs)
      |> Map.put(:action, :validate)
      |> to_form()

    {:noreply, assign(socket, :event_form, form)}
  end

  def handle_event("record_event", %{"event" => attrs}, socket) do
    case Inventory.record_event(socket.assigns.current_scope, socket.assigns.selected_part.id, attrs) do
      {:ok, _event} ->
        part = Inventory.get_part!(socket.assigns.current_scope, socket.assigns.selected_part.id)

        {:noreply,
         socket
         |> assign(:selected_part, part)
         |> assign(:event_form, to_form(Inventory.change_event(socket.assigns.current_scope)))
         |> put_flash(:info, "Inventory movement recorded.")}

      {:error, changeset} ->
        {:noreply, assign(socket, :event_form, to_form(changeset))}
    end
  end

  def render(assigns) do
    ~H"""
    <Layouts.app flash={@flash} current_scope={@current_scope}>
      <section id="inventory" class="space-y-8">
        <header>
          <h1 class="text-3xl font-bold">Inventory</h1>
          <p class="mt-2 text-base-content/70">Search parts and record every stock change as a permanent movement.</p>
        </header>

        <.form for={to_form(%{"query" => @search}, as: :search)} id="inventory-search" phx-change="search">
          <.input field={to_form(%{"query" => @search}, as: :search)[:query]} type="search" label="Search parts" placeholder="SKU or part name" phx-debounce="300" />
        </.form>

        <.form for={@part_form} id="new-part-form" phx-change="validate_part" phx-submit="create_part" class="rounded-box border border-base-300 p-5 space-y-3">
          <h2 class="text-xl font-semibold">Add a part</h2>
          <div class="grid gap-3 sm:grid-cols-2">
            <.input field={@part_form[:sku]} label="SKU" required />
            <.input field={@part_form[:name]} label="Part name" required />
            <.input field={@part_form[:unit]} label="Unit" required />
            <.input field={@part_form[:valuation_strategy]} type="select" label="Pricing strategy" options={[{"First in, first out", "fifo"}, {"Average cost", "average"}, {"Other", "other"}]} required />
          </div>
          <.button id="add-part" variant="primary" phx-disable-with="Adding…">Add part</.button>
        </.form>

        <div id="parts-list" phx-update="stream" class="space-y-3">
          <p id="parts-empty" class={if(@parts_empty?, do: "rounded-box bg-base-200 p-5", else: "hidden")}>No parts match this search.</p>
          <article :for={{id, part} <- @streams.parts} id={id} class="rounded-box border border-base-300 p-5 flex items-center justify-between gap-4">
            <div><h2 class="font-semibold">{part.name}</h2><p class="text-sm text-base-content/70">{part.sku} · {part.valuation_strategy}</p></div>
            <div class="text-right"><p class="font-mono font-semibold">{part.quantity_on_hand} {part.unit}</p><.link navigate={~p"/app/inventory/#{part.id}"} class="link">View movements</.link></div>
          </article>
        </div>

        <section :if={@selected_part} id="part-detail" class="border-t border-base-300 pt-8 space-y-6">
          <div><.link navigate={~p"/app/inventory"} class="link">Back to inventory</.link><h2 class="mt-3 text-2xl font-bold">{@selected_part.name}</h2><p>{@selected_part.sku} · On hand: <strong>{@selected_part.quantity_on_hand} {@selected_part.unit}</strong></p></div>
          <.form for={@event_form} id="inventory-event-form" phx-change="validate_event" phx-submit="record_event" class="rounded-box bg-base-200 p-5 space-y-3">
            <h3 class="text-lg font-semibold">Record a movement</h3>
            <.input field={@event_form[:kind]} type="select" label="Movement" options={[{"Add stock", "receipt"}, {"Remove stock", "removal"}, {"Adjustment", "adjustment"}]} required />
            <.input field={@event_form[:quantity]} type="number" step="0.0001" label="Quantity" required />
            <.input field={@event_form[:unit_cost]} type="number" min="0" step="0.01" label="Unit cost (optional)" />
            <.input field={@event_form[:reason]} label="Reason" required />
            <.button id="record-movement" variant="primary" phx-disable-with="Recording…">Record movement</.button>
          </.form>
          <div id="movement-history" class="space-y-3"><h3 class="text-lg font-semibold">Movement history</h3><p :if={@selected_part.events == []} class="text-base-content/70">No movements yet.</p><article :for={event <- @selected_part.events} id={"event-#{event.id}"} class="rounded-box border border-base-300 p-4"><div class="flex justify-between gap-3"><strong>{event.kind}</strong><span class="font-mono">{event.quantity} {@selected_part.unit}</span></div><p>{event.reason}</p><p class="text-sm text-base-content/70">{event.actor.email} · {Calendar.strftime(event.inserted_at, "%b %-d, %Y · %H:%M UTC")}</p></article></div>
        </section>
      </section>
    </Layouts.app>
    """
  end
end
