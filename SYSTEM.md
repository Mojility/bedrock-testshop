# TestShop's system

This document describes the system as it is now. Bedrock's generators keep
it current: every change that adds, removes, or moves something updates
the sections below in the same commit.

## What it is

A Phoenix 1.8 application (Elixir, LiveView, Ecto on PostgreSQL) in this
repository, built to how TestShop works. It runs as one container
from the `Dockerfile` here, in front of one PostgreSQL database.

## What it contains

- **Business identity** (`priv/business.json`, optional authored input): a JSON
  string under `name`, loaded by `config/runtime.exs` into the configuration read
  by `Business.name()`. Environment precedence is `BUSINESS_NAME`, then `SHOP_NAME`,
  then the data file, then the baked `config :business, :business_name`. Legacy
  systems without the file retain their names. Page titles, header, holding page
  and email consumers share this resolved name; generated names never enter
  executable source. The file ships in releases and is separate from scene
  publication. See `README.md` for the input and startup failure contract.

- **Accounts** (`lib/business/accounts/`): who can sign in. Sign-in is by
  magic link sent to the account's email; there are no passwords. A user
  may change their own email from Settings. Tables: `users`,
  `users_tokens`. Owner and staff access is invitation-only; see `BUSINESS.md`.

- **Website** (`lib/business/website/`, `lib/business_web/website_html.ex`): renders a
  versioned scene from `priv/published_site/scene.json`. The renderer and
  component model belong to this repository. Public content can come from this
  application's database through `Business.Website.Content`. See `WEBSITE.md`.
  Before publication, the holding page accepts the same validated enquiries.
  Its shared controls retain invalid input and focus the first error. Keyboard,
  contrast and mobile reflow checks cover both themes in Chromium;
  assistive-technology walkthroughs remain outstanding.
  Publishing updates scene/assets; it never replaces component implementations.

- **Leads** (`lib/business/leads/`): one record represents a customer enquiry,
  whether submitted publicly or recorded by staff from a phone call or email.
  Authenticated staff follow up at `/app/leads`; staff-recorded leads capture the
  needed work, location, requested date and waiting/booked/declined status, while
  `/app/enquiries` provides the weekly workload view. Pending public-lead email
  notifications retry independently. `/app/team` lets the owner invite staff and
  revoke access. Tables: `leads`, `lead_history`.

Private photographs are served from this application's Canadian S3 bucket.
The runtime reads short-lived credentials from `AWS_CREDENTIALS_FILE` on each
request. The host renews that file. Only explicitly configured proxy addresses
may supply the visitor address used by submission rate limits. The health
endpoint checks both the application and its database. Authenticated previews
use short-lived, signed photograph links so a draft can include photographs
that have not yet been published.

## How it is deployed

Every push to `main` runs the [quality checks](guides/quality.md),
builds an ARM64 container, and pushes
an immutable commit SHA tag to ECR. Roost deploys the image by digest after
Bedrock verifies the build and rehearses it against a private database copy in
Canada. Roost runs `/app/bin/migrate` before `/app/bin/server`; the server does
not repeat migrations on restart. Caddy terminates TLS.

`.tool-versions` states the Elixir, Erlang/OTP and PostgreSQL versions. CI
reads it, and the `Dockerfile` defaults must match it. Bedrock keeps them and
the dependencies current by dispatching `.github/workflows/maintenance.yml`,
which applies a baseline with `scripts/maintenance/apply_baseline.exs`, runs
the quality checks, and pushes a `maintenance/<id>` branch. It never deploys.
See `docs/maintenance.md`.

The standalone CloudFormation recipe uses an ARM instance in ca-central-1 and
requires an explicit commit image tag and exact main-branch CI identity. ECR
tags are immutable; the first start resolves the tag to a digest saved in
`/opt/business/image`. Restarts use that selected digest. Both
the runtime and infrastructure reject a non-Canadian AWS region. Its container
entrypoint runs migrations
before starting. A trusted deployment operator establishes the first owner with
`Business.Release.bootstrap_owner/1`; no public account bootstrap endpoint exists.

## Where its data lives

All business records live in this system's PostgreSQL database. Roost's isolated
pilot uses a dedicated database container on a Canadian host; standalone uses
the RDS instance created by `infra/standalone.yaml`. Photographs live in the
customer's Canadian S3 bucket. Back up both the database and photographs.
Customer records and runtime secrets are never committed to this repository.

