defmodule Shop.Catalogue.EnquiriesTest do
  use ExUnit.Case, async: true
  alias Shop.Catalogue.Enquiries

  test "public enquiry validation protects private fields and carries the request into follow-up" do
    state = Enquiries.initial()
    invalid = Enquiries.submit(state, %{"name" => "Visitor"})
    refute invalid.form.source.valid?
    assert invalid.leads == state.leads
    invalid_email = Enquiries.submit(state, %{"name" => "Visitor", "email" => "broken"})
    refute invalid_email.form.source.valid?

    state =
      Enquiries.submit(state, %{
        "name" => " Visitor ",
        "email" => "visitor@example.test",
        "message" => "Repair lights",
        "status" => "closed",
        "notes" => "public injection"
      })

    assert state.selected.name == "Visitor"
    assert state.selected.status == "new"
    assert state.selected.notes == nil
    assert hd(state.leads) == state.selected
    assert state.selected.seen_at == nil
    original = state.selected

    failed = Enquiries.follow_up(state, %{"status" => "invalid"})
    refute failed.follow_up.source.valid?
    assert failed.selected == original
    failed = Enquiries.follow_up(state, %{"notes" => String.duplicate("x", 4001)})
    refute failed.follow_up.source.valid?

    state =
      Enquiries.follow_up(state, %{
        "status" => "contacted",
        "notes" => "Called customer",
        "message" => "replacement"
      })

    assert state.selected.message == original.message
    assert state.selected.notes == "Called customer"
    assert state.selected.status == "contacted"
    assert %DateTime{} = state.selected.seen_at
    seen = state.selected.seen_at
    state = Enquiries.follow_up(state, %{"status" => "closed"})
    assert state.selected.seen_at == seen
    assert Enquiries.select(state, "missing") == state
    state = Enquiries.select(state, "sample-2")
    assert state.selected.name == "Sam Chen"
    assert state.selected.seen_at == nil
  end
end
