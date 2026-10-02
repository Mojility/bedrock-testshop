defmodule Business.Catalogue.Temporal do
  @moduledoc "Calendar values, zoned instants and scheduling rules for synthetic catalogue examples."
  import Ecto.Changeset

  @zones ~w(America/Toronto America/Vancouver America/Edmonton America/Winnipeg America/Halifax America/St_Johns Etc/UTC)
  def zones, do: @zones

  def schedule_defaults,
    do: %{
      "starts_at" => "2026-09-28T09:00",
      "ends_at" => "2026-09-28T11:00",
      "zone" => "America/Toronto"
    }

  def range_defaults, do: %{"from" => "2026-09-01", "to" => "2026-09-30"}
  def receipt_defaults, do: %{"occurred_at" => "2026-09-26T09:30", "zone" => "America/Toronto"}

  def date_range_form(params) do
    {%{}, %{from: :date, to: :date}}
    |> cast(params, [:from, :to])
    |> validate_required([:from, :to])
    |> validate_date_order()
  end

  defp validate_date_order(changeset) do
    case {get_field(changeset, :from), get_field(changeset, :to)} do
      {%Date{} = first, %Date{} = last} ->
        if Date.compare(first, last) == :gt,
          do: add_error(changeset, :to, "must be on or after the first date"),
          else: changeset

      _ ->
        changeset
    end
  end

  def timestamp_form(params) do
    {%{}, %{occurred_at: :naive_datetime, zone: :string}}
    |> cast(params, [:occurred_at, :zone])
    |> validate_required([:occurred_at, :zone])
    |> validate_inclusion(:zone, @zones)
    |> validate_instant(:occurred_at)
  end

  def schedule_form(params) do
    {%{}, %{starts_at: :naive_datetime, ends_at: :naive_datetime, zone: :string}}
    |> cast(params, [:starts_at, :ends_at, :zone])
    |> validate_required([:starts_at, :ends_at, :zone])
    |> validate_inclusion(:zone, @zones)
    |> validate_instant(:starts_at)
    |> validate_instant(:ends_at)
    |> validate_time_order()
  end

  def validate_instant(changeset, field) do
    case {get_field(changeset, field), get_field(changeset, :zone)} do
      {%NaiveDateTime{} = local, zone} when zone in @zones ->
        case instant(local, zone) do
          {:ok, _} -> changeset
          {:error, reason} -> add_error(changeset, field, reason)
        end

      _ ->
        changeset
    end
  end

  def instant(local, zone) do
    case DateTime.from_naive(local, zone, Tz.TimeZoneDatabase) do
      {:ok, zoned} ->
        {:ok, DateTime.shift_zone!(zoned, "Etc/UTC", Tz.TimeZoneDatabase)}

      {:gap, _, _} ->
        {:error, "does not exist when clocks move forward; choose another time"}

      {:ambiguous, _, _} ->
        {:error, "occurs twice when clocks move back; choose an unambiguous time in this example"}

      {:error, _} ->
        {:error, "has an unsupported time zone"}
    end
  end

  defp validate_time_order(%{valid?: false} = changeset), do: changeset

  defp validate_time_order(changeset) do
    {:ok, first} = instant(get_field(changeset, :starts_at), get_field(changeset, :zone))
    {:ok, last} = instant(get_field(changeset, :ends_at), get_field(changeset, :zone))

    if DateTime.compare(first, last) == :lt,
      do: changeset,
      else:
        add_error(
          changeset,
          :ends_at,
          "must be after the start; use the following date for overnight work"
        )
  end

  def schedule(params, appointments) do
    changeset = schedule_form(params)

    with {:ok, values} <- apply_action(changeset, :insert) do
      {:ok, first} = instant(values.starts_at, values.zone)
      {:ok, last} = instant(values.ends_at, values.zone)

      if Enum.any?(
           appointments,
           &(DateTime.compare(first, &1.ends_at) == :lt &&
               DateTime.compare(last, &1.starts_at) == :gt)
         ) do
        {:error,
         changeset
         |> add_error(:starts_at, "overlaps an existing booking for this crew")
         |> Map.put(:action, :insert)}
      else
        {:ok,
         %{
           id: length(appointments) + 1,
           starts_at: first,
           ends_at: last,
           zone: values.zone,
           minutes: div(DateTime.diff(last, first), 60)
         }}
      end
    end
  end

  def display(%DateTime{} = instant, zone) do
    local = DateTime.shift_zone!(instant, zone, Tz.TimeZoneDatabase)
    Calendar.strftime(local, "%b %d, %Y · %H:%M %Z")
  end

  def movements(receipt) do
    opening = [
      %{
        id: "opening-receipt",
        kind: "Received",
        quantity: 6,
        reference: "Opening sample delivery",
        route: "Supplier → Main warehouse",
        occurred_at: ~U[2026-09-24 13:00:00Z],
        recorded_at: ~U[2026-09-24 13:04:00Z]
      },
      %{
        id: "opening-transfer",
        kind: "Transferred",
        quantity: 2,
        reference: "TR-104",
        route: "Van 02 → Main warehouse",
        occurred_at: ~U[2026-09-25 18:30:00Z],
        recorded_at: ~U[2026-09-25 18:35:00Z]
      }
    ]

    deliveries =
      Enum.map(receipt.history, fn entry ->
        %{
          id: "receipt-#{entry.sequence}",
          kind: "Received",
          quantity: entry.quantity,
          reference: entry.reference,
          route: "Supplier → Main warehouse",
          occurred_at: entry.occurred_at,
          recorded_at: entry.recorded_at
        }
      end)

    Enum.sort_by(opening ++ deliveries, & &1.occurred_at, {:desc, DateTime})
  end

  def in_date_range(movements, %{from: first, to: last}, zone) do
    Enum.filter(movements, fn event ->
      date =
        event.occurred_at |> DateTime.shift_zone!(zone, Tz.TimeZoneDatabase) |> DateTime.to_date()

      Date.compare(date, first) != :lt && Date.compare(date, last) != :gt
    end)
  end
end
