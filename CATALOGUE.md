# Living component catalogue

Run the normal Phoenix development server and open `/dev/catalogue`. For a
separate local port, run `PORT=4005 mix phx.server` with your normal local
database settings. The server binds to loopback by default. No additional
frontend service is needed.

## Explore

- **Foundations:** semantic colour roles, typography and density; light/dark
  switch.
- **Controls:** buttons, labelled fields, status, notices and recoverable
  validation.
- **Compositions:** record/inspector, searchable table/inspector and
  task/evidence, scheduling/agenda and dated stock-movement history.
- **Blueprints:** business questions, rules, acceptance scenarios and known
  gaps.
- **Graph:** a visual component explorer with individual live previews, usage
  guidance, accessibility behaviour and bidirectional composition relationships.

Try receiving 8 of 24 breakers using a packing-slip reference, then the
remaining 16. The stock table shares that session-local record. Invalid
quantities preserve input and do not change stock. Refreshing resets all
examples. The catalogue performs no business database writes, emails, payments
or accounting syncs.

## Source contracts

| Source | Responsibility |
| --- | --- |
| `ShopWeb.CoreComponents` | Existing buttons, fields, icons and validation output |
| `ShopWeb.Workbench` | Headers, status, notices, typed tables and split compositions |
| `assets/css/workbench.css` | Operational colour roles, control and layout styles |
| `ShopWeb.CatalogueLive` | Example state and catalogue navigation |
| `Shop.Catalogue.Receiving` | Pure synthetic receiving transitions and validation |
| `priv/catalogue/receiving.json` | Versioned blueprint snapshot with source digest |

Each component declares attributes and slots. Business contexts retain ownership
of authorization, persistence, concurrency and transactions. Presentation
components must not derive permissions from visible or hidden controls.

The component graph currently describes the implemented subset explicitly in the
`Shop.Catalogue.Components` registry. New graph nodes must reference existing
nodes and reflect the actual composition contract. The blueprint snapshot is
portable; rendering it does not require Bedrock source, credentials or a network
call to the platform.

The receipt revision check prevents repeated application within this synthetic
session. It is not a substitute for transactional concurrency or idempotency in
a persistent customer implementation. Partial delivery and form recovery are
tested; receipt corrections, attachments, role enforcement and accounting are
not included.

## Table conventions

Sortable column slots declare a `sort_key`; the table emits the configured sort
command while its caller owns ordering. Headings expose `aria-sort`. Numeric
columns sort by numeric value. Row striping, hover, selected-record emphasis and
sticky headings use semantic theme roles. Record actions remain keyboard buttons.

The shared toolbar combines a compact labelled search, result count and density
control. Search matches names, SKUs, bins, categories, manufacturers and ranges.
Clearing search restores all results without losing the selected record or sort
order. An explicit notice identifies
selection outside the current result set. Column customization, bulk actions and
saved views are future patterns, not implemented controls.

The stock composition contains 2,000 deterministic synthetic parts across 12
categories, including zero stock, reservations, stocking units and reorder points.
Category filtering and 25/50/100-row pagination operate on the complete result
set. The reusable pagination control reports ranges and disables boundary actions;
the caller owns filtering, sorting and page state. Selection survives page changes.
This is an in-memory interaction fixture, not a database performance benchmark.

Optional thumbnails and inspector images demonstrate photo and missing-photo
states. Three locally served, AI-generated category images (breaker, cable and
receptacle) are representative examples reused across variants, not exact product
identification. Manufacturers and ranges are synthetic too.

## Development boundary

The route is conditional on `dev_routes` in the existing `current_user` live
session. It uses the normal browser pipeline and CSRF protection. Production
builds omit the route. The catalogue has no authentication requirement because
its state is synthetic and isolated from customer business records.

`Layouts.app` exposes an explicit catalogue presentation variant. Normal
customer layouts and staff navigation retain their existing appearance and
authorization. The demonstration uses no alternate login mechanism.

Run `mix precommit` before treating an increment as complete. Behaviour tests
cover invalid receipt quantities, partial/final delivery, repeated revisions,
filters, selection, form recovery and state shared between compositions. Browser
review must cover keyboard interaction, narrow layouts and both colour themes.

## Accessibility contract

Accessibility is a release criterion for every primitive, composition and
blueprint. Target WCAG 2.2 AA, with stronger focus visibility, touch targets and
reduced-motion support where practical. This is a target, not a conformance claim.

