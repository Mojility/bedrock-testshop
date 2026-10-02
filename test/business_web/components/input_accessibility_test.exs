defmodule BusinessWeb.InputAccessibilityTest do
  use ExUnit.Case, async: true
  import Phoenix.LiveViewTest

  test "all input types associate errors while preserving caller help text" do
    for type <- ~w(text select textarea checkbox) do
      html =
        render_component(&BusinessWeb.CoreComponents.input/1,
          id: "sample",
          name: "sample",
          value: "",
          label: "Sample",
          type: type,
          options: ["First"],
          errors: ["Needs correction"],
          rest: %{"aria-describedby": "sample-help"}
        )

      document = LazyHTML.from_fragment(html)

      assert document
             |> LazyHTML.query(
               "#sample[aria-invalid=true][aria-describedby='sample-help sample-errors']"
             )
             |> Enum.count() == 1

      assert document |> LazyHTML.query("#sample-errors[role=alert]") |> Enum.count() == 1
    end
  end
end
