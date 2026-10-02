defmodule Business.Catalogue.TemporalTest do
  use ExUnit.Case, async: true
  alias Business.Catalogue.{Receiving, Temporal}

  test "dates preserve calendar semantics including leap day and inclusive endpoints" do
    assert Temporal.date_range_form(%{"from" => "2028-02-29", "to" => "2028-02-29"}).valid?
    refute Temporal.date_range_form(%{"from" => "2026-02-29", "to" => "2026-03-01"}).valid?
    refute Temporal.date_range_form(%{"from" => "2026-09-30", "to" => "2026-09-01"}).valid?
    refute Temporal.date_range_form(%{"from" => "", "to" => ""}).valid?
    movements = Temporal.movements(Receiving.initial())

    assert [%{kind: "Transferred"}] =
             Temporal.in_date_range(
               movements,
               %{from: ~D[2026-09-25], to: ~D[2026-09-25]},
               "America/Toronto"
             )

    midnight = [%{occurred_at: ~U[2026-09-26 02:00:00Z]}]

    assert Temporal.in_date_range(
             midnight,
             %{from: ~D[2026-09-25], to: ~D[2026-09-25]},
             "America/Toronto"
           ) == midnight

    assert Temporal.in_date_range(
             midnight,
             %{from: ~D[2026-09-26], to: ~D[2026-09-26]},
             "America/Toronto"
           ) == []
  end

  test "zone conversion rejects daylight-saving gaps and repeated times" do
    assert {:ok, ~U[2026-09-26 13:30:00Z]} =
             Temporal.instant(~N[2026-09-26 09:30:00], "America/Toronto")

    assert {:error, gap} = Temporal.instant(~N[2026-03-08 02:30:00], "America/Toronto")
    assert gap =~ "does not exist"
    assert {:error, ambiguous} = Temporal.instant(~N[2026-11-01 01:30:00], "America/Toronto")
    assert ambiguous =~ "occurs twice"
    assert {:error, _} = Temporal.instant(~N[2026-09-26 09:30:00], "Invalid/Zone")

    refute Temporal.timestamp_form(%{
             "occurred_at" => "2026-03-08T02:30",
             "zone" => "America/Toronto"
           }).valid?

    refute Temporal.timestamp_form(%{"occurred_at" => "bad", "zone" => "Invalid/Zone"}).valid?
    assert Temporal.display(~U[2026-09-26 13:30:00Z], "America/Toronto") =~ "09:30 EDT"
  end

  test "schedules allow adjacent and overnight work but reject overlap and reversed ranges" do
    params = Temporal.schedule_defaults()
    assert {:ok, first} = Temporal.schedule(params, [])
    assert first.minutes == 120
    assert {:error, _} = Temporal.schedule(params, [first])

    assert {:ok, _} =
             Temporal.schedule(
               %{params | "starts_at" => "2026-09-28T11:00", "ends_at" => "2026-09-28T12:00"},
               [first]
             )

    assert {:ok, overnight} =
             Temporal.schedule(
               %{params | "starts_at" => "2026-09-28T23:00", "ends_at" => "2026-09-29T01:00"},
               []
             )

    assert overnight.minutes == 120
    assert {:error, _} = Temporal.schedule(%{params | "ends_at" => "2026-09-28T09:00"}, [])
    assert {:error, _} = Temporal.schedule(%{params | "ends_at" => "2026-09-27T09:00"}, [])
    assert {:error, _} = Temporal.schedule(%{params | "starts_at" => ""}, [])

    assert {:ok, spring} =
             Temporal.schedule(
               %{params | "starts_at" => "2026-03-08T01:30", "ends_at" => "2026-03-08T03:30"},
               []
             )

    assert spring.minutes == 60
  end

  test "receipt preserves arrival time independently from system recording time" do
    params =
      Map.merge(Temporal.receipt_defaults(), %{
        "quantity" => 8,
        "reference" => "Slip 481",
        "revision" => 0
      })

    now = ~U[2026-09-26 15:00:00Z]
    assert {:ok, state} = Receiving.receive(Receiving.initial(), params, now)

    assert [%{occurred_at: ~U[2026-09-26 13:30:00Z], recorded_at: ^now} | _] =
             Temporal.movements(state)

    assert state.on_hand == 16
    assert state.reserved == 8

    assert {:error, _} =
             Receiving.receive(
               Receiving.initial(),
               %{params | "occurred_at" => "2026-11-01T01:30"},
               now
             )
  end
end