Hosted secrets are protected host files. Runtime containers receive their own
database credentials, session secret, optional preview credential, and scoped
short-lived AWS credentials; they receive no fleet management credentials.
Standalone secrets are owned by the deploying account. SES delivery remains
subject to that account's Canadian-region sending permissions. Set
`LEAD_NOTIFICATIONS=false` and `MAIL_ADAPTER=disabled` for an isolated rehearsal.
The disabled adapter neither delivers nor logs message contents, even when a
credential file is present. Rehearsal credentials must also deny SES delivery.

## Isolated exploration mode

The application can run against a temporary database copy with
`CUSTOMER_EXPLORATION=true`. This mode uses PostgreSQL peer authentication for
local user `developer`, database `exploration`, and socket `/var/run/postgresql`.
It ignores production database, mail, and cloud credential configuration.
Set `EXPLORATION_HOST`, a new private `SECRET_KEY_BASE`, and the exact HTTPS
`EXPLORATION_PARENT_ORIGIN`; optionally set `EXPLORATION_MEDIA_ORIGIN` to the
existing public media origin. Only already published image paths are reused.
Media files are not part of the database checkpoint in this initial mode.

Boot with `PHX_SERVER=true MIX_ENV=prod mix phx.server` after compilation and
asset preparation. A private authenticated gateway is required: this mode
allows a local owner sign-in to the copied system, and must never be enabled on
an internet-accessible production server. Session cookies are host-only,
Secure, SameSite=None and Partitioned; frame ancestors allow only the configured
parent and optional `EXPLORATION_PLATFORM_ORIGIN`, an explicit HTTPS origin for
the platform console. No wildcard ancestors are admitted. Mail delivery is
disabled. The application has no management-platform runtime dependency.

With the server running, execute the actual smoke suite using the same isolated
configuration and `PHX_SERVER=false MIX_ENV=prod mix run --no-start scripts/smoke.exs`.
It checks readiness, public pages and CSS, protected staff access, CSRF denial,
a synthetic enquiry write with its contact and request fields, and authenticated
staff reading. CSS checks request the original URL, including digest query strings,
and require a nonempty `text/css` response. CSRF denial must leave no enquiry.
It also verifies retained enquiry fields, timestamps, source and follow-up without
updating them. `SMOKE_EXISTING_LEAD` can supply the expected synthetic record as
JSON; without it, smoke creates and cleans a synthetic retained record itself.
It deletes only its own test user, tokens and enquiries in cleanup; an externally
seeded retained record remains intact. It refuses production mode and non-loopback
HTTP targets. Failures report only a fixed check name or `unexpected_failure`;
exception messages and customer details are never printed. Passing compilation
alone does not establish database compatibility; this suite exercises the
selected source and copied schema without migrations.

`python3 scripts/qualify_release.py` is the starter-owned runtime v1 release
acceptance gate. `.github/workflows/build.yml` runs it in `release-acceptance`
against its pinned PostgreSQL service and exact `.tool-versions` Elixir/OTP;
image build/publication requires both this job and `quality`. Trusted pushes
and manual runs also start `.github/workflows/starter-platform.yml` in this
starter. It uses ordinary jobs and public actions: private platform sources are
checked out at runtime only after the starter repository guard passes. The jobs
run the shared Bedrock integration scripts on the resolved sources and preserve
all active validation in the nonpublishing shared producer (Bedrock commit
`78767528c45c0d9412c4cbc90d395c724ed1c5ee`, byte-identified by
`test/fixtures/integration-producer.yml`). Only inactive Bedrock image publication
steps/outputs are omitted; integration's exact OTP is aligned to this project's
existing `29.0.2` pin. When changing the shared producer, deliberately review and
port its validation changes here; the regression test detects local drift.

