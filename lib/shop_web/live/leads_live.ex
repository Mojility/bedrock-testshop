defmodule ShopWeb.LeadsLive do
  use ShopWeb, :live_view
  alias Shop.Leads

  def mount(_, _, socket) do
    scope = socket.assigns.current_scope
    if connected?(socket), do: Leads.subscribe(scope)

    {:ok,
     socket
     |> assign(:page_title, "Sales pipeline")
     |> assign(:stats, Leads.stats(scope))
     |> stream(:leads, Leads.list(scope))}
  end

  def handle_info(:leads_updated, socket) do
    scope = socket.assigns.current_scope

    {:noreply,
     socket
     |> assign(:stats, Leads.stats(scope))
     |> stream(:leads, Leads.list(scope), reset: true)}
  end

  def handle_event("save", %{"id" => id, "lead" => attrs}, socket) do
    case Leads.follow_up(socket.assigns.current_scope, id, attrs) do
      {:ok, lead} ->
        {:noreply,
         socket
         |> assign(:stats, Leads.stats(socket.assigns.current_scope))
         |> stream_insert(:leads, lead)
         |> put_flash(:info, "Pipeline stage and follow-up saved.")}

      {:error, _} ->
        {:noreply,
         put_flash(
           socket,
           :error,
           "Choose a pipeline stage and keep notes under 4,000 characters."
         )}
    end
  end

  def render(assigns) do
    ~H"""
    <Layouts.app flash={@flash} current_scope={@current_scope}>
      <section id="leads" class="space-y-8">
        <div>
          <h1 class="text-3xl font-bold">Sales pipeline</h1>
          <p class="mt-2 text-base-content/70">
            Track every website enquiry from first response through survey, quote, and closed job.
          </p>
        </div>

        <dl id="pipeline-stats" class="grid grid-cols-2 gap-3 sm:grid-cols-5">
          <.stat label="Website leads" value={@stats.leads} />
          <.stat
            label="Awaiting response"
            value={@stats.awaiting_response}
            urgent={@stats.awaiting_response > 0}
          />
          <.stat label="Surveys" value={@stats.surveys} />
          <.stat label="Quotes" value={@stats.quotes} />
          <.stat label="Closed jobs" value={@stats.closed_jobs} />
        </dl>

        <div
          :if={@stats.awaiting_response > 0}
          id="response-alert"
          role="status"
          class="alert alert-warning"
        >
          <.icon name="hero-exclamation-triangle" class="size-5" />
          <span>{@stats.awaiting_response} lead(s) still need a response.</span>
        </div>

        <p class="text-sm text-base-content/70">Showing the latest 200 enquiries.</p>
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
              <span class={["badge badge-outline", lead.status == "new" && "badge-warning"]}>
                {stage_label(lead.status)}
              </span>
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
                label="Pipeline stage"
                options={stage_options()}
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

  attr :label, :string, required: true
  attr :value, :integer, required: true
  attr :urgent, :boolean, default: false

  defp stat(assigns) do
    ~H"""
    <div class={[
      "rounded-box border p-4",
      if(@urgent, do: "border-warning bg-warning/10", else: "border-base-300")
    ]}>
      <dt class="text-sm text-base-content/70">{@label}</dt>
      <dd class="text-2xl font-bold">{@value}</dd>
    </div>
    """
  end

  defp stage_options do
    [
      {"Needs response", "new"},
      {"Conversation", "conversation"},
      {"Site survey", "survey"},
      {"Quote", "quote"},
      {"Closed job", "job_closed"},
      {"Lost / not proceeding", "lost"}
    ]
  end

  defp stage_label(status),
    do:
      stage_options()
      |> Enum.find_value(status, fn {label, value} -> if value == status, do: label end)
end
