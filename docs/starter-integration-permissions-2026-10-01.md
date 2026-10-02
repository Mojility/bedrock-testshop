# Starter reusable workflow permissions — 2026-10-01

The beneficiary is the field-service owner pursuing
`bedrock.goal.own_business_system` through
`bedrock.interaction.open_workshop_promptly` and
`bedrock.interaction.customers_reach_me_from_site`. The maintainer performs
this correction so starter integration can validate the owner's generated
system before starter image publication.

## Correction and executable rejection

The accumulated cycle 7 implementation is preserved on starter baseline
`973fb6ce8317363ce1ac478a666cb14997f60de2`. Its
integration call inherited workflow-level `contents: read`. Bedrock producer
commit `78767528c45c0d9412c4cbc90d395c724ed1c5ee` requests `contents: read` and
`id-token: write` in `bedrock-image`, exceeding that caller grant. Conditional
publication steps do not remove this reusable workflow validation requirement.

The calling integration job now explicitly grants both permissions. Workflow
permissions remain `contents: read`; the trusted starter push/manual event
restriction, inherited source secrets, integration-dependent ARM64 image
publication and standalone customer quality/release path remain intact.
No producer, customer, credential, runtime, toolchain or scene changes were made.

`test/fixtures/integration-producer.yml` is the byte-identical committed producer
workflow, SHA-256
`da1dac5fe25a61dbd0096f988269c58ab36d71458f7afb02f16258e34d8b4a06`.
The regression checks its byte identity and compares **every** producer job's
effective permissions to the calling job's grant. Job-level declarations
replace workflow defaults; unspecified permissions are `none`. It also rejects
an incomplete grant containing only `id-token: write`, because that loses
`contents: read`. Existing event and dependency-result tests still exercise
failed/cancelled/skipped integration and the standalone customer path.

Before adding the fixture or documentation or running the full quality suite:

```sh
foundry capture -- env MIX_ENV=test ERL_FLAGS='+S 4:4' HEX_HOME=/tmp/starter-c8-tools/hex MIX_TEST_PARTITION=_c8 INTEGRATION_PRODUCER_PATH=/tmp/starter-c8-permissions/producer.yml mix test test/maintenance/build_workflow_test.exs
```

The preserved workflow exited **2**, reporting exactly
`{"bedrock-image", "id-token", "write", "none"}`. After the source correction,
the same probe exited **0**, all six tests passing. `.foundry/proof.json` links
the complete external capture logs. The earlier dependency setup failure was
not counted as behavioral rejection: the default Hex cache was read-only;
a writable temporary public-package cache resolved dependencies successfully.

## Source identity and proof boundaries

`.foundry/permissions-sources.json` records exact committed sibling archive
identities and hashes, caller before/after hashes, and the unchanged scene
fixture hash. Cycle 7 proof remains at `.foundry/proof-c7.json`; all its supporting
records remain intact. It describes the older producer, not the current producer.
The current-source integration rehearsal and final gate results follow.

These are local workflow compatibility checks and real application-boundary
rehearsals, not hosted GitHub execution. No green main workflow, owner acceptance,
WCAG conformance or deployment is claimed. This change has no UI behavior;
existing outstanding assistive-technology verification remains outstanding.
A Contacted status still does not establish that a reply was sent or the
customer's Goal achieved. Hosted execution after Foundry finalization remains
necessary. No commits, pushes or ref changes were made in this repository, and no sibling
checkouts were edited. Generation creates disposable synthetic Git artifacts.

## Final project gates

`foundry capture -- python3 .foundry/permissions-local-quality.py` passed.
The retained runner executes every Mix command through Foundry capture with
`MIX_ENV=test`, exact Elixir `1.20.2-otp-29` / OTP `29.0.2`, `+S 4:4`, a writable
temporary Hex cache and a unique synthetic test database partition.
`.foundry/permissions-quality.json` links each complete external log.

| Gate | Result |
| --- | --- |
| deps.get; format --check-formatted; compile --warnings-as-errors | Passed |
| deps.unlock --check-unused | Passed |
| test --cover | 351 tests + 12 doctests passed; 94.11% exceeds 90% |
| credo --strict | No issues |
| dialyzer | Passed |
| docs --warnings-as-errors | Passed |
| hex.audit; deps.audit; sobelow --config | Passed |
| precommit | Passed |
| hex.outdated --all (informational) | Exit 1: upgrades available |
| LiveView repeating data refresh timers | None found by scoped rg |

No dependency or advisory suppression changed. MixAudit attempts to refresh
its read-only shared cache and ignores the failed Git exit. Independent checks
verified the scanned revision against current remote main and compared every
loaded advisory YAML byte to that committed archive. The exact revision, archive
hash and verification logs are in `.foundry/permissions-audit-source.json`.
The unique quality database and workflow-probe database were removed.

