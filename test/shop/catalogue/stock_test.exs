defmodule Shop.Catalogue.StockTest do
  use ExUnit.Case, async: true
  alias Shop.Catalogue.{Receiving, Stock}

  defp options(overrides) do
    Map.merge(
      %{
        query: "",
        category: "All categories",
        sort: "name",
        direction: "asc",
        page: 1,
        size: 25,
        selected: "MAT-112"
      },
      overrides
    )
  end

  test "busy inventory has unique identifiers, stock variation and optional photos" do
    rows = Stock.all(Receiving.initial())
    assert length(rows) == 2000
    assert length(Enum.uniq_by(rows, & &1.id)) == 2000
    assert length(Stock.categories()) == 12
    assert Enum.any?(rows, &(&1.on_hand == 0))
    assert Enum.any?(rows, &(&1.photo == nil))
    assert Enum.any?(rows, &(&1.photo == "cable"))
    assert Enum.all?(rows, &(&1.reserved <= &1.on_hand))
    assert Stock.get(Receiving.initial(), "missing") == nil
  end

  test "search and sorting apply to the entire inventory before pagination" do
    receipt = Receiving.initial()
    first = Stock.page(receipt, options(%{sort: "on_hand", direction: "desc"}))
    next = Stock.page(receipt, options(%{sort: "on_hand", direction: "desc", page: 2}))
    assert first.total == 2000
    assert first.pages == 80
    assert length(first.rows) == 25
    assert List.last(first.rows).on_hand >= hd(next.rows).on_hand
    assert MapSet.disjoint?(MapSet.new(first.rows, & &1.id), MapSet.new(next.rows, & &1.id))
    found = Stock.page(receipt, options(%{query: "SKU-11992"}))
    assert [%{id: "SKU-11992"}] = found.rows
    assert found.total == 1
    assert Stock.page(receipt, options(%{query: "cable northline", category: "Cable"})).total > 0
  end

  test "page bounds and empty results remain meaningful" do
    receipt = Receiving.initial()
    last = Stock.page(receipt, options(%{page: 999, size: 100}))
    assert {last.page, last.first, last.last} == {20, 1901, 2000}
    empty = Stock.page(receipt, options(%{query: "absent part", page: 20}))
    assert {empty.page, empty.pages, empty.first, empty.last} == {1, 1, 0, 0}
    assert empty.rows == []
    refute empty.selected_matches
    assert Stock.page(receipt, options(%{page: 0})).page == 1
  end
end
