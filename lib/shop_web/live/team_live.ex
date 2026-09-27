defmodule ShopWeb.TeamLive do
  use ShopWeb, :live_view
  alias Shop.Accounts
  alias Shop.Accounts.Staff
  alias ShopWeb.Operations

  def mount(_, _, socket) do
    {:ok,
     socket
     |> assign(:page_title, "Team")
     |> assign(:form, to_form(%{}, as: :invite))
     |> stream(:users, Staff.list(socket.assigns.current_scope))}
  end

  def handle_event("invite", %{"invite" => %{"email" => email}}, socket) do
    case Staff.invite(socket.assigns.current_scope, email) do
      {:ok, user} ->
        result = Accounts.deliver_login_instructions(user, &url(~p"/users/log-in/#{&1}"))

        message =
          if match?({:ok, _}, result),
            do: "Invitation sent.",
            else:
              "Access created, but the email could not be sent. They can request a login link."

        {:noreply, socket |> stream_insert(:users, user) |> put_flash(:info, message)}

      {:error, changeset} ->
        {:noreply, assign(socket, :form, to_form(changeset, as: :invite))}
    end
  end

  def handle_event("revoke", %{"id" => id}, socket) do
    case Staff.revoke(socket.assigns.current_scope, id) do
      {:ok, {user, tokens}} ->
        ShopWeb.UserAuth.disconnect_sessions(tokens)
        {:noreply, socket |> stream_insert(:users, user) |> put_flash(:info, "Access revoked.")}

      {:error, _} ->
        {:noreply, put_flash(socket, :error, "The owner's access cannot be revoked here.")}
    end
  end

  def render(assigns) do
    ~H"""
    <Layouts.app flash={@flash} current_scope={@current_scope} current_section="team">
      <Operations.page
        id="team"
        title="Your team"
        description="Manage who can receive and follow up on enquiries."
      >
        <Operations.panel
          id="invite-staff"
          title="Invite a staff member"
          description="They will receive a link to sign in. Only owners can manage access."
        >
          <.form for={@form} id="invite-form" phx-submit="invite">
            <.input field={@form[:email]} type="email" label="Staff email" required />
            <Operations.form_actions>
              <.button variant="primary" phx-disable-with="Inviting…">Invite staff member</.button>
            </Operations.form_actions>
          </.form>
        </Operations.panel>
        <Operations.panel id="staff-access" title="Staff access">
          <ul id="team-list" phx-update="stream" class="flex flex-col gap-4">
            <li
              :for={{id, user} <- @streams.users}
              id={id}
              class="flex flex-wrap items-center justify-between gap-4 border-b border-base-300 pb-4"
            >
              <div>
                <p class="font-semibold">{user.email}</p>
                <Operations.status
                  label={
                    if user.disabled_at, do: "Access revoked", else: String.capitalize(user.role)
                  }
                  tone={if user.disabled_at, do: "warning", else: "neutral"}
                />
              </div>
              <.button
                :if={user.role != "owner" && is_nil(user.disabled_at)}
                variant="danger"
                phx-click="revoke"
                phx-value-id={user.id}
                data-confirm="Revoke this person's access?"
              >
                Revoke access
              </.button>
            </li>
          </ul>
        </Operations.panel>
      </Operations.page>
    </Layouts.app>
    """
  end
end