## Current-source real boundary

| Source | Committed revision |
| --- | --- |
| Bedrock producer | `78767528c45c0d9412c4cbc90d395c724ed1c5ee` |
| Roost | `bb57e6d0bf2bff3af72d40ad9adb5fa7c34d81b8` |
| Workshop | `32730f7132b1a262b85a0b66fcc46fedd1b8051a` |
| Starter baseline, with recorded candidate overlay | `973fb6ce8317363ce1ac478a666cb14997f60de2` |

The preserved cycle 7 harness was adapted to these committed inputs and to
materialize the authored candidate. Git acquisition reads pinned committed
objects; generation's GitHub adapter and outbound mail remain the simulated
edges. Real generation uses a unique local test database partition; preparation
and runtime use a unique private PostgreSQL cluster with no TCP listener.
The real producer and customer commands execute with the pinned toolchain.

```sh
foundry capture -- env PATH=/tmp/starter-c8-permissions/bin:$PATH python3 /tmp/starter-c8-permissions/isolated.py corrected
foundry capture -- python3 scripts/qualify_callers.py --bedrock /tmp/starter-c8-permissions/clean-bedrock --bedrock-revision 78767528c45c0d9412c4cbc90d395c724ed1c5ee --snapshot-parent /tmp/starter-c8-permissions
```

Both commands exited **0**. The first ran the real resolver, followed by
`qualify_owner_journey.py --stages 1,2,3,4`. All stages passed: generation,
unpublished preparation and smoke, compatible publication through the real
exporter and renderer, published preparation and smoke, and packaged release
application checks in both states. Missing release lead-route probes rejected
with exit **1** and real HTTP **404**; corrected probes passed. Publication
output provenance, hashes, synthetic generated commit/parent identities and
current executing producer-file hashes are retained in
`.foundry/permissions-integration-corrected.json` and its source-resolution record.
Workshop iteration/stage 5 and all hosted producer jobs were not rerun by this
stages 1–4 rehearsal; no whole hosted integration result is claimed.

The second command exercises both cold and retained preparation paths. It
seeded a complete synthetic enquiry **before startup**, then reused that same
expectation through the unpublished and compatible synthetic published scene.
The stable candidate materialization digest was
`0d31bc3d345e71aae684dadf8b3ffba9c5ed4124fc4c1417bf6b5ae6c4fb84f9`.
Actual HTTP and SQL checks proved nonempty deployed CSS (including the digested
app stylesheet), CSRF denial without an enquiry write, anonymous staff denial,
exact new-enquiry field persistence, magic-link session creation and staff
reading both enquiries. Complete retained database values—contact, request,
source, status, legacy identity, submission/seen timestamps and follow-up—matched
the pre-start expectation before and after smoke in both states. Authenticated
HTML checks cover the displayed contact, request, submission timestamp and
follow-up; source/history metadata integrity is checked in SQL and is not
claimed as a separately rendered staff field. `.foundry/proof.json` links the
seed, both smoke logs and their identified executing checks.

The new producer qualifier differs from cycle 7, so its stages were rerun.
`.foundry/permissions-sources.json` records which prior caller files remain
byte-identical; prior observations are retained under their original identities.
The workflow and application/caller/asset inputs used by the current rehearsal
match the final candidate, as recorded in
`.foundry/permissions-executing-sources.json`. Documentation and the regression's
producer-byte assertion were finalized around the rehearsal, and final project
gates run on those final sources. No executed application source changed.

## Rejections and cleanup

The shared port lock was contended for much of the run. A real caller rejected
one acquisition race before any generation; the harness retried acquisition
only, retaining `.foundry/integration-queue-2.json`. It did not retry or bypass
a failing application check. One retained qualification rejected a documentation
edit during its source-stability check, before database creation or listener
startup; it removed its snapshot. That setup failure is retained separately at
`.foundry/permissions-caller-source-stability-rejection.json`, and the restarted
frozen-source qualification passed. Neither setup failure replaces the workflow
permission rejection.

Both successful qualifiers synchronously stopped service process groups before
releasing `/tmp/bedrock-port-4000.lock`; the owner qualifier stopped its private
PostgreSQL cluster before deleting its snapshot. Independent SQL checks found
none of our workflow, quality, generation or qualification databases remaining.
Both qualification snapshots, the owner snapshot, the partition marker, and
`/tmp/starter-c8-permissions` (archives and temporary harness files) were removed.
`.foundry/permissions-cleanup.json` retains the observation and its external log.
A subsequent independent shared-lock probe was contended; global port availability
is not claimed. The temporary public dependency cache is retained for gate replay;
it contains no business records. Raw logs remain outside the worktree in
Foundry's default log directory. No operational records, secrets, customer or
sibling changes are included.
