defmodule Shop.Catalogue.Components do
  @moduledoc "Presentation relationships and usage guidance for the executable catalogue."

  def all do
    [
      node(
        "website-leads",
        "Website enquiries and follow-up",
        "Blueprint",
        ["website-intro", "enquiry-form", "lead-queue", "lead-follow-up"],
        "Connect a prospective customer's request to private staff follow-up.",
        "Explore the customer and office staff Journeys with shared synthetic enquiries.",
        "Public and private contexts are named. Validation, selection and save results support keyboard use."
      ),
      node(
        "website-intro",
        "Public website",
        "Composition",
        ["header", "button"],
        "Help a prospective customer understand services and decide to enquire.",
        "Public and staff stages share synthetic records in the Journey preview. Real staff access requires authentication.",
        "Native labelled controls, keyboard selection, associated errors and announced results."
      ),
      node(
        "enquiry-form",
        "Website enquiry form",
        "Composition",
        ["input", "button", "notice"],
        "Collect a name, a way to reply and the help requested.",
        "Public and staff stages share synthetic records in the Journey preview. Real staff access requires authentication.",
        "Native labelled controls, keyboard selection, associated errors and announced results."
      ),
      node(
        "lead-queue",
        "Enquiry queue",
        "Composition",
        ["table", "status", "timestamp-display"],
        "Let office staff scan enquiries and select one for follow-up.",
        "Public and staff stages share synthetic records in the Journey preview. Real staff access requires authentication.",
        "Native labelled controls, keyboard selection, associated errors and announced results."
      ),
      node(
        "lead-follow-up",
        "Lead + follow-up",
        "Composition",
        ["header", "input", "select", "button", "notice"],
        "Keep the original request alongside private follow-up status and notes.",
        "Public and staff stages share synthetic records in the Journey preview. Real staff access requires authentication.",
        "Native labelled controls, keyboard selection, associated errors and announced results."
      ),
      node(
        "date-field",
        "Date input",
        "Control",
        ["input"],
        "A calendar day without a time zone.",
        "Use for due dates or promised delivery days, not exact event times.",
        "Native date input retains a visible label and keyboard entry."
      ),
      node(
        "time-field",
        "Time-of-day input",
        "Control",
        ["input"],
        "A local clock time, independent of a date.",
        "Use for business hours; pair with a date and zone for a specific appointment.",
        "Native time input supports keyboard entry and a visible label."
      ),
      node(
        "timestamp-field",
        "Zoned timestamp input",
        "Pattern",
        ["input", "select", "notice"],
        "Resolve a local date and time in a named zone into an exact instant.",
        "Use for when a delivery arrived or a transfer occurred. Do not infer the business zone from the browser.",
        "Grouped date/time and zone fields; daylight-saving errors are linked to the field and focused on submission."
      ),
      node(
        "timestamp-display",
        "Timestamp display",
        "Pattern",
        ["foundations"],
        "A readable moment with machine-readable time and visible zone.",
        "Show absolute occurrence and recording times in histories; relative wording alone is insufficient.",
        "Semantic time elements expose an ISO timestamp and visible date, time and zone."
      ),
      node(
        "duration-display",
        "Duration",
        "Pattern",
        ["foundations"],
        "An explicitly labelled elapsed amount of time.",
        "Calculate from resolved instants; clock changes can make elapsed time differ from wall-clock time.",
        "State the unit in text; never rely on a bar width alone."
      ),
      node(
        "date-range",
        "Date range",
        "Pattern",
        ["date-field", "notice"],
        "An inclusive first and last calendar date.",
        "Use for history filters and all-day reporting periods, with a stated reporting zone.",
        "Fieldset and legend group labelled endpoints; invalid order retains the last valid results."
      ),
      node(
        "time-range",
        "Scheduled window",
        "Pattern",
        ["timestamp-field", "duration-display"],
        "A start and end in a scheduling zone, with positive elapsed duration.",
        "End is excluded, so adjacent bookings can meet without conflict.",
        "Label both endpoints and the zone. Reject gaps, repeated times and reversed intervals explicitly."
      ),
      node(
        "schedule",
        "Schedule + agenda",
        "Composition",
        ["header", "time-range", "button", "inspector"],
        "Book warehouse work and see the crew’s agenda alongside it.",
        "Use for one-off work windows. This sample checks overlap for a single crew.",
        "Errors focus their field; successful additions announce the updated booking count."
      ),
      node(
        "movement-history",
        "Stock movement history",
        "Composition",
        ["date-range", "table", "timestamp-display"],
        "See when stock was received or transferred, and when it was recorded.",
        "Filter by occurrence date in the stated business zone. Recording time remains separately visible.",
        "Native tables, labelled date controls and announced counts support keyboard and screen-reader review."
      ),
      node(
        "foundations",
        "Foundations",
        "Foundation",
        [],
        "Colour, typography, spacing and focus give every screen a shared language.",
        "Use semantic roles in both themes; never encode meaning in colour alone.",
        "Check contrast, reflow, reduced motion and visible focus."
      ),
      node(
        "button",
        "Button",
        "Control",
        ["foundations", "icon"],
        "An explicit action, such as recording a delivery or clearing a filter.",
        "Use a verb. Reserve primary emphasis for the main task; secondary actions retain context.",
        "Native button: Tab to focus, Enter or Space to activate. Disabled actions expose their state."
      ),
      node(
        "input",
        "Text & number input",
        "Control",
        ["foundations", "notice"],
        "A labelled field for information a person needs to enter.",
        "Keep labels visible and retain values when validation fails.",
        "Labels name the field. Invalid state and error descriptions are linked; submission focuses the first error."
      ),
      node(
        "select",
        "Select",
        "Control",
        ["foundations"],
        "A choice from a known set, such as category or page size.",
        "Use for short, predictable lists. Large option sets need a searchable chooser, not yet built.",
        "Native select supports platform keyboard interaction and exposes its current value."
      ),
      node(
        "inventory-picker",
        "Inventory item selector",
        "Pattern",
        ["search", "select", "status"],
        "Choose a part with availability and location alongside its name.",
        "Use when the decision needs business context. The stored selection is the item ID; stock counts are read-only context.",
        "Native select options include name, SKU, available quantity, unit and location. Search limits the option set; selection is announced."
      ),
      node(
        "icon",
        "Icon",
        "Control",
        ["foundations"],
        "A small visual cue supporting a named action or state.",
        "Pair unfamiliar symbols with text. An icon alone is not an accessible name.",
        "Decorative icons are hidden from screen readers; their parent control supplies the name."
      ),
      node(
        "status",
        "Status badge",
        "Pattern",
        ["foundations"],
        "A compact statement of a record’s current state.",
        "Use beside a record title or in a row. It is a label, not a button.",
        "Visible words carry the meaning independently of colour."
      ),
      node(
        "notice",
        "Notice & feedback",
        "Pattern",
        ["foundations"],
        "An explanation of a result, problem or next step.",
        "Keep messages close to the task. Use urgent alerts only for errors requiring attention.",
        "Status messages are polite; errors use alerts. Avoid repeated announcements of unchanged content."
      ),
      node(
        "header",
        "Record header",
        "Pattern",
        ["status", "button"],
        "The record’s identity, context and primary actions in one place.",
        "Name the task once. Put supporting references below it; avoid repeated business branding.",
        "A heading identifies the record; actions retain native button semantics."
      ),
      node(
        "search",
        "Table toolbar",
        "Pattern",
        ["input", "button", "select"],
        "Compact search, result count and table controls.",
        "Keep frequently used controls together. Search covers the full dataset, not just this page.",
        "Search has an accessible name; results are announced without stealing focus."
      ),
      node(
        "table",
        "Data table",
        "Pattern",
        ["button", "photo"],
        "Comparable records with sortable headings, numeric alignment and optional row selection.",
        "Use when scanning and comparing matters. Keep row actions available to both pointer and keyboard users.",
        "Native caption and column headers, aria-sort, unique record buttons and explicit selected state."
      ),
      node(
        "pagination",
        "Pagination",
        "Pattern",
        ["button", "select"],
        "A bounded window onto a larger set of records.",
        "Show the current range and total. Keep page size near page navigation.",
        "Named controls expose disabled boundaries. Page changes announce their range and retain focus."
      ),
      node(
        "photo",
        "Part photo",
        "Pattern",
        ["icon"],
        "A thumbnail for recognition, a larger reference image and an honest missing-photo state.",
        "Use as supporting evidence. The demo reuses generated category examples, not exact product photographs.",
        "Redundant thumbnails use empty alt text; meaningful larger images have descriptions and labelled links."
      ),
      node(
        "inspector",
        "Inspector",
        "Pattern",
        ["photo", "status", "notice"],
        "Supporting details for the selected record, alongside the current work.",
        "Preserve the selection while searching and paging. Avoid forcing a separate page for quick reference.",
        "A named complementary landmark and keyboard skip link provide direct access."
      ),
      node(
        "split",
        "Table + inspector",
        "Composition",
        ["header", "search", "table", "pagination", "inspector"],
        "Browse a busy inventory and inspect a part without losing the list.",
        "Useful for stock, quotes and invoices when comparison and detail need to coexist.",
        "Selection is announced, focus stays with the task, and the inspector moves below the table on narrow screens."
      ),
      node(
        "record",
        "Record + inspector",
        "Composition",
        ["header", "table", "input", "timestamp-field", "button", "notice", "inspector"],
        "Complete a focused transaction while seeing its consequences and history.",
        "Use for receiving, approvals or other bounded record updates.",
        "Validation retains input; finishing a task that removes its form moves focus to the result."
      ),
      node(
        "task",
        "Task + evidence",
        "Composition",
        ["header", "button", "status", "inspector"],
        "A clear action with supporting evidence and completion state.",
        "Use for inspections and checklists. This starter demonstrates a check, not an attachment workflow.",
        "Completion is expressed in words and announced; controls remain keyboard operable."
      ),
      node(
        "receiving",
        "Receive materials",
        "Blueprint",
        ["record", "split", "task", "schedule", "movement-history"],
        "A business capability for partial deliveries, stock updates and inspection.",
        "Start from the workflow, roles, records and invariants; adapt to the business before implementation.",
        "Accessibility must be tested across the complete workflow, not inferred from its components."
      )
    ]
  end

  def get(id), do: Enum.find(all(), &(&1.id == id)) || Enum.find(all(), &(&1.id == "foundations"))
  def used_in(id), do: Enum.filter(all(), &(id in &1.depends))

  defp node(id, title, layer, depends, purpose, usage, accessibility) do
    %{
      id: id,
      title: title,
      layer: layer,
      depends: depends,
      purpose: purpose,
      usage: usage,
      accessibility: accessibility
    }
  end
end
