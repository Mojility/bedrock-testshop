defmodule Business.Catalogue.ReceivingTest do
  use ExUnit.Case, async: true
  alias Business.Catalogue.Receiving

  test "partial and final receipt preserve reservations and close the outstanding quantity" do
    assert {:ok, partial} = Receiving.receive(Receiving.initial(), params(8, 0))
    assert partial.received == 8
    assert partial.on_hand == 16
    assert partial.reserved == 8
    assert {:ok, full} = Receiving.receive(partial, params(16, 1))
    assert full.received == full.ordered
    assert full.on_hand == 32
    assert Enum.map(full.history, & &1.quantity) == [16, 8]
    assert {:error, _} = Receiving.receive(full, params(1, 2))
  end

  test "invalid quantities and references never produce a changed state" do
    for quantity <- [0, -1, "1.5", "bad", 25] do
      assert {:error, _} = Receiving.receive(Receiving.initial(), params(quantity, 0))
    end

    for ref <- ["", " ", "a", String.duplicate("x", 81)] do
      assert {:error, _} =
               Receiving.receive(Receiving.initial(), Map.put(params(8, 0), "reference", ref))
    end
  end

  test "duplicate revision cannot apply the same delivery twice" do
    assert {:ok, state} = Receiving.receive(Receiving.initial(), params(8, 0))
    assert {:error, changeset} = Receiving.receive(state, params(8, 0))
    assert Keyword.has_key?(changeset.errors, :revision)
    assert state.on_hand == 16
  end

  defp params(quantity, revision),
    do: %{
      "quantity" => quantity,
      "reference" => "Slip 481",
      "revision" => revision,
      "occurred_at" => "2026-09-26T09:30",
      "zone" => "America/Toronto"
    }
end
