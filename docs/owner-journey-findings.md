# Owner Journey caller findings

## 2026-10-01 — PostgreSQL major ownership (caller CI coverage)

For `bedrock.actor.field_service_owner` pursuing
`bedrock.goal.own_business_system` through
`bedrock.interaction.open_workshop_promptly`, preserve the starter's PostgreSQL
18 pin. **Named owners: Bedrock integration CI and Roost CI maintainers own the
remaining 16-versus-18 qualification mismatch; Roost's immutable guest profile
owns workshop runtime selection.** CI versions do not establish hosting versions.

Immutable archived trunks (HEAD equalled local `origin/main` at acquisition):
Bedrock `c87fbdbe7213546445340140a464ccff478bba70`, Roost
`bb57e6d0bf2bff3af72d40ad9adb5fa7c34d81b8`, Workshop
`96dcc50c5015a9986f7d7573c0be9b698baf27c4`. These are local committed trunk
identities, not a fresh remote or live-host observation.

Bedrock `.github/workflows/integration.yml:86` selects `postgres:16` and line
170 installs `postgresql-16`. Roost `.github/workflows/check.yml:16` selects
`postgres:16` and line 41 installs `postgresql-16`. In contrast, Roost
`docs/development-environment-qualification.md:10` records the workshop AMI's
PostgreSQL **18.6**; lines 134–136 identify its successor image and reuse of
that qualified toolchain. `priv/cell/environment_guest.py:65` queries
`SHOW server_version_num` and lines 67–68 reject a major different from the
immutable profile before restoring a database. `infra/environments/install.py:76`
requires `postgres_major` in the operator-supplied profile; it does not derive
it from the starter or CI. `priv/cell/environment.py:116` provisions the
operator profile's `image_id`. The same Roost trunk's
`docs/postgresql-18-maintenance.md:5` records the shared RDS upgrade to **18.6**;
`priv/cell/runner.py:363` separately pins the RDS export/rehearsal image for 18.
The unbound `POSTGRES_IMAGE` digest at line 362 is a separate path; its major
was not resolved or run here.

Practical consequence: the shared owner-journey CI proves PostgreSQL 16 behavior,
not the recorded workshop/RDS major. No evidence supports downgrading newly
generated systems or changing existing runtime obligations. The smallest owning
correction is for Bedrock and Roost to align their CI service and isolated-test
tool packages with the qualified 18 profile, then rerun their real integration
and database-boundary checks. Those sibling changes are outside this task.
No current hosted major or successful 18 execution is claimed by this finding.

The starter controls `.tool-versions:3` and its own CI reads that pin; it does
not provision the workshop guest. Its local `docker-compose.yml:18` still names
16, a separate local-running declaration. Changing that configuration or its
retained volume is outside this ownership correction; it is not evidence of
the hosted workshop version.

See [the dated sanitized record](postgres-contract-2026-10-01.md) for exact
reproductions, source hashes, local observation, gates and cleanup.
`.foundry/proof.json` records a direct acceptance probe for this documentation
objective; earlier caller behavioral proof is retained separately. The finding
closes the starter decision and leaves the named caller CI correction open.

## 2026-10-01 — starter preparation contract

Owners inspected: Bedrock's `Bedrock.Explorations.Bootstrap` and
`Bedrock.Explorations.Preparation`, at trunk
`6fc8d8eda5806ddbfe9f271699bc67e45ad8cf70` and the final run at
`aaec254d96299f17c4a846a2dc04e5d1f068d15b` (unchanged preparation-module hashes).

No caller-owned blocker has been confirmed in the local contract checks.
The confirmed digested-stylesheet false rejection and missing enquiry-field
checks belong to the starter's `Business.Smoke`; they are corrected here with
rejecting and passing boundary evidence. The snapshot-copy and port-preflight
failures belonged to the new qualification harness and were corrected here.
No sibling or caller source was edited.

[The dated run log](caller-qualification-2026-10-01.md) records exact commands,
source identities, reproductions, ownership, smallest source corrections and
limits. The [reconciliation record](caller-reconciliation-2026-10-01.md)
supersedes the original signal/lock and marker-based negative claims. Its final
full run uses clean committed Bedrock main
`12d15697b629235d7c4bfeaf4753ff2f899a1ed5`, with unchanged producer module hashes.
`.foundry/proof.json` links the current rejecting and passing boundary runs.
These local results do not establish hosted isolation, production-data upgrade
compatibility, owner acceptance or deployment. Those are evidence gaps, not
fabricated caller blockers.

