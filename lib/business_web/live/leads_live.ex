defmodule BusinessWeb.LeadsLive do
  use BusinessWeb, :live_view
  alias Business.Leads
  alias BusinessWeb.Operations

  def mount(_, _, socket) do
    scope = socket.assigns.current_scope
    if connected?(socket), do: Leads.subscribe(scope)
    {:ok, socket |> assign(:page_title, "Leads") |> stream(:leads, Leads.list(scope))}
  end

  def handle_info(:leads_updated, socket) do
    {:noreply, stream(socket, :leads, Leads.list(socket.assigns.current_scope), reset: true)}
  end

  def handle_event("save", %{"id" => id, "lead" => attrs}, socket) do
    case Leads.follow_up(socket.assigns.current_scope, id, attrs) do
      {:ok, lead} ->
        {:noreply, socket |> stream_insert(:leads, lead) |> put_flash(:info, "Follow-up saved.")}

      {:error, _} ->
        {:noreply,
         put_flash(socket, :error, "Choose a status and keep notes under 4,000 characters.")}
    end
  end

  def render(assigns) do
    ~H"""
    <Layouts.app flash={@flash} current_scope={@current_scope} current_section="leads">
      <Operations.page
        id="leads"
        title="Leads"
        description="Customer enquiries from the website, phone and email, with the details your team needs to follow up."
      >
        <p class="text-sm text-base-content/80">Showing the latest 200 enquiries.</p>
        <ol id="leads-list" phx-update="stream" class="flex flex-col gap-6">
          <li id="leads-empty" class="hidden only:block">
            <Operations.empty_state
              title="No enquiries yet"
              description="Messages from your website will appear here."
            />
          </li>
          <li
            :for={{id, lead} <- @streams.leads}
            id={id}
          >
            <Operations.panel id={"lead-card-#{lead.id}"} title={lead.name}>
              <:actions><Operations.status label={String.capitalize(lead.status)} /></:actions>
              <div class="grid gap-6 lg:grid-cols-2">
                <div class="flex min-w-0 flex-col gap-4">
                  <Operations.facts>
                    <:item label="Received">
                      <time
                        class="text-sm text-base-content/70"
                        datetime={DateTime.to_iso8601(lead.inserted_at)}
                      >
                        {Calendar.strftime(lead.inserted_at, "%b %-d, %Y · %H:%M UTC")}
                      </time>
                    </:item>
                    <:item :if={lead.location} label="Location">{lead.location}</:item>
                    <:item :if={lead.requested_date} label="Requested date">
                      <time datetime={Date.to_iso8601(lead.requested_date)}>
                        {Calendar.strftime(lead.requested_date, "%A, %b %-d, %Y")}
                      </time>
                    </:item>
                    <:item label="Source">{String.capitalize(lead.source)}</:item>
                  </Operations.facts>
                  <div class="flex flex-wrap gap-4">
                    <.link
                      :if={lead.phone}
                      href={"tel:#{lead.phone}"}
                      class="link inline-flex min-h-11 items-center gap-2"
                    >
                      <.icon name="hero-phone" class="size-5" />{lead.phone}
                    </.link>
                    <.link
                      :if={lead.email}
                      href={"mailto:#{lead.email}"}
                      class="link inline-flex min-h-11 items-center gap-2"
                    >
                      <.icon name="hero-envelope" class="size-5" />{lead.email}
                    </.link>
                  </div>
                  <p class="whitespace-pre-line">{lead.message}</p>
                </div>
                <.form
                  for={to_form(%{"status" => lead.status, "notes" => lead.notes}, as: :lead)}
                  id={"follow-up-#{lead.id}"}
                  phx-submit="save"
                  phx-value-id={lead.id}
                >
                  <.input
                    name="lead[status]"
                    value={lead.status}
                    type="select"
                    label="Status"
                    options={[
                      {"New", "new"},
                      {"Contacted", "contacted"},
                      {"Closed", "closed"},
                      {"Waiting", "waiting"},
                      {"Booked", "booked"},
                      {"Declined", "declined"}
                    ]}
                  />
                  <.input
                    name="lead[notes]"
                    value={lead.notes}
                    type="textarea"
                    label="Follow-up notes"
                    maxlength="4000"
                  />
                  <Operations.form_actions>
                    <.button phx-disable-with="Saving…" variant="primary">Save follow-up</.button>
                  </Operations.form_actions>
                </.form>
              </div>
            </Operations.panel>
          </li>
        </ol>
      </Operations.page>
    </Layouts.app>
    """
  end
end
