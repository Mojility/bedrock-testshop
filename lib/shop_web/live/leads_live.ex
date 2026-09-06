defmodule ShopWeb.LeadsLive do
  use ShopWeb, :live_view
  alias Shop.Leads

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
    <Layouts.app flash={@flash} current_scope={@current_scope}>
      <section id="leads" class="space-y-8">
        <div>
          <h1 class="text-3xl font-bold">Leads</h1>
          <p class="mt-2 text-base-content/70">
            Enquiries from your website. Contact the customer and keep your team up to date.
          </p>
          <p class="text-sm text-base-content/70">Showing the latest 200 enquiries.</p>
        </div>
        <ol id="leads-list" phx-update="stream" class="space-y-6">
          <li id="leads-empty" class="hidden only:block rounded-box bg-base-200 p-6">
            No enquiries yet. Messages from your website will appear here.
          </li>
          <li
            :for={{id, lead} <- @streams.leads}
            id={id}
            class="rounded-box border border-base-300 p-6 space-y-4"
          >
            <div class="flex flex-wrap justify-between gap-3">
              <h2 class="text-xl font-semibold">{lead.name}</h2>
              <span class="badge badge-outline">{lead.status}</span>
            </div>
            <time
              class="text-sm text-base-content/70"
              datetime={DateTime.to_iso8601(lead.inserted_at)}
            >
              {Calendar.strftime(lead.inserted_at, "%b %-d, %Y · %H:%M UTC")}
            </time>
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
                options={[{"New", "new"}, {"Contacted", "contacted"}, {"Closed", "closed"}]}
              />
              <.input
                name="lead[notes]"
                value={lead.notes}
                type="textarea"
                label="Follow-up notes"
                maxlength="4000"
              />
              <.button phx-disable-with="Saving…" variant="primary">Save follow-up</.button>
            </.form>
          </li>
        </ol>
      </section>
    </Layouts.app>
    """
  end
end
