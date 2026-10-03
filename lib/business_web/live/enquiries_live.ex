defmodule BusinessWeb.EnquiriesLive do
  use BusinessWeb, :live_view

  alias Business.Enquiries
  alias Business.Leads.Lead
  alias BusinessWeb.Operations

  def mount(_params, _session, socket) do
    if connected?(socket), do: Enquiries.subscribe(socket.assigns.current_scope)
    week_start = monday(Date.utc_today())
    {:ok, load(socket, week_start, Enquiries.change(%Lead{}))}
  end

  def handle_event("save", %{"lead" => attrs}, socket) do
    case Enquiries.create(socket.assigns.current_scope, attrs) do
      {:ok, _} ->
        {:noreply,
         socket
         |> load(socket.assigns.week_start, Enquiries.change(%Lead{}))
         |> put_flash(:info, "Lead recorded.")}

      {:error, %Ecto.Changeset{} = changeset} ->
        {:noreply, assign(socket, :form, to_form(Map.put(changeset, :action, :insert)))}

      {:error, _} ->
        {:noreply, put_flash(socket, :error, "The lead could not be recorded.")}
    end
  end

  def handle_event("status", %{"id" => id, "lead" => attrs}, socket) do
    case Enquiries.update_status(socket.assigns.current_scope, id, attrs) do
      {:ok, _} ->
        {:noreply, socket |> reload() |> put_flash(:info, "Status updated.")}

      {:error, :stale} ->
        {:noreply,
         socket
         |> reload()
         |> put_flash(:error, "Someone else updated this lead. Review it and try again.")}

      {:error, _} ->
        {:noreply, put_flash(socket, :error, "Choose a valid status.")}
    end
  end

  def handle_event("week", %{"direction" => direction}, socket) do
    days = if direction == "previous", do: -7, else: 7
    {:noreply, load(socket, Date.add(socket.assigns.week_start, days), Enquiries.change(%Lead{}))}
  end

  def handle_info(:leads_updated, socket), do: {:noreply, reload(socket)}

  defp reload(socket), do: load(socket, socket.assigns.week_start, Enquiries.change(%Lead{}))

  defp load(socket, week_start, changeset) do
    leads = Enquiries.list_week(socket.assigns.current_scope, week_start)

    socket
    |> assign(:page_title, "Job leads")
    |> assign(:week_start, week_start)
    |> assign(:week_end, Date.add(week_start, 6))
    |> assign(:form, to_form(changeset))
    |> assign(:empty?, leads == [])
    |> stream(:leads, leads, reset: true)
  end

  defp monday(date), do: Date.add(date, 1 - Date.day_of_week(date))

  def render(assigns) do
    ~H"""
    <Layouts.app flash={@flash} current_scope={@current_scope} current_section="enquiries">
      <Operations.page
        id="job-leads"
        title="Job leads"
        description="Record customer requests and see this week's workload at a glance."
      >
        <div class="grid gap-8 xl:grid-cols-[minmax(20rem,26rem)_1fr]">
          <Operations.panel
            id="new-lead"
            title="Record a lead"
            description="All fields are required."
          >
            <.form for={@form} id="lead-form" phx-submit="save">
              <.input field={@form[:name]} label="Customer name" required />
              <.input field={@form[:message]} type="textarea" label="What they need" required />
              <.input field={@form[:location]} label="Location" required />
              <.input field={@form[:requested_date]} type="date" label="Requested date" required />
              <.input
                field={@form[:source]}
                type="select"
                label="How they contacted us"
                prompt="Choose one"
                options={[{"Phone", "phone"}, {"Email", "email"}]}
                required
              />
              <.input
                field={@form[:status]}
                type="select"
                label="Status"
                options={[{"Waiting", "waiting"}, {"Booked", "booked"}, {"Declined", "declined"}]}
                required
              />
              <Operations.form_actions>
                <.button variant="primary" phx-disable-with="Recording…">Record lead</.button>
              </Operations.form_actions>
            </.form>
          </Operations.panel>

          <Operations.panel
            id="week-view"
            title="Week view"
            description={Calendar.strftime(@week_start, "%b %-d") <> "–" <> Calendar.strftime(@week_end, "%b %-d, %Y")}
          >
            <:actions>
              <button
                id="previous-week"
                type="button"
                phx-click="week"
                phx-value-direction="previous"
                class="btn btn-ghost"
              >Previous</button>
              <button
                id="next-week"
                type="button"
                phx-click="week"
                phx-value-direction="next"
                class="btn btn-ghost"
              >Next</button>
            </:actions>
            <Operations.empty_state
              :if={@empty?}
              title="No leads this week"
              description="Use the form to record the first request."
            />
            <ol id="week-leads" phx-update="stream" class="flex flex-col gap-4">
              <li
                :for={{id, lead} <- @streams.leads}
                id={id}
                class="rounded-box border border-base-300 p-4"
              >
                <div class="flex flex-wrap items-start justify-between gap-3">
                  <div>
                    <h3 class="font-semibold">{lead.name}</h3>
                    <p>
                      <time datetime={Date.to_iso8601(lead.requested_date)}>{Calendar.strftime(
                        lead.requested_date,
                        "%A, %b %-d"
                      )}</time>
                      · {lead.location}
                    </p>
                    <p class="mt-2 whitespace-pre-line">{lead.message}</p>
                    <p class="mt-2 text-sm text-base-content/70">Received by {lead.source}</p>
                  </div>
                  <Operations.status label={String.capitalize(lead.status)} />
                </div>
                <.form
                  for={
                    to_form(%{"status" => lead.status, "lock_version" => lead.lock_version},
                      as: :lead
                    )
                  }
                  id={"status-#{lead.id}"}
                  phx-submit="status"
                  phx-value-id={lead.id}
                  class="mt-4 flex flex-wrap items-end gap-3"
                >
                  <input type="hidden" name="lead[lock_version]" value={lead.lock_version} />
                  <.input
                    name="lead[status]"
                    value={lead.status}
                    type="select"
                    label="Update status"
                    options={[{"Waiting", "waiting"}, {"Booked", "booked"}, {"Declined", "declined"}]}
                  />
                  <.button phx-disable-with="Saving…">Save status</.button>
                </.form>
              </li>
            </ol>
          </Operations.panel>
        </div>
      </Operations.page>
    </Layouts.app>
    """
  end
end
