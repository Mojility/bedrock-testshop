defmodule ShopWeb.LeadDetailLive do
  use ShopWeb, :live_view

  alias Shop.Leads

  def mount(%{"id" => id}, _, socket) do
    {:ok, load(socket, id)}
  end

  def handle_event("follow_up", %{"lead" => attrs}, socket) do
    case Leads.follow_up(socket.assigns.current_scope, socket.assigns.lead.id, attrs) do
      {:ok, _lead} ->
        {:noreply,
         socket
         |> load(socket.assigns.lead.id)
         |> put_flash(:info, follow_up_message(attrs))}

      {:error, _reason} ->
        {:noreply,
         socket
         |> assign(:follow_up_form, to_form(attrs, as: :lead))
         |> put_flash(
           :error,
           "Add follow-up notes, a valid survey date, and the required site address."
         )}
    end
  end

  def handle_event("dismiss", %{"lead" => attrs}, socket) do
    case Leads.dismiss(socket.assigns.current_scope, socket.assigns.lead.id, attrs["notes"]) do
      {:ok, _lead} ->
        {:noreply,
         socket
         |> load(socket.assigns.lead.id)
         |> put_flash(:info, "Dismissed — not an opportunity.")}

      {:error, _reason} ->
        {:noreply, put_flash(socket, :error, "Could not dismiss this lead.")}
    end
  end

  def render(assigns) do
    ~H"""
    <Layouts.app flash={@flash} current_scope={@current_scope}>
      <section id="lead-detail" class="space-y-8">
        <header>
          <.link navigate={~p"/app/leads"} class="link">← Sales pipeline</.link>
          <div class="mt-4 flex flex-wrap items-center justify-between gap-3">
            <h1 class="text-3xl font-bold">{@lead.name}</h1>
            <span id="lead-state" class="badge badge-outline">{stage_label(@lead.status)}</span>
          </div>
          <p class="mt-2 text-base-content/70">{@lead.email || @lead.phone}</p>
        </header>

        <section aria-labelledby="enquiry-heading" class="rounded-box border border-base-300 p-6">
          <h2 id="enquiry-heading" class="text-xl font-semibold">Enquiry</h2>
          <p class="mt-3 whitespace-pre-line">{@lead.message}</p>
        </section>

        <div
          :if={@lead.status not in ["lost", "quote", "job_closed"]}
          class="grid gap-6 md:grid-cols-2"
        >
          <.form
            for={@follow_up_form}
            id="follow-up-form"
            phx-submit="follow_up"
            class="space-y-4 rounded-box border border-base-300 p-6"
          >
            <h2 class="text-xl font-semibold">Record follow-up</h2>
            <p class="text-sm text-base-content/70">
              Saving notes records a conversation. To book a site survey at the same time, enter both its date and site address.
            </p>
            <.input
              field={@follow_up_form[:notes]}
              id="follow-up-notes"
              type="textarea"
              label="Follow-up notes"
              maxlength="4000"
              required
            />
            <.input
              field={@follow_up_form[:survey_date]}
              id="survey-date"
              type="date"
              label="Site survey date (optional)"
            />
            <.input
              field={@follow_up_form[:survey_address]}
              id="survey-address"
              type="text"
              label="Site address (required when booking a survey)"
              maxlength="500"
            />
            <.button variant="primary" phx-disable-with="Saving…">Save follow-up</.button>
          </.form>

          <.form
            for={@dismiss_form}
            id="dismiss-form"
            phx-submit="dismiss"
            class="space-y-4 rounded-box border border-base-300 p-6"
          >
            <h2 class="text-xl font-semibold">Not an opportunity?</h2>
            <p class="text-sm text-base-content/70">
              Dismiss this contacted lead so it no longer appears as an active opportunity.
            </p>
            <.input
              field={@dismiss_form[:notes]}
              id="dismiss-notes"
              type="textarea"
              label="Reason (optional)"
              maxlength="4000"
            />
            <.button phx-disable-with="Dismissing…">Dismiss — not an opportunity</.button>
          </.form>
        </div>

        <section aria-labelledby="activity-heading">
          <h2 id="activity-heading" class="text-xl font-semibold">Contact activity</h2>
          <ol id="activity-history" class="mt-3 space-y-3">
            <li :if={@lead.activities == []} class="rounded-box bg-base-200 p-4">
              No follow-up recorded yet.
            </li>
            <li
              :for={activity <- @lead.activities}
              id={"activity-#{activity.id}"}
              class="rounded-box border border-base-300 p-4"
            >
              <strong>{activity.user.email}</strong>
              changed {stage_label(activity.from_status)} to {stage_label(activity.to_status)}
              <time
                class="block text-sm text-base-content/70"
                datetime={DateTime.to_iso8601(activity.inserted_at)}
              >{Calendar.strftime(activity.inserted_at, "%b %-d, %Y · %H:%M UTC")}</time>
              <p :if={activity.reason} class="mt-2 whitespace-pre-line">{activity.reason}</p>
            </li>
          </ol>
        </section>

        <section aria-labelledby="contact-history-heading">
          <h2 id="contact-history-heading" class="text-xl font-semibold">
            Earlier enquiries from this contact
          </h2>
          <ol id="contact-history" class="mt-3 space-y-3">
            <li :if={@history == []} class="rounded-box bg-base-200 p-4">
              No earlier enquiries match this phone number or email.
            </li>
            <li
              :for={earlier <- @history}
              id={"contact-history-#{earlier.id}"}
              class="rounded-box border border-base-300 p-4"
            >
              <.link navigate={~p"/app/leads/#{earlier.id}"} class="link font-semibold">{Calendar.strftime(
                earlier.inserted_at,
                "%b %-d, %Y"
              )}</.link>
              <p class="mt-2 line-clamp-3">{earlier.message}</p>
            </li>
          </ol>
        </section>
      </section>
    </Layouts.app>
    """
  end

  defp load(socket, id) do
    {lead, history} = Leads.get!(socket.assigns.current_scope, id)

    assign(socket,
      page_title: lead.name,
      lead: lead,
      history: history,
      follow_up_form:
        to_form(%{"notes" => "", "survey_date" => "", "survey_address" => ""}, as: :lead),
      dismiss_form: to_form(%{"notes" => ""}, as: :lead)
    )
  end

  defp follow_up_message(%{"survey_date" => date}) when date not in [nil, ""],
    do: "Follow-up saved and site survey booked."

  defp follow_up_message(_attrs), do: "Follow-up saved; lead advanced to Conversation."

  defp stage_label("new"), do: "New"
  defp stage_label("conversation"), do: "Conversation"
  defp stage_label("survey"), do: "Site survey"
  defp stage_label("quote"), do: "Quote"
  defp stage_label("job_closed"), do: "Closed job"
  defp stage_label("lost"), do: "Dismissed — not an opportunity"
  defp stage_label(status), do: String.capitalize(status)
end
