# Starter CI integration qualification — 2026-10-01

The beneficiary is the business owner creating an independently operated
system. The Goal is to own a working business system; the Interactions are
publishing a website and exploring before adoption. The maintainer performs
this CI correction. This record demonstrates local source compatibility and
failure detection, not owner acceptance, GitHub execution or deployment.

## Source correction

`.github/workflows/build.yml` now calls
`Mojility/bedrock/.github/workflows/integration.yml@main` with `secrets: inherit`
only for starter pushes and manual runs. Image publication depends on integration,
quality and release acceptance. Explicit result checks with `!cancelled()` allow
customer repositories to proceed when platform integration is skipped, while
requiring their quality and release acceptance to succeed. Starter integration
failure, cancellation or skipping prevents image publication.

The existing triggers, exact `.tool-versions` pins, quality checks, release
acceptance, immutable commit tags and ARM64 publication remain intact.
Application, authentication, runtime and publication source/output are unchanged.
`SYSTEM.md` and the quality guide describe the repository guard.

## Immutable permitted inputs

Sibling sources were obtained with `git archive HEAD` from the permitted
Mojility checkouts, then pinned to the resolved revisions. No sibling uncommitted
source or customer checkout was used. The committed producer was inspected
before wiring its call: it checks out a starter caller's exact `github.sha`,
resolves all four sources and runs `qualify_owner_journey.py --stages 1,2,3,4`.

| Source | Revision |
| --- | --- |
| Bedrock producer and owner journey | `69c7f88c796299f0a4c46a888dddb91c77cf70b3` |
| Roost | `bb57e6d0bf2bff3af72d40ad9adb5fa7c34d81b8` |
| Workshop | `adfcae0a96c291ddebfd28a086e5464bf97c9376` |
| Starter baseline | `a5912b119a61e8c216e7118c60659ead02acce06` |

The candidate was that starter archive plus the authored workflow change.
Its materialization digest was
`8c91bb687a61ae5461d09398fbaf4b9c300fcc477fd3720f5ea9e7bcf4471f2f`.
The rejecting variant's digest was
`c8ef4ad6c653a0dafa6cf201d512cbf23ff6a9fbdb5b2583fdbe1d5c2a0c49b4`.
Tests and documentation were finalized afterward; no application or caller
command source changed afterward. `.foundry/integration-command-sources.json`
records archive hashes, unchanged executing caller-file hashes and the unchanged
scene fixture hash. `.foundry/integration-sources-*.json` records resolver
provenance, including generated guidance and compatibility-related inputs.

## Real boundary: rejecting and passing runs

Commands ran through Foundry capture; full logs remain outside the repository.
The local Git transport reads pinned committed objects. The starter overlay is
explicitly recorded alongside its baseline revision and materialization digest.
Every Mix command executes the real pinned executable. A local Mix environment
wrapper supplies a unique test partition only to Bedrock generation, because
the caller omits that variable from its child environment. GitHub transport and
outbound mail are the simulated/disabled edges; execution and PostgreSQL are real.

The passing source-resolution command, from the archived Bedrock root, was:

```sh
python3 scripts/integrate.py --roost /home/svetzal/Work/Projects/Mojility/roost --workshop /home/svetzal/Work/Projects/Mojility/bedrock-workshop --starter /home/svetzal/.foundry/worktrees/bedrock-system-template/starter-caller-contracts-v1-c7-083990
python3 scripts/qualify_owner_journey.py --stages 1,2,3,4 --output /home/svetzal/.foundry/worktrees/bedrock-system-template/starter-caller-contracts-v1-c7-083990/.foundry/integration-corrected.json
```

The rejecting harness called the same real resolver's `integrate.prepare/3`
entry point; the passing harness invoked its CLI. The retained final local
harness reproduces the CLI route and the same synthetic fault. Neither resolver
nor owner-journey checks were replaced by successful command mocks.

```sh
foundry capture -- env PATH=/tmp/starter-integration-bin-083990:$PATH python3 /tmp/starter-integration-isolated-083990.py broken
foundry capture -- env PATH=/tmp/starter-integration-bin-083990:$PATH python3 /tmp/starter-integration-isolated-083990.py corrected
```

The synthetic controller reports enquiry success without inserting a lead when
an email field is present. The rejecting run exited **1**. In both unpublished
and published states, actual HTTP submission appeared successful but actual
SQL found no submitted enquiry: smoke rejected `lead_persistence`.
The passing baseline exited **0**, with stages 1–4 passing. Both states verified
nonempty deployed/digested CSS, CSRF denial without a write, anonymous staff
denial, persisted enquiry fields, magic-link session creation, and staff reads
of new and retained synthetic enquiries. Release checks also rejected an actual
HTTP 404 at a deliberately missing enquiry route, then passed against the real
route. The exporter output was rendered and an incompatible model was rejected;
its publication manifest and parent/generated object provenance remain in
`.foundry/integration-corrected.json`.

