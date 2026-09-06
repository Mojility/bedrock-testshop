defmodule Shop.Leads.Notifier do
  @moduledoc "Durable pending notifications. Delivery failures never lose accepted enquiries."
  use GenServer
  import Ecto.Query
  import Swoosh.Email, except: [from: 2]
  alias Shop.{Repo, Mailer}
  alias Shop.Leads.Lead
  alias Shop.Accounts.User

  def start_link(opts), do: GenServer.start_link(__MODULE__, opts, name: __MODULE__)

  def init(_) do
    if Application.get_env(:shop, :lead_notifications, true),
      do: Process.send_after(self(), :deliver, 30_000)

    {:ok, nil}
  end

  def handle_info(:deliver, state) do
    deliver_pending()
    Process.send_after(self(), :deliver, 30_000)
    {:noreply, state}
  end

  def deliver_pending(deliver \\ &Mailer.deliver/1) do
    Repo.transact(fn ->
      recipients =
        Repo.all(
          from u in User,
            where: u.role == "owner" and is_nil(u.disabled_at) and not is_nil(u.confirmed_at),
            select: u.email
        )

      if recipients != [] do
        leads =
          Repo.all(
            from l in Lead,
              where: is_nil(l.notified_at),
              order_by: l.inserted_at,
              limit: 20,
              lock: "FOR UPDATE SKIP LOCKED"
          )

        Enum.each(leads, fn lead ->
          email =
            new()
            |> Swoosh.Email.from(Mailer.from_address())
            |> to(recipients)
            |> subject("New enquiry for #{Shop.name()}")
            |> text_body(
              "A new enquiry is waiting in your business system. Sign in to read it and record your follow-up.\n\n#{ShopWeb.Endpoint.url()}/app/leads#leads-#{lead.id}"
            )

          case deliver.(email) do
            {:ok, _} ->
              lead |> Ecto.Changeset.change(notified_at: DateTime.utc_now()) |> Repo.update!()

            _ ->
              :retry_later
          end
        end)
      end

      {:ok, :checked}
    end)
  rescue
    _ -> {:error, :delivery_unavailable}
  end
end