- Use native headings, landmarks, buttons, links, form controls and tables first.
  Do not add grid or tab roles without their complete keyboard interaction model.
- Every control needs an accessible name. Repeated record actions include the
  record identifier. Icons are decorative; meaningful images need useful alt text.
- Errors expose `aria-invalid` and reference visible messages through
  `aria-describedby`, preserving existing help associations. Give every input
  an ID.
  Invalid submission focuses the first invalid field; live validation does not.
- Keep focus visible and unobscured by sticky table headings. Section navigation
  focuses its heading; completion that removes a form focuses its result.
- Whole-row pointer selection retains a native keyboard button. Its pressed state
  and `aria-controls` identify the selected record and supporting inspector.
  A polite status announces selection; a skip link reaches the inspector directly.
- Search counts and page ranges use atomic status announcements. Keep ordinary
  inspector content out of live regions to avoid reading long records repeatedly.
- Preserve native table captions, column headings and `aria-sort`. Scrollable
  tables are keyboard reachable. Paging controls expose names and disabled state.
- Distinguish decorative dividers from control borders. Test both themes for
  4.5:1 normal text and 3:1 control/focus contrast. Never encode state only by colour.
  Support forced colours, reduced motion, narrow screens and coarse pointers.

Each new catalogue story must cover names, roles, states, relationships, keyboard
order, focus recovery, empty/error/loading/success states and non-colour cues.
Behaviour tests enforce representative semantic contracts; browser checks verify
actual focus, Enter/Space activation, reflow and visual states.

Current evidence: automated behaviour tests and browser checks, plus token contrast
calculations. Outstanding before any conformance claim: an automated accessibility
scanner across all stories/states, VoiceOver/Safari and NVDA/Firefox walkthroughs,
200% text resize and 400% zoom, OS forced-colour checks, and disabled-user testing.
Authentication, custom customer compositions and future dialogs need independent
assessment. An accessible primitive does not certify a complete workflow.

