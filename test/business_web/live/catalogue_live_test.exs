defmodule BusinessWeb.CatalogueLiveTest do
  use BusinessWeb.ConnCase, async: true
  import Phoenix.LiveViewTest
  alias Business.Catalogue.{Components, Model}

  test "website Journey carries an enquiry into private follow-up without leaving the page", %{
    conn: conn
  } do
    {:ok, view, _} = live(conn, "/dev/catalogue/model?node=journey:enquiry_to_follow_up")
    view |> form("#enquiry-demo-form", enquiry: %{name: "Casey Example"}) |> render_submit()
    assert has_element?(view, "#enquiry_phone[aria-invalid=true]")

    assert_push_event(view, "workbench:focus", %{
      selector: "#enquiry-demo-form [aria-invalid=true]"
    })

    view
    |> form("#enquiry-demo-form",
      enquiry: %{name: "Casey Example", phone: "555-0101", message: "Replace workshop lighting"}
    )
    |> render_submit()

    assert has_element?(view, "#enquiry-queue", "Casey Example")
    assert has_element?(view, "[role=status]", "4 sample enquiries")
    assert has_element?(view, "h3", "Follow up with Casey Example")

    view
    |> form("#lead-follow-up-form",
      follow_up: %{status: "contacted", notes: "Called to arrange a visit"}
    )
    |> render_submit()

    assert has_element?(view, "[role=status]", "No message was sent")
    assert has_element?(view, "#enquiry-queue tr", "Contacted")

    assert has_element?(
             view,
             "section[aria-label='Original enquiry']",
             "Replace workshop lighting"
           )

    view |> element("button[phx-value-id='sample-2']") |> render_click()
    assert has_element?(view, "h3", "Follow up with Sam Chen")
    assert has_element?(view, "#follow_up_notes", "Called; awaiting site photos.")
    render_submit(view, "save_enquiry_follow_up", %{"follow_up" => %{"status" => "bad"}})
    assert has_element?(view, "#follow_up_status[aria-invalid=true]")

    assert_push_event(view, "workbench:focus", %{
      selector: "#lead-follow-up-form [aria-invalid=true]"
    })

    render_patch(view, "/dev/catalogue/model?node=actor:office_staff")
    assert has_element?(view, "nav[aria-label='Choose a Journey']")

    ids =
      render(view)
      |> LazyHTML.from_fragment()
      |> LazyHTML.query("[id]")
      |> LazyHTML.attribute("id")

    assert length(ids) == length(Enum.uniq(ids))
  end

  test "sections and themes are navigable without accessing business records", %{conn: conn} do
    {:ok, view, _} = live(conn, "/dev/catalogue")
    view |> element("#exercise-control") |> render_click()
    assert has_element?(view, "#exercise-result", "Activated 1 times")
    view |> element("#theme-toggle") |> render_click()
    assert has_element?(view, "[data-wb-theme=dark]")

    for section <- ~w(controls compositions blueprints graph) do
      render_patch(view, "/dev/catalogue/#{section}")
      assert has_element?(view, "a[aria-current=page][href='/dev/catalogue/#{section}']")
    end

    assert has_element?(view, "a[href='/dev/catalogue/graph?node=table']", "Data table")
  end

  test "component explorer provides previews and traversable relationships", %{conn: conn} do
    {:ok, view, _} = live(conn, "/dev/catalogue/graph?node=split")
    assert has_element?(view, "#component-heading", "Table + inspector")
    assert has_element?(view, "#stock-table")

    view
    |> element("a.catalogue-part-label[href='/dev/catalogue/graph?node=table']")
    |> render_click()

    assert has_element?(view, "#component-heading", "Data table")
    assert has_element?(view, "#graph-table")
    assert has_element?(view, ".catalogue-anatomy a[href='/dev/catalogue/graph?node=split']")

    for node <- Components.all() do
      render_patch(view, "/dev/catalogue/graph?node=#{node.id}")
      assert has_element?(view, "#component-heading", node.title)
      assert has_element?(view, ".catalogue-preview-content")
      assert has_element?(view, "nav[aria-label='Component library'] a[aria-current=true]")
    end

    render_patch(view, "/dev/catalogue/graph?node=input")
    view |> form("#example-form", example: %{name: ""}) |> render_submit()
    assert has_element?(view, "#example_name[aria-invalid=true]")
    render_patch(view, "/dev/catalogue/graph?node=unknown")
    assert has_element?(view, "#component-heading", "Foundations")
  end

  test "domain and visual models connect through blueprint bindings", %{conn: conn} do
    {:ok, view, _} = live(conn, "/dev/catalogue/domain?node=stock_position")
    assert has_element?(view, "#component-heading", "Stock position")
    assert has_element?(view, "a[href='/dev/catalogue/domain?node=quantity']")
    assert has_element?(view, "a[href='/dev/catalogue/graph?node=inventory-picker']")
    render_patch(view, "/dev/catalogue/graph?node=inventory-picker")

    assert has_element?(
             view,
             "#inventory-part-choice option[value=MAT-112]",
             "0 each available / 8 on hand"
           )

    view |> form("#stock-filter", filter: %{query: "MAT-310"}) |> render_change()
    view |> form("#inventory-picker", part_id: "MAT-310") |> render_change()
    assert has_element?(view, "#inventory-part-choice option[selected][value=MAT-310]")
    render_patch(view, "/dev/catalogue/domain?node=stock_position")
    assert has_element?(view, ".catalogue-preview-content", "60 m")
    view |> form("#domain-picker", node: "quantity") |> render_change()
    assert has_element?(view, "#component-heading", "Quantity")
    render_patch(view, "/dev/catalogue/blueprints")
    assert has_element?(view, "a[href='/dev/catalogue/domain?node=receipt']")
    assert has_element?(view, "a[href='/dev/catalogue/graph?node=inventory-picker']")
  end

  test "design model connects commands, bindings and working compositions", %{conn: conn} do
    {:ok, view, _} = live(conn, "/dev/catalogue/model?node=command:receive_materials")
    assert has_element?(view, "#component-heading", "Record receipt")

    assert has_element?(
             view,
             "#concept-incoming a[href='/dev/catalogue/model?node=binding:record_receipt']"
           )

    view
    |> element("#concept-incoming a[href='/dev/catalogue/model?node=binding:record_receipt']")
    |> render_click()

    assert has_element?(view, "#component-heading", "Record a delivery")

    assert has_element?(
             view,
             "#concept-outgoing a[href='/dev/catalogue/model?node=projection:receiving_context']"
           )

    render_patch(view, "/dev/catalogue/graph?node=record")
    assert has_element?(view, "#contract-record", "Composition contract")
    assert has_element?(view, "a[href='/dev/catalogue/model?node=command:receive_materials']")

    for concept <- Model.nodes() do
      render_patch(view, "/dev/catalogue/model?node=#{concept["id"]}")
      assert has_element?(view, "#component-heading", concept["name"])
    end
  end

  test "Actor Journey stages render working compositions with shared receipt state", %{conn: conn} do
    {:ok, view, _} = live(conn, "/dev/catalogue/model")
    assert has_element?(view, "#component-heading", "Warehouse staff")
    assert has_element?(view, "nav[aria-label='User-centric product model']")

    assert has_element?(
             view,
             "#journey-stage-identify_materials a[href='/dev/catalogue/graph?node=split']"
           )

    assert has_element?(view, "#journey-stage-identify_materials #stock-table")
    assert has_element?(view, "#journey-stage-record_delivery #receipt-form")
    assert has_element?(view, "#journey-stage-review_result #movement-table")

    view
    |> form("#receipt-form",
      receipt: %{
        quantity: "8",
        reference: "JOURNEY-8",
        revision: "0",
        occurred_at: "2026-09-26T09:30",
        zone: "America/Toronto"
      }
    )
    |> render_submit()

    assert has_element?(view, "#journey-stage-review_result #movement-table", "JOURNEY-8")
    assert has_element?(view, "#journey-stage-record_delivery #on-hand", "16")
    assert has_element?(view, "#journey-stage-identify_materials #stock-table", "MAT-112")
    view |> form("#stock-filter", filter: %{query: "MAT-112"}) |> render_change()
    assert has_element?(view, "#journey-stage-review_result #movement-table", "JOURNEY-8")
    assert has_element?(view, "nav[aria-label='User-centric product model']")

    ids =
      view
      |> render()
      |> LazyHTML.from_document()
      |> LazyHTML.query("[id]")
      |> LazyHTML.attribute("id")

    assert length(ids) == length(Enum.uniq(ids))
  end

  test "temporal controls validate, schedule, and filter receipt and transfer history", %{
    conn: conn
  } do
    {:ok, view, _} = live(conn, "/dev/catalogue/graph?node=schedule")
    view |> form("#schedule-form") |> render_submit()
    assert has_element?(view, "#booking-1", "120 minutes")
    view |> form("#schedule-form") |> render_submit()
    assert has_element?(view, "#schedule_starts_at[aria-invalid=true]")
    assert_push_event(view, "workbench:focus", %{selector: "#schedule-form [aria-invalid=true]"})
    render_patch(view, "/dev/catalogue/graph?node=timestamp-field")

    view
    |> form("#timestamp-form",
      timestamp: %{occurred_at: "2026-03-08T02:30", zone: "America/Toronto"}
    )
    |> render_submit()

    assert has_element?(view, "#timestamp_occurred_at[aria-invalid=true]")

    view
    |> form("#timestamp-form",
      timestamp: %{occurred_at: "2026-09-26T09:30", zone: "America/Toronto"}
    )
    |> render_submit()

    assert has_element?(view, "#resolved-timestamp time[datetime='2026-09-26T13:30:00Z']")
    render_patch(view, "/dev/catalogue/compositions")
    view |> element("nav button[phx-value-scenario=receiving]") |> render_click()

    view
    |> form("#receipt-form", receipt: %{quantity: 8, reference: "Timed delivery"})
    |> render_submit()

    view |> element("nav button[phx-value-scenario=movements]") |> render_click()
    assert has_element?(view, "#movement-table", "Timed delivery")

    view
    |> form("#movement-range", range: %{from: "2026-09-25", to: "2026-09-25"})
    |> render_change()

    assert has_element?(view, "#movement-table", "TR-104")
    refute has_element?(view, "#movement-table", "Timed delivery")

    view
    |> form("#movement-range", range: %{from: "2026-09-30", to: "2026-09-25"})
    |> render_change()

    assert has_element?(view, "#range-invalid")
    assert has_element?(view, "#movement-table", "TR-104")
  end

  test "composition buttons tolerate the browser's native empty value", %{conn: conn} do
    {:ok, view, _} = live(conn, "/dev/catalogue/compositions")

    for {scenario, composition} <- [
          {"stock", "stock"},
          {"task", "task"},
          {"receiving", "receiving"}
        ] do
      view
      |> element("nav button[phx-value-scenario=#{scenario}]")
      |> render_click(%{"value" => ""})

      assert has_element?(view, "##{composition}-composition")
    end
  end

  test "invalid input is retained and partial receipts update both compositions", %{conn: conn} do
    {:ok, view, _} = live(conn, "/dev/catalogue/compositions")

    view
    |> form("#receipt-form", receipt: %{quantity: 30, reference: "Slip 481"})
    |> render_submit()

    assert has_element?(view, "#on-hand", "8")
    assert has_element?(view, "#receipt_reference[value='Slip 481']")

    view
    |> form("#receipt-form", receipt: %{quantity: 8, reference: "Slip 481"})
    |> render_submit()

    assert has_element?(view, "#available", "8")
    assert has_element?(view, "#receipt-1", "8 units received")
    view |> element("button[phx-value-scenario=stock]") |> render_click()
    assert has_element?(view, "#stock-table", "16")
    view |> form("#stock-filter", filter: %{query: "no such material"}) |> render_change()
    assert has_element?(view, "#stock-empty")
    view |> form("#stock-filter", filter: %{query: "panel"}) |> render_change()
    view |> element("tr[phx-value-id=MAT-204]") |> render_click()
    assert has_element?(view, "#selected-stock", "200A panel assembly")
    view |> element("button[phx-click=density]") |> render_click()
    assert has_element?(view, "#stock-table.wb-compact")
    view |> element("nav button[phx-value-scenario=receiving]") |> render_click()

    view
    |> form("#receipt-form", receipt: %{quantity: 16, reference: "Slip 482"})
    |> render_submit()

    assert has_element?(view, "#receipt-complete")
    refute has_element?(view, "#receipt-form")
    assert has_element?(view, "#available", "24")
    view |> element("#reset-receipt") |> render_click()
    assert has_element?(view, "#receipt-form")
    assert has_element?(view, "#available", "0")
  end

  test "table sorts numerically, retains selection, and clears an empty search", %{conn: conn} do
    {:ok, view, _} = live(conn, "/dev/catalogue/compositions")
    view |> element("nav button[phx-value-scenario=stock]") |> render_click(%{"value" => ""})
    assert has_element?(view, "#stock-toolbar-count", "2000 of 2000 items")

    view |> form("#stock-filter", filter: %{query: "MAT-"}) |> render_change()
    view |> element("button[phx-value-column=on_hand]") |> render_click(%{"value" => ""})
    assert has_element?(view, "#stock-table th[aria-sort=ascending]", "On hand")
    assert has_element?(view, "#stock-table tbody tr:first-child#stock-table-MAT-428")
    view |> element("button[phx-value-column=on_hand]") |> render_click(%{"value" => ""})
    assert has_element?(view, "#stock-table th[aria-sort=descending]", "On hand")
    assert has_element?(view, "#stock-table tbody tr:first-child#stock-table-MAT-310")
    assert has_element?(view, "#stock-table-MAT-112.wb-selected")

    for column <- ~w(reserved available name) do
      view |> element("button[phx-value-column=#{column}]") |> render_click()

      assert has_element?(
               view,
               "#stock-table th[aria-sort=ascending] button[phx-value-column=#{column}]"
             )
    end

    view |> form("#stock-filter", filter: %{query: "A-04"}) |> render_change()
    assert has_element?(view, "#stock-toolbar-count", "1 of 2000 items")
    view |> element("tr[phx-value-id=MAT-204]") |> render_click()
    view |> form("#stock-filter", filter: %{query: "not here"}) |> render_change()
    assert has_element?(view, "#stock-empty")
    assert has_element?(view, "#selection-filtered")
    assert has_element?(view, "#selected-stock", "200A panel assembly")
    view |> element("#clear-stock-search") |> render_click()
    assert_push_event(view, "workbench:clear-search", %{id: "stock-filter"})
    assert has_element?(view, "#stock-toolbar-count", "2000 of 2000 items")
    refute has_element?(view, "#stock-empty")
    refute has_element?(view, "#selection-filtered")
    assert has_element?(view, "#stock-table-MAT-204.wb-selected")
  end

  test "large stock catalogue pages, filters categories and inspects photo states", %{conn: conn} do
    {:ok, view, _} = live(conn, "/dev/catalogue/compositions")
    view |> element("nav button[phx-value-scenario=stock]") |> render_click()
    assert has_element?(view, "#stock-pagination", "Page 1 of 80")
    view |> element("button[aria-label='Next page']") |> render_click(%{"value" => ""})
    assert has_element?(view, "#stock-pagination", "26–50 of 2000")
    view |> element("button[aria-label='Last page']") |> render_click()
    assert has_element?(view, "#stock-pagination", "1976–2000 of 2000")
    assert has_element?(view, "button[aria-label='Next page'][disabled]")
    view |> form("#stock-options", options: %{category: "Cable"}) |> render_change()
    view |> form("#stock-page-size", options: %{size: "100"}) |> render_change()
    assert has_element?(view, "#stock-pagination", "1–100 of 167")
    view |> form("#stock-filter", filter: %{query: "SKU-10002"}) |> render_change()
    view |> element("tr[phx-value-id=SKU-10002]") |> render_click()
    assert has_element?(view, ".wb-part-photo img[src='/images/catalogue/parts/cable.png']")
    view |> element("#clear-stock-search") |> render_click()
    view |> form("#stock-filter", filter: %{query: "SKU-11992"}) |> render_change()
    assert has_element?(view, "#stock-toolbar-count", "1 of 2000 items")
    view |> element("tr[phx-value-id=SKU-11992]") |> render_click()
    assert has_element?(view, "#stock-photo-missing")
    assert has_element?(view, "#stock-pagination", "Page 1 of 1")
  end

  test "accessible navigation, errors and record context remain connected", %{conn: conn} do
    {:ok, view, _} = live(conn, "/dev/catalogue/controls")
    assert has_element?(view, "nav[aria-label='Catalogue sections']")
    assert has_element?(view, "a[href='#catalogue-heading']", "Skip to main content")
    assert has_element?(view, "h1#catalogue-heading[tabindex='-1']")
    view |> form("#example-form", example: %{name: "", status: "Ready"}) |> render_submit()

    assert has_element?(
             view,
             "#example_name[aria-invalid=true][aria-describedby=example_name-errors]"
           )

    assert has_element?(view, "#example_name-errors[role=alert]", "Enter a customer name")
    assert_push_event(view, "workbench:focus", %{selector: "#example-form [aria-invalid=true]"})
    view |> form("#example-form", example: %{name: "Morgan", status: "Ready"}) |> render_submit()
    refute has_element?(view, "#example_name[aria-invalid=true]")
    refute has_element?(view, "#example_name-errors")
    render_patch(view, "/dev/catalogue/compositions")
    view |> element("nav button[phx-value-scenario=stock]") |> render_click()
    assert has_element?(view, "#stock-table caption", "Warehouse stock")

    assert has_element?(
             view,
             "#stock-table-MAT-112 button[aria-controls=stock-composition-inspector][aria-pressed=true][aria-label='15A AFCI breaker, MAT-112']"
           )

    assert has_element?(view, "#stock-selection-status[role=status][aria-atomic=true]", "MAT-112")
    assert has_element?(view, "#stock-composition-inspector[tabindex='-1']")
    assert has_element?(view, "a[href='#stock-composition-inspector']")
  end

  test "field example and form errors are recoverable", %{conn: conn} do
    {:ok, view, _} = live(conn, "/dev/catalogue/controls")
    view |> form("#example-form", example: %{name: "", status: "Ready"}) |> render_submit()
    refute has_element?(view, "#control-result")
    assert has_element?(view, "#example_status option[selected]", "Ready")
    view |> form("#example-form", example: %{name: "Morgan", status: "Ready"}) |> render_submit()
    assert has_element?(view, "#control-result", "Saved Morgan as Ready")
    render_patch(view, "/dev/catalogue/compositions")
    view |> element("button[phx-value-scenario=task]") |> render_click()
    view |> element("#inspection-toggle") |> render_click()
    assert has_element?(view, "#inspection-done")
    view |> element("#inspection-toggle") |> render_click()
    refute has_element?(view, "#inspection-done")
  end
end
