defmodule Shop.Leads.RateLimiter do
  @moduledoc """
  A crude brake on the lead form: at most #{10} submissions from one
  address in any clock hour. Counts live in an ETS table this process owns,
  keyed by address and hour, so they are per node and gone on restart. That
  is deliberate: the form is public and unauthenticated, this stops a
  script from filling an owner's inbox, and anything more careful (a shared
  store, a sliding window) can wait until it is needed.

  Buckets from past hours are swept once an hour so the table does not
  grow without bound.
  """
  use GenServer

  @table __MODULE__
  @limit 10
  @sweep_every :timer.hours(1)

  @doc "The number of submissions one address may make in an hour."
  def limit, do: @limit

  def start_link(opts) do
    GenServer.start_link(__MODULE__, opts, name: Keyword.get(opts, :name, __MODULE__))
  end

  @doc """
  Counts one submission from `address` and says whether it is within the
  limit. Every call counts, accepted or not, so a script that keeps trying
  stays refused.
  """
  @spec allow?(term()) :: boolean()
  def allow?(address) do
    :ets.update_counter(@table, {address, current_hour()}, {2, 1}, {{address, current_hour()}, 0}) <=
      @limit
  end

  @impl true
  def init(_opts) do
    :ets.new(@table, [:named_table, :public, :set, write_concurrency: true])
    schedule_sweep()
    {:ok, %{}}
  end

  @impl true
  def handle_info(:sweep, state) do
    hour = current_hour()
    :ets.select_delete(@table, [{{{:_, :"$1"}, :_}, [{:<, :"$1", hour}], [true]}])
    schedule_sweep()
    {:noreply, state}
  end

  defp schedule_sweep, do: Process.send_after(self(), :sweep, @sweep_every)

  defp current_hour, do: div(System.system_time(:second), 3600)
end
