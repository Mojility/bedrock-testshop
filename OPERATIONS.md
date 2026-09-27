# Staff operations design

Staff should recognize how to work on a new capability from the ones they already
use. This design belongs to the customer application, alongside its public website
design. It is conventional Phoenix source, with no management-platform runtime
dependency. Public scenes continue to use the website component graph described
in WEBSITE.md; authenticated workflows compose typed Phoenix components.

## Component hierarchy

| Layer | Owner | Contract |
| --- | --- | --- |
| Foundations | `assets/css/app.css` | Semantic colours, supported light/dark themes, typography, spacing, focus and motion |
| Controls | `ShopWeb.CoreComponents` | Labelled inputs, buttons, icons, validation and flash feedback |
| Workflow components | `ShopWeb.Operations` | Page header, panel, status, empty state, form actions and labelled facts |
| Staff shell | `ShopWeb.Layouts.app`, `ShopWeb.StaffNavigation` | One navigation registry, current location, account controls and responsive content width |
| Pages | Staff LiveViews | Compose the patterns, own form state and invoke authorized business contexts |
| Business rules | Contexts and database | Permissions, validation, relationships, concurrency, transactions and audit history |

Add or extend a shared component when several workflows need the same interaction.
Do not clone styling into each new page. Attributes and slots are the composition
contract; avoid a generic form engine that infers business rules from database
columns. The website's atoms-to-compositions principle applies, while staff
interaction state and authorization remain explicit application code.

## Existing components

Use `alias ShopWeb.Operations` in the page and keep `Layouts.app` as its outer
wrapper. Pass `current_scope` and a `current_section` matching the navigation ID.
Leads and Team are executable examples.

- `Operations.page`: one page title, short purpose, optional action slot, content.
- `Operations.panel`: a labelled group with a heading and optional actions.
- `Operations.status`: a readable business label; tone is supplementary to text.
- `Operations.empty_state`: explains absence and an optional next action.
- `Operations.form_actions`: consistent save/cancel placement with optional help.
- `Operations.facts`: semantic labelled values for record details.

Use existing core fields and buttons inside these patterns. One primary action
per task group; secondary links and destructive actions must be distinct. Preserve
submitted input on validation failures. Show in-progress submission text and
prevent duplicate effects in the business context, not just by disabling buttons.

The first component set does not implement a generic search/pagination engine or
history store. Build the following patterns from real workflow requirements and
extract shared components as the second concrete use establishes their contract.

## Page patterns

**List and search.** Page title and purpose, one create action where permitted,
labelled search, active filters and reset, sort, bounded results and navigation.
Distinguish no records from no matching records. Show the result scope when a list
is capped. Preserve filters and position when returning from details. Use tables
for comparison, record cards for work needing several actions or longer prose.
Never put buttons inside a clickable row; provide a clear record link.

**Record detail.** Back to the originating list, record identity and status,
labelled facts grouped by meaning, related records, actions and history. Show
units, currency and time zone. Do not expose raw internal identifiers by default.

**Create and edit.** Clear title, grouped labelled fields, visible requirements,
field errors and an error summary when needed, save and cancel in a stable place.
Retain values after failure; report concurrent-edit conflicts without overwriting
another person's changes. Explain irreversible effects before confirmation.

**History and corrections.** Authorized users see who did what, when and why.
Show corrections as corrections, preserving the original entry. Use a ledger or
event-sourced aggregate when balances must be reconstructed; ordinary descriptive
records may use transactional audit history. Do not display secrets or unnecessary
personal data. Presentation components do not establish audit integrity.

## Definition of a completed increment

Every completed iteration is eligible for owner acceptance, subject to fresh
release verification against the live system. There is no lower-quality prototype
or later hardening phase. Reduce scope rather than leaving a half-working path.
Keep all quality gates active, including tests, security and integrity checks.
A failing gate means unfinished work, not a completed iteration with a caveat.

Verify navigation to the feature, the permitted person's complete workflow,
validation recovery and denied access. Test relevant concurrency, duplicate writes,
exact quantities and money, existing-record upgrades and consequential history.
Use synthetic fixtures. Keep operational data out of source, logs and CI.

Review narrow and wide layouts, keyboard use, focus visibility, labelled controls,
empty/loading/error/success/conflict states, and both supported themes. Use the
shared semantic colour roles and spacing scale. Text needs sufficient contrast;
status must never rely on colour alone. Keep frequent controls comfortably tappable.

A passed automated gate establishes only what it measured. It does not establish
that the owner accepts the behavior or that a release is deployed. Record any
unverified UI or business assumption explicitly, and resolve required gaps before
claiming the iteration complete.
