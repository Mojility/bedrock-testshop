defmodule BusinessWeb.CatalogueLive do
  @moduledoc "Development-only living catalogue. All examples use session-local synthetic data."
  use BusinessWeb, :live_view

  alias Business.Catalogue.Components
  alias Business.Catalogue.Domain
  alias Business.Catalogue.Enquiries
  alias Business.Catalogue.Model
  alias Business.Catalogue.Receiving
  alias Business.Catalogue.Stock
  alias Business.Catalogue.Temporal
  alias BusinessWeb.Workbench

  embed_templates "catalogue/*"

  @sections ~w(foundations controls compositions blueprints graph domain model)
  @blueprint_path Path.expand("../../../priv/catalogue/receiving.json", __DIR__)
  @external_resource @blueprint_path
  @blueprint @blueprint_path |> File.read!() |> Jason.decode!()

  @impl true
  def mount(_params, _session, socket) do
    state = Receiving.initial()

    {:ok,
     assign(socket,
       page_title: "Component catalogue",
       section: "foundations",
       component_id: "split",
       domain_id: "inventory_item",
       model_id: "actor:warehouse_staff",
       schedule_form:
         to_form(Temporal.schedule_form(Temporal.schedule_defaults()), as: :schedule),
       appointments: [],
       range_form: to_form(Temporal.date_range_form(Temporal.range_defaults()), as: :range),
       date_range: %{from: ~D[2026-09-01], to: ~D[2026-09-30]},
       timestamp_form:
         to_form(Temporal.timestamp_form(Temporal.receipt_defaults()), as: :timestamp),
       timestamp_result: nil,
       enquiries: Enquiries.initial(),
       count: 0,
       theme: "light",
       scenario: "receiving",
       compact: false,
       query: "",
       stock_page_number: 1,
       stock_page_size: 25,
       stock_category: "All categories",
       stock_sort: "name",
       stock_direction: "asc",
       filter_form: to_form(%{"query" => ""}, as: :filter),
       selected: "MAT-112",
       receipt: state,
       receipt_form: receipt_form(state),
       result: nil,
       field_done: false,
       control_form: to_form(%{"name" => "", "status" => "Draft"}, as: :example),
       control_result: nil,
       blueprint: blueprint(),
       nodes: nodes()
     )}
  end

  @impl true
  def handle_params(params, _uri, socket) do
    section = params["section"]

    section = if section in @sections, do: section, else: "foundations"

    {:noreply,
     assign(socket,
       section: section,
       component_id: Components.get(params["node"] || "split").id,
       model_id: Model.get(params["node"])["id"],
       domain_id: Domain.get(params["node"] || "inventory_item")["id"],
       page_title: "#{String.capitalize(section)} · Component catalogue"
     )}
  end

  @impl true
  def handle_event("submit_enquiry", %{"enquiry" => params}, socket) do
    state = Enquiries.submit(socket.assigns.enquiries, params)
    socket = assign(socket, :enquiries, state)

    socket =
      if state.form.source.valid?,
        do: socket,
        else:
          push_event(socket, "workbench:focus", %{
            selector: "#enquiry-demo-form [aria-invalid=true]"
          })

    {:noreply, socket}
  end

  def handle_event("select_enquiry", %{"id" => id}, socket) do
    {:noreply, assign(socket, :enquiries, Enquiries.select(socket.assigns.enquiries, id))}
  end

  def handle_event("save_enquiry_follow_up", %{"follow_up" => params}, socket) do
    state = Enquiries.follow_up(socket.assigns.enquiries, params)
    socket = assign(socket, :enquiries, state)

    socket =
      if state.follow_up.source.valid?,
        do: socket,
        else:
          push_event(socket, "workbench:focus", %{
            selector: "#lead-follow-up-form [aria-invalid=true]"
          })

    {:noreply, socket}
  end

  def handle_event("schedule", %{"schedule" => params}, socket) do
    case Temporal.schedule(params, socket.assigns.appointments) do
      {:ok, appointment} ->
        {:noreply,
         socket
         |> assign(schedule_form: to_form(Temporal.schedule_form(params), as: :schedule))
         |> update(:appointments, &(&1 ++ [appointment]))}

      {:error, changeset} ->
        {:noreply,
         socket
         |> assign(schedule_form: to_form(changeset, as: :schedule))
         |> push_event("workbench:focus", %{selector: "#schedule-form [aria-invalid=true]"})}
    end
  end

  def handle_event("date_range", %{"range" => params}, socket) do
    changeset = Temporal.date_range_form(params) |> Map.put(:action, :validate)
    socket = assign(socket, range_form: to_form(changeset, as: :range))

    case Ecto.Changeset.apply_action(changeset, :validate) do
      {:ok, range} -> {:noreply, assign(socket, date_range: range)}
      {:error, _} -> {:noreply, socket}
    end
  end

  def handle_event("timestamp", %{"timestamp" => params}, socket) do
    changeset = Temporal.timestamp_form(params) |> Map.put(:action, :validate)

    socket =
      assign(socket, timestamp_form: to_form(changeset, as: :timestamp), timestamp_result: nil)

    case Ecto.Changeset.apply_action(changeset, :validate) do
      {:ok, values} ->
        {:ok, instant} = Temporal.instant(values.occurred_at, values.zone)
        {:noreply, assign(socket, timestamp_result: instant)}

      {:error, _} ->
        {:noreply,
         push_event(socket, "workbench:focus", %{selector: "#timestamp-form [aria-invalid=true]"})}
    end
  end

  def handle_event("domain_node", %{"node" => id}, socket) do
    {:noreply, push_patch(socket, to: "/dev/catalogue/domain?node=#{Domain.get(id)["id"]}")}
  end

  def handle_event("choose_part", %{"part_id" => id}, socket),
    do: handle_event("select", %{"id" => id}, socket)

  def handle_event("component", %{"node" => id}, socket) do
    {:noreply, push_patch(socket, to: "/dev/catalogue/graph?node=#{Components.get(id).id}")}
  end

  def handle_event("exercise", _, socket), do: {:noreply, update(socket, :count, &(&1 + 1))}

  def handle_event("theme", _, socket),
    do: {:noreply, update(socket, :theme, &if(&1 == "light", do: "dark", else: "light"))}

  def handle_event("density", _, socket), do: {:noreply, update(socket, :compact, &(!&1))}

  def handle_event("scenario", %{"scenario" => value}, socket)
      when value in ~w(receiving stock task schedule movements website-intro enquiry-form lead-queue lead-follow-up),
      do: {:noreply, assign(socket, scenario: value)}

  def handle_event("filter", %{"filter" => %{"query" => query}}, socket),
    do:
      {:noreply,
       assign(socket,
         query: query,
         stock_page_number: 1,
         filter_form: to_form(%{"query" => query}, as: :filter)
       )}

  def handle_event("clear_filter", _, socket) do
    {:noreply,
     socket
     |> assign(
       query: "",
       stock_category: "All categories",
       stock_page_number: 1,
       filter_form: to_form(%{"query" => ""}, as: :filter)
     )
     |> push_event("workbench:clear-search", %{id: "stock-filter"})}
  end

  def handle_event("sort_stock", %{"column" => column}, socket)
      when column in ~w(name on_hand reserved available) do
    direction =
      if socket.assigns.stock_sort == column && socket.assigns.stock_direction == "asc",
        do: "desc",
        else: "asc"

    {:noreply,
     assign(socket, stock_sort: column, stock_direction: direction, stock_page_number: 1)}
  end

  def handle_event("select", %{"id" => id}, socket) do
    if Stock.get(socket.assigns.receipt, id),
      do: {:noreply, assign(socket, selected: id)},
      else: {:noreply, socket}
  end

  def handle_event("stock_page", %{"page" => page}, socket) do
    case Integer.parse(page) do
      {number, ""} when number > 0 -> {:noreply, assign(socket, stock_page_number: number)}
      _ -> {:noreply, socket}
    end
  end

  def handle_event("stock_options", %{"options" => params}, socket) do
    requested_category = Map.get(params, "category", socket.assigns.stock_category)

    category =
      if requested_category in Stock.categories(), do: requested_category, else: "All categories"

    size =
      case Map.get(params, "size", to_string(socket.assigns.stock_page_size)) do
        "50" -> 50
        "100" -> 100
        _ -> 25
      end

    {:noreply,
     assign(socket, stock_category: category, stock_page_size: size, stock_page_number: 1)}
  end

  def handle_event("task", _, socket), do: {:noreply, update(socket, :field_done, &(!&1))}

  def handle_event("reset", _, socket) do
    state = Receiving.initial()
    {:noreply, assign(socket, receipt: state, receipt_form: receipt_form(state), result: nil)}
  end

  def handle_event("validate_receipt", %{"receipt" => params}, socket) do
    changeset = Receiving.form(socket.assigns.receipt, params) |> Map.put(:action, :validate)
    {:noreply, assign(socket, receipt_form: to_form(changeset, as: :receipt), result: nil)}
  end

  def handle_event("receive", %{"receipt" => params}, socket) do
    case Receiving.receive(socket.assigns.receipt, params) do
      {:ok, state} ->
        socket =
          assign(socket,
            receipt: state,
            receipt_form: receipt_form(state),
            result: "Receipt recorded. Stock and outstanding quantity updated."
          )

        socket =
          if state.received == state.ordered,
            do: push_event(socket, "workbench:focus", %{selector: "#receipt-complete"}),
            else: socket

        {:noreply, socket}

      {:error, changeset} ->
        {:noreply,
         socket
         |> assign(receipt_form: to_form(changeset, as: :receipt), result: nil)
         |> push_event("workbench:focus", %{selector: "#receipt-form [aria-invalid=true]"})}
    end
  end

  def handle_event("control_submit", %{"example" => params}, socket) do
    errors =
      if String.trim(params["name"] || "") == "",
        do: [name: {"Enter a customer name", []}],
        else: []

    result =
      if errors == [],
        do: "Saved #{params["name"]} as #{params["status"]} in this example.",
        else: nil

    socket =
      assign(socket,
        control_form: to_form(params, as: :example, errors: errors),
        control_result: result
      )

    socket =
      if errors != [],
        do:
          push_event(socket, "workbench:focus", %{selector: "#example-form [aria-invalid=true]"}),
        else: socket

    {:noreply, socket}
  end

  defp receipt_form(state) do
    params = %{
      "occurred_at" => "2026-09-26T09:30",
      "zone" => "America/Toronto",
      "quantity" => state.ordered - state.received,
      "reference" => "",
      "revision" => state.revision
    }

    state |> Receiving.form(params) |> to_form(as: :receipt)
  end

  defp blueprint, do: @blueprint

  defp nodes, do: Components.all()

  defp stock_page(assigns) do
    Stock.page(assigns.receipt, %{
      query: assigns.query,
      category: assigns.stock_category,
      sort: assigns.stock_sort,
      direction: assigns.stock_direction,
      page: assigns.stock_page_number,
      size: assigns.stock_page_size,
      selected: assigns.selected
    })
  end

  defp journey_story(assigns) do
    %{
      enquiries: assigns.enquiries,
      receipt: assigns.receipt,
      form: assigns.receipt_form,
      result: assigns.result,
      compact: assigns.compact,
      query: assigns.query,
      filter_form: assigns.filter_form,
      stock_page: assigns.stock_page,
      selected_part: assigns.selected_part,
      stock_options: assigns.stock_options,
      stock_sort: assigns.stock_sort,
      stock_direction: assigns.stock_direction,
      selected: assigns.selected,
      field_done: assigns.field_done,
      temporal: %{
        schedule_form: assigns.schedule_form,
        appointments: assigns.appointments,
        range_form: assigns.range_form,
        date_range: assigns.date_range,
        timestamp_form: assigns.timestamp_form,
        timestamp_result: assigns.timestamp_result,
        receipt: assigns.receipt
      }
    }
  end

  @impl true
  def render(assigns) do
    assigns =
      assign(assigns,
        stock_page: stock_page(assigns),
        selected_part: Stock.get(assigns.receipt, assigns.selected),
        stock_options:
          to_form(%{"category" => assigns.stock_category, "size" => assigns.stock_page_size},
            as: :options
          )
      )

    assigns = assign(assigns, :journey_story, journey_story(assigns))

    ~H"""
    <Layouts.app flash={@flash} current_scope={@current_scope} catalogue>
      <div
        id="catalogue"
        class="catalogue workbench"
        data-wb-theme={@theme}
        data-section={@section}
        data-node={
          case @section do
            "domain" -> @domain_id
            "model" -> @model_id
            _ -> @component_id
          end
        }
        phx-hook="WorkbenchAccessibility"
      >
        <a
          href="#catalogue-heading"
          class="wb-skip-link"
          phx-click={JS.focus(to: "#catalogue-heading")}
        >Skip to main content</a>
        <nav class="catalogue-rail" aria-label="Catalogue sections">
          <.link patch="/dev/catalogue" class="catalogue-brand">BEDROCK
          <small>Design catalogue</small></.link>
          <p class="catalogue-label">Library</p>
          <.link
            :for={section <- ~w(foundations controls compositions blueprints graph domain model)}
            patch={"/dev/catalogue/#{section}"}
            class={if @section == section, do: "active"}
            aria-current={if @section == section, do: "page"}
          >{String.capitalize(section)}</.link>
          <div class="catalogue-rail-note">
            Living Phoenix components<br />Synthetic data only<br />Refresh resets examples
          </div>
        </nav>
        <main class="catalogue-main">
          <header class="catalogue-top">
            <span>DESIGN SYSTEM / 01</span><.button
              id="theme-toggle"
              phx-click="theme"
              class="wb-button secondary"
            >{if @theme == "light", do: "Dark theme", else: "Light theme"}</.button>
          </header>
          <div class="catalogue-heading">
            <div>
              <p class="catalogue-label">Library / {@section}</p><h1
                id="catalogue-heading"
                tabindex="-1"
              >
                {String.capitalize(@section)}
              </h1>
            </div><Workbench.status label="In development" />
          </div>
          <.foundations :if={@section == "foundations"} count={@count} />
          <.controls
            :if={@section == "controls"}
            count={@count}
            form={@control_form}
            result={@control_result}
          />
          <.compositions
            :if={@section == "compositions"}
            enquiries={@enquiries}
            receipt={@receipt}
            form={@receipt_form}
            result={@result}
            scenario={@scenario}
            compact={@compact}
            query={@query}
            filter_form={@filter_form}
            stock_page={@stock_page}
            selected_part={@selected_part}
            stock_options={@stock_options}
            stock_sort={@stock_sort}
            stock_direction={@stock_direction}
            selected={@selected}
            field_done={@field_done}
            temporal={
              %{
                schedule_form: @schedule_form,
                appointments: @appointments,
                range_form: @range_form,
                date_range: @date_range,
                timestamp_form: @timestamp_form,
                timestamp_result: @timestamp_result,
                receipt: @receipt
              }
            }
          />
          <.model
            :if={@section == "model"}
            node={Model.get(@model_id)}
            nodes={Model.nodes()}
            story={@journey_story}
          />
          <.blueprints
            :for={blueprint <- Domain.blueprints()}
            :if={@section == "blueprints"}
            blueprint={blueprint}
          />
          <.domain
            :if={@section == "domain"}
            node={Domain.get(@domain_id)}
            nodes={Domain.nodes()}
            used_in={Domain.used_in(@domain_id)}
            bindings={Domain.for_concept(@domain_id)}
            part={@selected_part}
            receipt={@receipt}
          />
          <.graph
            :if={@section == "graph"}
            nodes={@nodes}
            bindings={Domain.for_component(@component_id)}
            domain_types={Enum.filter(Domain.nodes(), &(@component_id in &1["presentations"]))}
            selected_part={@selected_part}
            node={Components.get(@component_id)}
            used_in={Components.used_in(@component_id)}
            control_form={@control_form}
            control_result={@control_result}
            stock_options={@stock_options}
            count={@count}
            compact={@compact}
            query={@query}
            filter_form={@filter_form}
            stock_page={@stock_page}
            selected={@selected}
            stock_sort={@stock_sort}
            stock_direction={@stock_direction}
            receipt={@receipt}
            temporal={
              %{
                schedule_form: @schedule_form,
                appointments: @appointments,
                range_form: @range_form,
                date_range: @date_range,
                timestamp_form: @timestamp_form,
                timestamp_result: @timestamp_result,
                receipt: @receipt
              }
            }
            story={@journey_story}
          />
        </main>
      </div>
    </Layouts.app>
    """
  end
end
