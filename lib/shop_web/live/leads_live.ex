defmodule ShopWeb.LeadsLive do
  use ShopWeb, :live_view
  alias Shop.Leads
  alias ShopWeb.Operations

  def mount(_, _, socket) do
    scope = socket.assigns.current_scope
    if connected?(socket), do: Leads.subscribe(scope)
    {:ok, load(socket, false)}
  end

  def handle_info(:leads_updated, socket), do: {:noreply, load(socket, socket.assigns.trash?)}

  def handle_event("show_pipeline", _, socket), do: {:noreply, load(socket, false)}
  def handle_event("show_trash", _, socket), do: {:noreply, load(socket, true)}

  def handle_event("save", %{"id" => id, "lead" => attrs}, socket) do
    case Leads.follow_up(socket.assigns.current_scope, id, attrs) do
      {:ok, _lead} ->
        {:noreply,
         socket
         |> load(false)
         |> put_flash(:info, "Pipeline activity saved.")}

      {:error, _reason} ->
        {:noreply,
         put_flash(
           socket,
           :error,
           "Choose a valid survey date and enter the required site address."
         )}
    end
  end

  def handle_event("trash", %{"id" => id}, socket) do
    case Leads.trash(socket.assigns.current_scope, id) do
      {:ok, _} ->
        {:noreply, socket |> load(false) |> put_flash(:info, "Junk submission moved to trash.")}

      _ ->
        {:noreply, put_flash(socket, :error, "Could not move this submission to trash.")}
    end
  end

  def handle_event("restore", %{"id" => id}, socket) do
    case Leads.restore(socket.assigns.current_scope, id) do
      {:ok, _} ->
        {:noreply, socket |> load(true) |> put_flash(:info, "Submission restored.")}

      _ ->
        {:noreply,
         put_flash(socket, :error, "Only an office manager or owner can restore submissions.")}
    end
  end

  def handle_event("empty_trash", _, socket) do
    {:ok, count} = Leads.empty_trash(socket.assigns.current_scope)

    {:noreply,
     socket
     |> load(true)
     |> put_flash(:info, "Permanently deleted #{count} junk submission(s).")}
  end

  def render(assigns) do
    ~H"""
    <Layouts.app flash={@flash} current_scope={@current_scope} current_section="leads">
      <Operations.page
        id="leads"
        title="Sales pipeline"
        description="Every genuine website enquiry, from response through closed job."
      >
        <:actions>
          <div class="join">
            <button id="show-pipeline" class="btn join-item" phx-click="show_pipeline">Pipeline</button><button
              id="show-trash"
              class="btn join-item"
              phx-click="show_trash"
            >Trash</button>
          </div>
        </:actions>

        <dl :if={!@trash?} id="pipeline-stats" class="grid grid-cols-2 gap-3 sm:grid-cols-6">
          <.stat label="Website leads" value={@stats.leads} /><.stat
            label="Conversations"
            value={@stats.conversations}
          /><.stat label="Surveys" value={@stats.surveys} /><.stat
            label="Quotes"
            value={@stats.quotes}
          /><.stat label="Closed jobs" value={@stats.closed_jobs} /><.stat
            label="Awaiting response"
            value={@stats.awaiting_response}
            urgent={@stats.awaiting_response > 0}
          />
        </dl>
        <div
          :if={!@trash? && @stats.awaiting_response > 0}
          id="response-alert"
          role="status"
          class="alert alert-warning"
        >
          <.icon name="hero-exclamation-triangle" class="size-5" /><span>{@stats.awaiting_response} genuine inquiry(s) still need a response.</span>
        </div>

        <div :if={@trash?} class="flex items-center justify-between">
          <p>Junk submissions are excluded from pipeline statistics and response tracking.</p><button
            :if={@manager?}
            id="empty-trash"
            class="btn btn-error"
            phx-click="empty_trash"
            data-confirm="Permanently delete every trashed submission? This cannot be undone."
          >Empty trash</button>
        </div>

        <div class="overflow-x-auto">
          <table id="leads-table" class="table">
            <caption class="sr-only">
              {if @trash?, do: "Trashed submissions", else: "Active sales leads"}
            </caption><thead>
              <tr>
                <th scope="col">Prospect</th><th scope="col">Received</th><th scope="col">State</th><th scope="col">
                  Contact
                </th><th scope="col">Actions</th>
              </tr>
            </thead><tbody id="leads-list" phx-update="stream">
              <tr id="leads-empty" class="hidden only:table-row">
                <td colspan="5">{if @trash?, do: "Trash is empty.", else: "No active enquiries."}</td>
              </tr><tr :for={{id, lead} <- @streams.leads} id={id}>
                <th scope="row">
                  <.link navigate={~p"/app/leads/#{lead.id}"} class="link">{lead.name}</.link>
                </th><td>
                  <time datetime={DateTime.to_iso8601(lead.inserted_at)}>{Calendar.strftime(
                    lead.inserted_at,
                    "%b %-d, %Y"
                  )}</time>
                </td><td>
                  <span class={["badge badge-outline", lead.status == "new" && "badge-warning"]}>{state_indicator(
                    lead
                  )}</span>
                </td><td>{lead.email || lead.phone}</td><td>
                  <.form
                    :if={!@trash?}
                    for={
                      to_form(
                        %{
                          "status" => "survey",
                          "notes" => "Survey booked",
                          "survey_date" => "",
                          "survey_address" => ""
                        },
                        as: :lead
                      )
                    }
                    id={"follow-up-#{lead.id}"}
                    phx-submit="save"
                    phx-value-id={lead.id}
                    class="flex min-w-72 flex-col gap-2"
                  >
                    <input type="hidden" name="lead[status]" value="survey" />
                    <input type="hidden" name="lead[notes]" value="Survey booked" />
                    <label class="form-control">
                      <span class="label-text">Site survey date</span>
                      <input
                        id={"survey-date-#{lead.id}"}
                        class="input input-bordered input-sm"
                        type="date"
                        name="lead[survey_date]"
                        required
                      />
                    </label>
                    <label class="form-control">
                      <span class="label-text">Site address</span>
                      <input
                        id={"survey-address-#{lead.id}"}
                        class="input input-bordered input-sm"
                        type="text"
                        name="lead[survey_address]"
                        maxlength="500"
                        required
                      />
                    </label>
                    <button class="btn btn-sm" type="submit">Book survey</button>
                  </.form><button
                    :if={!@trash?}
                    id={"trash-#{lead.id}"}
                    class="btn btn-sm"
                    phx-click="trash"
                    phx-value-id={lead.id}
                  >Move junk to trash</button><button
                    :if={@trash? && @manager?}
                    id={"restore-#{lead.id}"}
                    class="btn btn-sm"
                    phx-click="restore"
                    phx-value-id={lead.id}
                  >Restore</button>
                </td>
              </tr>
            </tbody>
          </table>
        </div>
      </Operations.page>
    </Layouts.app>
    """
  end

  defp load(socket, trash?) do
    scope = socket.assigns.current_scope

    socket
    |> assign(
      page_title: "Sales pipeline",
      stats: Leads.stats(scope),
      trash?: trash?,
      manager?: scope.user.role in ["owner", "office_manager"]
    )
    |> stream(:leads, Leads.list(scope, trash?), reset: true)
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

  defp state_indicator(%{status: "new"}), do: "New"
  defp state_indicator(%{status: "survey"}), do: "Site survey"
  defp state_indicator(%{status: "lost"}), do: "Dismissed — not an opportunity"

  defp state_indicator(%{responded_at: %DateTime{} = at}),
    do: "Responded #{Calendar.strftime(at, "%b %-d, %Y")}"

  defp state_indicator(lead), do: String.capitalize(lead.status)
end
