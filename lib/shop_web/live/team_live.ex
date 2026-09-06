defmodule ShopWeb.TeamLive do
  use ShopWeb, :live_view
  alias Shop.Accounts
  alias Shop.Accounts.Staff

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
    <Layouts.app flash={@flash} current_scope={@current_scope}>
      <section id="team" class="space-y-8">
        <div>
          <h1 class="text-3xl font-bold">Your team</h1>
          <p class="mt-2">Invite people who should receive and follow up on enquiries.</p>
        </div>
        <.form for={@form} id="invite-form" phx-submit="invite">
          <.input field={@form[:email]} type="email" label="Staff email" required />
          <.button variant="primary" phx-disable-with="Inviting…">Invite staff member</.button>
        </.form>
        <ul id="team-list" phx-update="stream" class="space-y-4">
          <li
            :for={{id, user} <- @streams.users}
            id={id}
            class="flex flex-wrap items-center justify-between gap-4 border-b border-base-300 pb-4"
          >
            <div>
              <p class="font-semibold">{user.email}</p>
              <p>{if user.disabled_at, do: "Access revoked", else: user.role}</p>
            </div>
            <.button
              :if={user.role != "owner" && is_nil(user.disabled_at)}
              phx-click="revoke"
              phx-value-id={user.id}
              data-confirm="Revoke this person's access?"
            >
              Revoke access
            </.button>
          </li>
        </ul>
      </section>
    </Layouts.app>
    """
  end
end