## 2026-10-01 — current Workshop completion boundary

Workshop source: `9bfe35ffc6cca45fc83d260193208d44fd934cc7` (HEAD and
`origin/main` agreed when the permitted archive was taken). Bedrock source:
`12d15697b629235d7c4bfeaf4753ff2f899a1ed5` (also matched `origin/main`).

The real 14-gate run exposed two starter-owned failures. The blueprint sentence
at `lib/business_web/live/catalogue/blueprints.html.heex:58` tripped unchanged
`WorkshopExecutive.Source.separation` because it ended in `Bedrock.`. Rewording
the prose is the smallest correction; no platform-reference gate was weakened.
The actual protected coverage wrapper then failed 11 smoke regressions because
`test/business/smoke_contract_test.exs:9` wrote source `priv` rather than the
runtime test-build `priv` copied by Workshop. Resolve those synthetic fixture
paths using `Application.app_dir(:business, path)`; retain every assertion.

Exact executing command, argv, output and rejecting log are in
[the dated Workshop qualification record](workshop-qualification-2026-10-01.md).
The rejecting packaged run executed all 14 gates: coverage failed with exit 2;
the other 13 passed. Its overall exit was 1, source and lock were preserved,
and both databases, all owned listeners and the candidate snapshot were removed.
No caller-owned failure is confirmed by these outcomes. Missing derived guidance
in a bare archive and the workstation's unwritable default Hex home were harness
setup responsibilities, corrected without sibling edits. Installed guest
isolation remains outside this workstation's proof boundary.

The corrected run exits 0 with all 14 gates passing, runtime-fixture coverage
94.11%, independent local boot/smoke, isolated owner session creation and
retained staff reading verified. Final source and lock preservation and cleanup
passed. The dated record identifies exact logs and the guest boundaries still
unverified; no confirmed caller-owned blocker requires a sibling correction.

## 2026-10-01 — interrupted Workshop final cleanup

The defect belongs to this starter's `scripts/qualify_workshop.py`: its normal
final cleanup could receive a first signal while stopping a process group or
removing databases. `callers.interrupted` then raised `SystemExit`, bypassing the
remaining cleanup and unwinding the port lock. The smallest correction defers
SIGINT/SIGTERM around the entire finalizer using the existing signal-mask context;
snapshot removal keeps its separate protection. No caller source changes are
required. The real listener and database red/green evidence, updated caller
identities, limits and resource cleanup are recorded in
[the correction record](workshop-cleanup-correction-2026-10-01.md).

## 2026-10-01 — Workshop source-drift revalidation

Current committed Workshop trunk is
`6dc82a749f77548ed5488b7fa25d303d0c655795`; the cycle-4 recorded source hashes
still match their earlier declared commit, but twelve recorded executable paths
have changed in today's caller. Current Bedrock committed trunk is
`426ba1ba37c550a4fc793e598bb984d8b8a817b2`. The unchanged starter candidate is
`7d102f2d760e1d4be07195f17910e2d41e35ec7a`.

The real boundary exposed a starter-owned obsolete assertion at
`scripts/check_workshop_boundaries.exs:49`. Current Workshop correctly accepts
plain HEEx prose; our probe still expected it to fail. The smallest correction
uses `{Bedrock.Sites.name()}` as the rejecting input and retains both the real
platform-call rejection and prose acceptance assertions. The actual rejecting
full run exited 1 (nested boundary test exit 2); the corrected pinned boundary
probe exited 0. No caller gate was weakened and no sibling source was edited.

The qualifier now verifies executing caller bytes against immutable commits
before and after execution, records manifests before building, and extracts an
unchanged starter commit without a worktree overlay. A revision label cannot
prove identity. Exact commands, source checks, external logs, independent
cleanup observations and limits are in
[the current source-revalidation record](workshop-source-revalidation-2026-10-01.md).
No caller-owned defect is established by the prose acceptance outcome.

The unchanged committed starter passed all 14 current executive completion gates,
independent local boot/smoke, isolated-owner session storage and authenticated
retained-enquiry reading. Independent SQL verified every retained field; source,
lock and cleanup checks passed. No caller-owned blocker was confirmed. These are
local verified results, separate from installed guest isolation, owner acceptance
and deployment.

## 2026-10-01 — starter integration and caller-owned proof limits