The ordinary integration jobs resolve all four sources, check Bedrock/Roost,
validate/build Workshop, build/validate the Bedrock image, and require every
result to succeed. Only then does `publish-starter` call the **local** `build.yml`
with `starter-publication: true`. That call runs the unchanged quality and
release-acceptance gates before building/pushing the immutable ARM64 starter
image. Direct starter runs leave that input false and cannot build an image.
Quality/release checks therefore run both directly and in the gated call; this
keeps one authored build/publish implementation and avoids cross-run receipts.
Customer pushes/manual runs build/publish after their own quality and release
checks, without platform keys. No private reusable workflow is resolved at load
time, even if a customer still has the starter-only file: its root jobs skip,
and dependency-bound jobs follow them. No platform repository is publicized.

`.bedrock/starter-only.json` is a versioned JSON object:
`{"version":1,"paths":[".github/workflows/starter-platform.yml"]}`.
Paths are repository-relative files that **must not exist** in a generated
customer system. Bedrock generation and every reset must remove the listed
paths; the producer change remains pending in `docs/owner-journey-findings.md`.
The manifest itself may remain as metadata. Tests check customer workflow load
safety, producer validation parity, unchanged quality/release checks, and the
publication graph over event, cancellation and dependency-result combinations.
These local checks do not establish a successful hosted GitHub run.

The release acceptance gate assembles
deployed assets and `mix release` from an isolated baseline archive plus the
identified candidate changes, then executes the artifact's `bin/migrate` and
foreground `bin/server`. It verifies ordinary startup leaves an empty database
unmigrated, migrations create the business tables, `PORT` selects the listener,
and readiness changes from HTTP 200 to 503 when real database access is revoked.
The complete gate seeds a retained synthetic enquiry before port-4000 startup
and executes `scripts/smoke.exs` using the artifact's own code in a separate
release-eval observer. That observer alone receives the isolation permission;
the release server never receives `CUSTOMER_EXPLORATION` or patched runtime
configuration. Messaging is disabled through the existing rehearsal configuration.
The observer checks persisted contact, request, source, timestamps and follow-up
as well as staff HTTP reads, enquiry writes, deployed CSS, CSRF denial and
magic-link authentication. The shared port lock stays held until all owned
listener processes stop; synthetic databases and snapshots are removed on
success, failure and signals. CI preserves server logs as a workflow artifact.

`--proof` runs only the smallest readiness/migration boundary; CI never uses it.
`--release /path/to/artifact` qualifies an already assembled artifact for
regression experiments; the default command builds the candidate itself.
`scripts/verify_release_regressions.py --release /path/to/artifact --case readiness`
replaces the readiness BEAM only in a disposable copy; `--case smoke` empties
deployed CSS there. Both commands deliberately exit nonzero through the real
gate, with normal cleanup. The dated release record under `docs/` and
`.foundry/proof.json` distinguish these experiments from the corrected build.
`scripts/verify_release_cleanup.py --release /path/to/artifact --signal SIGTERM`
(repeat with `SIGINT`) pauses its own real BEAM listener, signals the runner,
and observes lock retention, whole-group termination and database/snapshot removal.
Every server probe, including a dynamically selected port, holds the shared lock
to prevent default release node names colliding on the workstation.
This gate proves local release behavior, not ARM image equivalence, hosted TLS,
scoped database roles, public HTTPS, current customer data or deployment.
The Canadian workstation has PostgreSQL 16; CI continues to use pinned 18.
This difference is not evidence of a hosted workshop mismatch. At the immutable
caller trunks inspected on 2026-10-01, Bedrock integration and Roost CI select
16, while Roost's committed guest qualification and RDS maintenance records
report 18.6. Roost's immutable guest profile owns the runtime major and its
executor rejects a different server major before restore. Preserve this starter's
18 pin; aligning caller CI belongs to the Bedrock and Roost maintainers.
The standalone local Compose declaration still selects 16; it was not changed
as part of the workshop ownership finding. No hosted configuration was queried
or changed. See `docs/owner-journey-findings.md` for ownership and
`docs/postgres-contract-2026-10-01.md` for dated evidence.

`scripts/qualify_callers.py --bedrock /path/to/clean/bedrock-trunk` is the executable
starter preparation contract. It reads Bedrock's actual Bootstrap and Preparation
modules, builds disposable source snapshots in dev/test/prod, exercises dependency
preparation and promotion, then runs the production compile, service and smoke
commands against unpublished and compatible synthetic published states. Git source
acquisition is represented by an exact-baseline archive plus this worktree's source
changes; sandbox paths and the local database role are remapped only in the proof
snapshot. Application builds and asset deployment remain real. The fixture hash
is checked as supplied, never replaced. `scripts/qualification_seed.exs` records a
synthetic enquiry before startup; both states verify the same record through staff
HTTP reads and exact database field comparisons. This proves enquiry capture and
staff access, not email delivery or completion of the customer's service request.