- Rejecting log: `/home/svetzal/.foundry/tool-logs/2-1790892282861303690.stdout.log`.
- Passing log: `/home/svetzal/.foundry/tool-logs/2-1790893483812201571.stdout.log`.
- Strict behavioral proof and nested release logs: `.foundry/proof.json`.

## Workflow regression

`test/maintenance/build_workflow_test.exs` reads the authored YAML and interprets
only condition operators and context lookups. It exercises dependency failure
propagation, cancellation, skipped integration, customer execution and event
restrictions. It also rejects the previous publication graph explicitly.

The actual archived pre-change workflow was supplied through
`BUILD_WORKFLOW_PATH=/tmp/starter-build-before-083990.yml`. Running
`MIX_ENV=test mix test test/maintenance/build_workflow_test.exs` against it exited
**2**; the corrected authored workflow exited **0**, all five tests passing.
The exact environment overlays and red/green logs are retained in
`.foundry/integration-command-sources.json`. These are local workflow contract
checks; they do not execute GitHub's scheduler or validate hosted secret delivery.

## Isolation, cleanup and limits

Final proof generation used unique `bedrock_test_starter_c7_083990_*` databases,
removed by the harness. Customer execution used unique private PostgreSQL
clusters with Unix sockets and no TCP listener; the caller's `exploration`
database was confined to each private cluster. The shared
`/tmp/bedrock-port-4000.lock` covered every port-4000 listener until shutdown.
The passing run's cluster was `bedrock-owner-proof-6usy845u`; the rejecting
run's was `bedrock-owner-proof-2td100i2`. Both snapshots were removed after
server shutdown and database cleanup.

Pre-generation lock contention was retained and retried only before any
application command ran. Application and smoke failures were never retried as
success. An initial discarded attempt used the default Bedrock test partition;
subsequent attempts established the unique generation partition. Interrupted
scratch snapshots were checked for stopped private sockets and removed;
`.foundry/integration-interrupted-cleanup.json` records that cleanup. A private
socket generation attempt was rejected by the caller's existing host restriction.
These discarded attempts are not passing evidence.

The workstation runs Elixir 1.20.2, OTP 29.0.2 and PostgreSQL 16.15. CI's exact
Elixir/OTP pins and PostgreSQL 18 pin were preserved. Local x86 execution does
not establish an ARM64 image build or PostgreSQL 18 acceptance. No Docker,
cloud credentials, customer data, production infrastructure, source refs or
publication outputs were changed. No GitHub workflow was dispatched and no
image was published or deployed. UI source is unchanged; this task adds no
browser/assistive-technology conformance claim.

The cross-publication retained-record helper checks a narrower field set than
per-state starter smoke, and seeds empty follow-up. That caller-owned gap is
recorded in `docs/owner-journey-findings.md`; it was not repaired or weakened
here. Contacted demo state and staff visibility do not prove a reply was sent or
that the customer's service Goal was achieved. Mail and the live owner journey
remain unverified.

## Repository quality

Required checks, coverage, strict Credo, Dialyzer, documentation, audits,
Sobelow, precommit, upgrade visibility and database cleanup are recorded in
`.foundry/integration-quality.json`. All eleven required individual checks and `mix precommit` exited 0. The suite
passed 362 cases (12 doctests and 350 tests) with 94.11% coverage, above the 90%
threshold. Strict Credo found no issues; Dialyzer reported zero errors and zero
skips. Dependency vulnerability and retirement audits and Sobelow passed.
`mix hex.outdated --all` exited 1 for upgrade visibility, which is advisory;
no dependency or advisory suppression was added. LiveView source contains no
`send_after` matches.

The full gate command was `foundry capture -- python3
/tmp/starter-integration-quality-083990.py`; its outer log is
`/home/svetzal/.foundry/tool-logs/2-1790895506174166711.stdout.log`. Every
individual command, actual exit and external log is in the quality record.
The unique quality database was removed. Caller source was byte-checked again
after execution. Temporary archives, harness files and source snapshots were
removed; `.foundry/integration-cleanup.json` records independent snapshot and
synthetic-database observations. The pre-existing public dependency cache and
normal ignored build/coverage/docs/PLT artifacts were retained. No source ref
was changed; completed modifications remain uncommitted for Foundry review.

MixAudit's cache refresh printed a read-only `FETCH_HEAD` error even though the
scan exited 0. Its synchronization code ignores the pull failure. Independent
read-only verification established that the scanned advisory cache matches
remote `main` revision `935abf7410a2bbb18e12579dee6e31267c3ed244`, and every loaded
YAML file matches that committed archive byte for byte.
`.foundry/integration-audit-source.json` retains the exact revision, archive hash
and both successful verification logs. This establishes current scan data; it
does not claim the refresh itself succeeded. No advisory was suppressed or
cache/source ref changed.