The starter-owned missing integration prerequisite is corrected in
`.github/workflows/build.yml`, with a repository guard preserving standalone
customer execution. The real owner journey at Bedrock
`69c7f88c796299f0a4c46a888dddb91c77cf70b3` passed stages 1–4 against the
candidate; a synthetic lead-capture loss failed actual HTTP/database smoke in
both publication states. Exact commands and provenance are in
[the CI integration run record](starter-ci-integration-2026-10-01.md).

Two proof gaps belong to Bedrock and were left unchanged:

- `scripts/qualify_owner_journey.py:470` excludes `MIX_TEST_PARTITION` from its
  child environment; line 472 rejects a private Unix-socket `PGHOST`. The private
  socket attempt exited 1 with `Generation requires a local PostgreSQL host`
  (`foundry capture -- env PATH=/tmp/starter-integration-bin-083990:$PATH python3
  /tmp/starter-integration-isolated-083990.py broken`, capture
  `/home/svetzal/.foundry/tool-logs/2-1790892106927936065.stdout.log`). The local executable environment
  wrapper supplies a unique partition to the real Mix process while preserving
  the host check. Smallest caller correction: carry the partition variable and
  support an explicitly configured local Unix socket while rejecting remote
  hosts. Lock contention at line 465 remains a rejecting resource condition.
- `scripts/owner_journey_records.exs:5` compares only ID, contact/request,
  status, notes and insertion time. Lines 7–15 seed an enquiry with no phone or
  populated follow-up; source, `seen_at`, notification time and legacy identity
  are absent from the comparison. The passing publication proof therefore
  establishes this narrower cross-state retention. Starter smoke separately
  verifies populated retained fields and staff reads in each publication state.
  Smallest caller correction: seed populated historical synthetic contact,
  request, source, timestamps and follow-up and compare that full projection
  across publication, including staff visibility. No assertion was weakened and
  no sibling source was edited to obtain this local pass.

## 2026-10-01 — encoded business identity: starter consumer ready, producer outstanding

Actor: the owner naming a new business system. Goal: the accepted business name
survives generation and appears faithfully in the running system. Interaction:
create the system, then open its public page and magic-link sign-in page.

Read Bedrock only from `git archive HEAD` of its stock checkout, revision
`78767528c45c0d9412c4cbc90d395c724ed1c5ee` (matching its local `origin/main`).
`apps/bedrock/lib/bedrock/foundry.ex:57` still names executable config and both
legacy/current root layouts in `@named_files`; `name_files/2` at line 308 and
`replace_placeholders/2` at line 350 perform raw replacement. No JSON identity
input is emitted. `tenancy/tenant.ex:172` permits names up to 120 characters.

The new starter input is **`priv/business.json`, JSON object key `name`, string**.
Bedrock must add this file to its generated naming commit using
`Jason.encode!(%{"name" => business_name}) <> "\n"`, even when the file was absent
from the template. Stop substituting names into Elixir, HEEx and other executable
configuration; retain prose naming separately. Update its naming tests and run
its real generated-system acceptance with quotes, backslashes, literal
interpolation syntax, HTML characters, Unicode and 120-character names. This is
the remaining Bedrock-owned producer change; this run did not edit siblings or
prove that current Bedrock generation writes the new input.

The starter reads the optional data once at runtime. Resolution is `BUSINESS_NAME`
(including an empty string), then `SHOP_NAME`, then the JSON name, then baked
configuration. Only missing data falls back; malformed data fails startup when
no environment override wins. No generated name is evaluated as source. Root
page titles now use `Business.name()`, matching header/home/email consumers.
Existing published scene facts remain their authored publication values; the
fixture compatibility hash and publication output provenance remain intact.

The committed baseline was characterized through actual HTTP before expanding
acceptance: legacy baked names and both environment overrides worked, including
empty `BUSINESS_NAME`; the baseline root title remained baked despite overrides.
Raw substitution of a quoted Unicode name rejected with an Elixir syntax error.
The corrected synthetic generated system preserved that same name through
formatting, compilation, HTTP titles/header/home and mail naming. See
`.foundry/proof.json` and the dated [run record](business-name-boundary-2026-10-01.md)
for exact commands, identities, gates, limitations and cleanup. Demonstrated and
verified locally does not imply accepted or deployed; no customer records or
external delivery were used. Contacted status still does not prove a reply or
achievement of the customer's service goal.