The runner holds `/tmp/bedrock-port-4000.lock` until the listener's
process group stops, uses a unique local synthetic database, disables messaging
and provider credentials, and removes the database and snapshots on success and
failure, SIGINT and SIGTERM. Interrupts unwind owned command groups; cleanup
is protected from further interrupts. Default capture and service logs live
outside the repository under `~/.foundry/tool-logs/`; `.foundry/proof.json`
links the review evidence. `scripts/verify_qualification_cleanup.py --bedrock
/path/to/clean/bedrock-trunk --case sigterm` (repeat with `sigint`, `failure`,
and `success`) observes real child/listener termination, database/snapshot
removal and shared lock ownership. The observer allocates a private `/tmp` snapshot parent and passes
it with `--snapshot-parent`; discovery and rescue cleanup stay within that
parent. Its signal cases pause the real BEAM to force shutdown escalation;
its command-failure case removes disposable deployed CSS before actual smoke.
`--proof` runs the smaller prod-only boundary probe before the full preparation qualification. Runtime defaults
and exploration's existing local-owner sign-in remain unchanged. Negative HTTP and
database regressions live in `test/business/smoke_contract_test.exs`; sanitized dated
run evidence belongs in `docs/`. Local proof does not establish hosted isolation,
current customer-data compatibility, public HTTPS readiness or deployment acceptance.

`python3 scripts/qualify_callers.py --list-checks` describes the full qualification
without requiring `--bedrock` or performing source acquisition, builds, database,
network, listener or snapshot operations. Add `--proof` to describe the smaller
prod-only, unpublished probe: it omits dev/test preparation, cached preparation,
the published state and the pre-start retained seed (smoke still checks its own
synthetic retained enquiry). Both execution paths still require `--bedrock`.
Discovery is an inventory, never passing behavioral evidence. Run
`python3 scripts/verify_caller_discovery.py` for real CLI regressions that deny
child processes, network and filesystem mutations while checking both inventories
and the execution source requirement.

`scripts/qualify_workshop.py --workshop /path/to/committed/workshop-archive
--workshop-revision <full-sha> --workshop-repository /path/to/workshop-git
--bedrock /path/to/committed/bedrock-archive --bedrock-revision <full-sha>
--bedrock-repository /path/to/bedrock-git --starter-revision <full-sha>` owns
starter compatibility qualification of Workshop's completion gates. It executes the supplied Workshop's `Contract`, `Runner.check`,
`Command`, journal, broker command/environment constructors, forced compilation,
coverage wrapper, protected audit helpers and asset boot. The candidate is an
unchanged committed starter archive; tracked source and `mix.lock` are compared after
execution. The command exits unsuccessfully on a caller gate
failure as well as a starter failure; caller defects are recorded for their owner.
`scripts/check_workshop_boundaries.exs`, executed inside that Workshop snapshot,
checks actual rejection of executable HEEx platform calls and removal of a
retained test, then acceptance of explanatory prose and the restored test.
The smoke regression fixtures resolve runtime `priv` through `Application.app_dir/2`
so the protected coverage build exercises real HTTP without writing source assets.
An independent HTTP probe verifies isolated-owner login, a stored owner session
and retained enquiry reading. LocalSmoke runs independently on a separate
disposable copy with only its local database role/name remapped, keeping the
protected candidate untouched.

The runner uses two unique synthetic databases, seeds the retained enquiry before
startup, disables mail, holds the shared port lock through process-group shutdown,
and records source hashes, executed argv, outcomes and cleanup in `.foundry/workshop.json`.
Final Workshop cleanup defers the first SIGINT or SIGTERM until owned process
groups and both databases are removed, before releasing the port lock. Snapshot
removal is independently protected. `scripts/verify_workshop_cleanup.py --stage
shutdown` (also `--stage database`, with `--signal SIGINT` or `SIGTERM`) executes
the exact finalizer in its real lock and snapshot contexts, using a real listener
and unique PostgreSQL databases. Its database case pauses a transparent launcher
before exec of real `dropdb`; it does not replace cleanup outcomes. Independent
observations precede any observer recovery. This probe isolates final cleanup;
the full Workshop qualification separately verifies completion behavior.