Reference: [W3C WCAG 2.2](https://www.w3.org/TR/WCAG22/).

## Exploring components

Open `/dev/catalogue/graph`. The grouped library lists individual controls,
patterns, compositions and the receiving blueprint. Each entry has a live example,
plain-language purpose, usage guidance and accessibility behaviour. “Uses components”
links traverse its ingredients; “Used by” links traverse the reverse relationships.
The query parameter `node` makes each entry directly linkable and supports browser
Back/Forward. Unknown identifiers safely fall back to foundations.

Composition previews reuse the working receiving, stock and task stories. Labelled
“Explore” links identify their regions without hijacking the normal controls.
Primitive previews cover representative states: primary/secondary/disabled buttons,
input validation, status tones, notices, sortable and selectable tables, density,
pagination and optional photos. The page theme switch applies to every example.
Not every possible component state is demonstrated yet.

Previews share session-local sample state, so stock filters and receipt changes
carry across related entries. Refresh resets that state. Component navigation
moves keyboard focus to the new heading; all relationships are real links rather
than pointer-only graph edges. Registry and composition changes should land together
so the dependency view continues to describe what is actually demonstrated.

## Domain and presentation contracts

The Domain section explores primitives, composed values and business entities
from the versioned blueprint snapshot. Field links lead to their types; reverse
links show where a type is used. Visual components link to business bindings, and
entities link back to the controls that present or manipulate them. The blueprint
page includes both sets of objects and their bindings.

Inventory-item identity is separate from stock position at a location. Quantity
pairs value and unit; availability is derived from on hand minus reserved. The
inventory selector uses the item ID as its selected value and includes SKU,
availability, on-hand stock, unit and location in the native option label. Search
limits the matching options to 25 while retaining the current selection. These
are synthetic snapshots, not stock reservations or guarantees of availability.

Bindings distinguish selection of view state, read-only presentation and command
input. The receiving command accepts quantity and reference and applies existing
receiving rules. The model documents decimal/unit intent; the demonstrated receipt
still accepts whole units only. There is no generic model interpreter, generated
persistence, arbitrary field mutation or live query binding in this increment.

`Shop.Catalogue.Domain` reads only the carried blueprint. Bedrock's canonical
source is `blueprints/receiving.v5.json`; the snapshot includes its SHA-256 digest.
Domain definitions and bindings must remain consistent with executable examples.
Tests check reference integrity, field paths, presentation targets and navigation.

## Calendar values and event times

The domain explorer includes dates, local times, time zones, timestamps,
durations, date ranges, scheduled windows, appointments and stock movements.
Their presentation links lead to native controls and working compositions.

Calendar dates do not acquire a time zone. Exact events resolve a local date/time
and IANA zone to UTC. Date filters include both selected dates in the displayed
zone. Scheduled windows exclude their end, so adjacent bookings are permitted;
overlapping Crew A bookings are rejected. Overnight windows are supported and
duration measures actual elapsed time across daylight-saving changes.

Receiving asks when the delivery occurred; recording time is assigned separately.
The movement history combines synthetic receipts/transfers with receipts entered
in this session. Its date filter follows occurrence time. Invalid filters retain
the last valid results with an explicit notice.

The `tz` dependency supplies bundled IANA rules through the explicit
Tz.TimeZoneDatabase provider.
No background updater or external service is configured. Dependency maintenance
must refresh these rules. Missing and repeated local times return field errors;
choosing the earlier/later occurrence is not implemented. Recurrence, persistent
bookings, transfer commands and multi-user resource scheduling remain future work.

Controls retain native keyboard behaviour, fieldset legends, explicit labels,
linked error messages and invalid-submit focus recovery. Rendered event times use
semantic `time` elements with ISO timestamps.

## Design model contracts

The Model section connects intent, domain meaning, behaviour and presentation
through typed relationships. Follow both incoming and outgoing links, then open
a domain sample or working component. Namespaced identities preserve concept
identity across different kinds. Unknown links fall back to the Actor overview.

Bindings distinguish read projections, command inputs and view-state changes.
Command metadata states authority and transaction limitations; it does not execute
commands. Domain fields expose requiredness, value source and reference cardinality.
Composition contracts name their interaction, regions, state, outputs, recovery
and remaining gaps. The version 4 composition list matches all executable examples.

The component registry remains the source for visual-use relationships. The
blueprint owns its conceptual relationships. Reference and behavioural tests
protect their agreement; a navigable model is not proof of production correctness.

## Actor Journey traces

The Model page leads with Actor, Goal, Interaction, and Journey. Select one to
trace the Journey's ordered stages, performers, completion conditions, and context
passed onward. Each stage renders its working composition inline with shared
session state.
Component breakdowns, domain bindings and standalone links are expandable details.
The previews link back to the Journey. Supporting design concepts remain available
in a separate disclosure.

Blueprint version 5 makes these stage relationships explicit. The warehouse sample
progresses from finding stock to recording a delivery and reviewing movement history.
Its fixed MAT-112 order does not follow arbitrary item selection; the stage handoff
explains that boundary. Trace navigation preserves the current LiveView session.

Recording a receipt inside the Journey updates both the stock composition and
movement history without navigation. Stock tables scroll within their stage.
The inline examples reuse the standalone composition implementations and retain
unique control IDs, labels, validation and focus behaviour.

## Website enquiry Journeys

The `website-leads.json` snapshot adds prospective customer and office staff Actors,
their Goals, four Interactions, and two Journeys. The customer Journey renders the
public website, enquiry form, private enquiry queue, and follow-up composition
inline. The staff Journey starts at the queue. Each stage names its performer and
states what is carried forward; the protagonist and performer can differ.

`Shop.Catalogue.Enquiries` keeps up to 50 synthetic enquiries in session state.
Submitting the form adds a Lead to the queue and selects it for follow-up. Selection
changes view state only. Saving follow-up preserves the original public request,
updates status and private notes, and records the first saved follow-up time. No
action persists data or sends messages. Both input paths reuse `Shop.Leads.Lead`
changesets. Reloading clears the sample state.

The model and domain explorers combine both blueprint snapshots, sharing primitive
references without duplicating nodes. Multiple related Journeys offer a choice but
render only one trace, preventing duplicate form IDs. Public/private markers explain
the real authentication boundary; this development catalogue is not that boundary.
The canonical source is `bedrock/blueprints/website-leads.v1.json`,
accompanied by a
source SHA-256 in the starter snapshot. Bedrock's worked example documents the
portable Epilogue Tracker model and the mapping to the current Lead schema.

Semantic and behaviour tests cover validation, shared state, field protection and
unique IDs. Browser verification covers keyboard submission, error focus, selection
and staff follow-up. Full assistive-technology review is still required.