Workshop qualification resolves each caller commit through its read-only Git
object store and compares every committed archive file before execution and after
snapshot cleanup, including failed runs. It records the initial manifests before
building. The candidate is extracted directly from the requested starter commit,
without copying worktree changes; its archive SHA-256 and every committed file's
SHA-256 are recorded and checked afterward. Canonical derived guidance retains
its producer's provenance separately. A supplied revision label, advisory
revision or matching command text is not accepted as proof of source identity.
The external boundary probe rejects an executable HEEx platform call and accepts
explanatory prose through the current Workshop Runner. Historical proof remains
under `.foundry/`; the current source revalidation is described in
`docs/workshop-source-revalidation-2026-10-01.md`.

Detailed caller artifacts remain in the external tool-log directory. A permitted
Bedrock `git archive HEAD` snapshot can be supplied to preparation qualification
with `--bedrock-revision <full-sha>`; the invoker records the archive identity.
This Canadian workstation exercises real commands, HTTP, database and local login
behavior. It does not establish the installed broker's sudo authorization,
systemd filesystem sandbox, read-only source mount, guest user separation,
network/proxy isolation, cgroups, resource limits or lifecycle lease enforcement.
Workshop's omitted packaging guidance is hydrated from canonical committed
Bedrock bytes and the public Phoenix profile using its producer's validation,
provenance and check functions; the resolved revisions and hashes are recorded.
The dated Workshop run record in `docs/` separates these limits from verified
behavior and from owner acceptance or deployment.

## Staff operations design

`OPERATIONS.md` defines the shared staff-page patterns and quality standard.
`BusinessWeb.Operations` provides typed presentation components; `StaffNavigation`
owns the visible destinations. Leads, Job enquiries and Team use the shared shell
and components. Authorization, validation and business writes remain in contexts.

## Development component catalogue

`/dev/catalogue` is available when `dev_routes` is enabled, including local
development and test builds. It is absent from production routes. It uses the
browser pipeline and existing `current_user` LiveView session, with no requirement
to sign in because every example uses synthetic state and performs no database
writes or external actions. The normal staff authorization routes are unchanged.

The catalogue demonstrates the Workbench visual conventions, controls, composition
dependencies, and a materials-receiving blueprint. Sample receipts and field checks
last only for the current LiveView; refreshing resets them. Production inventory
behaviour, durable receipts, and cross-user transactions are not implemented.
See [the catalogue guide](CATALOGUE.md) for running and extending it.

The catalogue also demonstrates temporal domain types, zoned receipt entry,
date-filtered stock history and a session-local crew schedule. The `tz` package
provides bundled IANA time-zone rules, used explicitly by `Business.Catalogue.Temporal`;
there is no automatic network updater. These examples add no business tables or
production scheduling capability.

The catalogue's Model section explores typed design relationships across actors,
goals, capabilities, domain concepts, commands, projections, bindings and visual
components. Receiving blueprint version 4 carries composition contracts and
explicit binding effects. This metadata is descriptive; it does not interpret
commands or replace application authorization and validation.

The catalogue also traces an Actor's Journey through ordered Interactions and the
compositions used at each stage. Version 5 records the Journey Actor and Goal,
separate stage performers, completion conditions and context passed onward.
This is navigable design intent, not a runtime workflow engine.

Journey stages render working compositions inline. A shared LiveView state feeds
stock, receiving and movement history, so changes appear across stages without
leaving the Journey. Standalone exploration remains available in expandable details.

The development catalogue also demonstrates website enquiries across prospective
customer and office staff Journeys. `priv/catalogue/website-leads.json`
carries the
portable product model, Lead/contact concepts, bindings and composition contracts.
The catalogue combines this with the receiving snapshot and reuses shared domain
primitives. Inline public-form, queue and follow-up previews share bounded synthetic
session state through `Business.Catalogue.Enquiries`. They reuse Lead changeset validation
but never call the repository or notifier; real staff authorization remains in
`Business.Leads`. No customer application is replaced or upgraded by this example.
