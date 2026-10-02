# Starter release runtime acceptance — 2026-10-01

Actor: the business owner selecting a starter release. Goal: an independently
running customer system that captures enquiries and preserves staff access.
Interaction: qualify the actual production artifact before image publication.
The executable gate belongs to this starter, not Bedrock's planning tracker.

## Exact source and environment

Read the campaign brief and starter inbox at
`/home/svetzal/Work/Operations/Planning/campaigns/2026-10-01-bedrock-owner-journey/`.
Starter baseline: `fb808a5e753427945bd85779bba1d04033fb21e5`. Foundry owns Git
finalization: no commit, ref update, push or customer checkout was used. The
candidate is the baseline archive plus identified working-tree changes; each
run prints its source SHA-256 and assembled artifact SHA-256. It is not described
as an already committed or deployed candidate.

Permitted sibling `git archive HEAD` inputs:

| Repository | Revision | Owning source |
| --- | --- | --- |
| Roost | `bb57e6d0bf2bff3af72d40ad9adb5fa7c34d81b8` | `docs/contract-v1.md:302`, `priv/cell/runner.py:725`, `infra/cell/qualify_phoenix.py:54` |
| Bedrock | `426ba1ba37c550a4fc793e598bb984d8b8a817b2` | `infra/customer-release/rehearse.py:62`, `:198`; `apps/bedrock/lib/bedrock/explorations/bootstrap.ex` |

`.foundry/release-contract-sources.json` records archive commands and SHA-256
identities for every input. No uncommitted sibling files were treated as trunk.
Roost executes `/app/bin/migrate` separately from foreground `/app/bin/server`;
its runtime environment names `DATABASE_URL`, `DATABASE_SSL`, `SECRET_KEY_BASE`,
`PHX_HOST`, `PHX_SERVER`, `PORT`, `POOL_SIZE`, `ERL_FLAGS`, `AWS_REGION` and optional
scoped media settings. Bedrock's isolated rehearsal explicitly adds
`PHX_SCHEME=http`, `MAIL_ADAPTER=disabled`, and `LEAD_NOTIFICATIONS=false`.

The release probe substitutes only synthetic local database/session values and
localhost for these caller settings. `bin/server` itself sets `PHX_SERVER`.
Neither the server nor its runtime configuration receives exploration overrides.
Media keys are absent because this synthetic unpublished baseline has no media.
The separate observer receives `SMOKE_EXISTING_LEAD` and the pre-start seed
receives `SMOKE_EXPECTATION_PATH`; only the observer sets the smoke isolation
permission. It checks the URL is loopback and the database has the uniquely
generated `release_qualification_` prefix before enabling that permission.
The existing smoke loopback and exploration guards remain intact.

Host: Canadian workstation `mojility-ops-01`. Elixir `1.20.2-otp-29`, OTP `29.0.2`
match `.tool-versions` exactly. Local PostgreSQL is
`16.15 (Ubuntu 16.15-0ubuntu0.24.04.1)`; CI remains pinned to PostgreSQL 18.
The local release is native to this workstation; no Docker or cloud calls occur.
Hex uses a writable, task-specific `/tmp/starter-c6-tools/hex` cache because the
default cache is outside this worktree's writable boundary. Credentials and
synthetic data are omitted from this record.

## Proof first

Before documentation expansion or the full quality suite, build:

```sh
foundry capture -- env HEX_HOME=/tmp/starter-c6-tools/hex ERL_FLAGS='+S 4:4' MIX_ENV=prod sh -c 'mix deps.get && mix assets.deploy && mix release --overwrite'
```

This passed; build log:
`/home/svetzal/.foundry/tool-logs/2-1790889661897273048.stdout.log`.
The first rejecting experiment compiled a controller that skipped its SQL query
into a disposable copy of this artifact. The real server then returned HTTP 200
after PostgreSQL `ALLOW_CONNECTIONS false` and termination of that synthetic
database's active connections. The release gate rejected it with exit 1:
`/home/svetzal/.foundry/tool-logs/2-1790890103986398360.stdout.log` and adjacent
`.stderr.log`. This was an introduced regression experiment, not a claim that
the baseline controller was defective.

The original artifact passed the same boundary with HTTP 503 and a JSON
`unavailable` body, separate migration execution, and unmigrated ordinary startup:

```sh
foundry capture -- env HEX_HOME=/tmp/starter-c6-tools/hex python3 scripts/qualify_release.py --release _build/prod/rel/business --proof
```

Exit 0, log:
`/home/svetzal/.foundry/tool-logs/2-1790890111242106827.stdout.log`.
The repeatable in-repository rejecting command is:

```sh
foundry capture -- env HEX_HOME=/tmp/starter-c6-tools/hex python3 scripts/verify_release_regressions.py --release _build/prod/rel/business --case readiness
```

Exit 1, logs:
`/home/svetzal/.foundry/tool-logs/2-1790890262506898609.stdout.log` and adjacent
`.stderr.log`. `.foundry/proof.json` points to these rejecting/corrected results.
Both runs removed their synthetic databases and snapshots and proved listener
termination by re-binding the selected port after process-group shutdown.

## Complete gate and limits

CI's `release-acceptance` job executes `python3 scripts/qualify_release.py` with
the exact pinned toolchain and local PostgreSQL service. `build-and-push` depends
on it and the existing quality job. The complete gate builds a fresh isolated
candidate, deploys assets, assembles `mix release`, migrates, seeds the retained
synthetic enquiry before startup, and runs the real `scripts/smoke.exs` against
the foreground artifact on locked port 4000. Signal handling defers interrupts
around process creation and cleanup; the lock encloses whole-group shutdown.
Raw capture/server logs remain outside the repository; CI uploads server logs.

The full default command passed (exit 0):

```sh
foundry capture -- env HEX_HOME=/tmp/starter-c6-tools/hex python3 scripts/qualify_release.py
```

Log: `/home/svetzal/.foundry/tool-logs/2-1790890586043993825.stdout.log`.
Candidate source SHA-256:
`f7872531aadcb93488bdc697e61f435f46376614b830c32b275d9897d5f95257`.
Release artifact SHA-256:
`7983955388f0173d29f3544161e0c09215777dbb31968aa81a574bfa486d358c`.
Actual smoke observer log:
`/home/svetzal/.foundry/tool-logs/522-1790890616112702829.stdout.log`.
Port-4000 HTTP server log:
`/home/svetzal/.foundry/tool-logs/release-e66c5a378bbcfd5a.log`.
These identify the source at execution time; this dated record was subsequently
completed with results. The final rerun is linked in `.foundry/proof.json`.

An earlier simultaneous probe failed with
`Protocol 'inet_tcp': the name business@mojility-ops-01 seems to be in use by another Erlang node`:
`/home/svetzal/.foundry/tool-logs/2-1790890468804038042.stdout.log`, server log
`/home/svetzal/.foundry/tool-logs/release-166b0a5ed7f809c4.log`.
The starter-owned runner now locks every server probe, including its dynamic
port, instead of changing the caller's release environment or node settings.
The corrected full run above passed after that fix. Builds also reject any
change to the candidate's `mix.lock`.

The real smoke rejected a disposable artifact with empty CSS (exit 1):

```sh
foundry capture -- env HEX_HOME=/tmp/starter-c6-tools/hex python3 scripts/verify_release_regressions.py --release _build/prod/rel/business --case smoke
```

Log: `/home/svetzal/.foundry/tool-logs/2-1790890487019794466.stdout.log`, adjacent
`.stderr.log`; observer log
`/home/svetzal/.foundry/tool-logs/323-1790890501933580797.stdout.log` reports
`stylesheet_delivery` failure. Original deployed assets were untouched.
The rejecting gate removed its port-4000 listener, database and both snapshots.

Signal cleanup was observed by pausing the owned BEAM with SIGSTOP, then
signalling the real runner. While its paused listener remained, the shared lock
could not be acquired; after shutdown, neither the listener process group nor
the exact synthetic database or snapshot remained. Repeatable commands:

```sh
foundry capture -- env HEX_HOME=/tmp/starter-c6-tools/hex python3 scripts/verify_release_cleanup.py --release _build/prod/rel/business --signal SIGTERM
foundry capture -- env HEX_HOME=/tmp/starter-c6-tools/hex python3 scripts/verify_release_cleanup.py --release _build/prod/rel/business --signal SIGINT
```

The observer exits 0 only after verifying the runner's expected exit 143/130
and cleanup; final logs are linked in `.foundry/proof.json`. Earlier observer
runs also passed: `/home/svetzal/.foundry/tool-logs/2-1790890627512972384.stdout.log`
and `/home/svetzal/.foundry/tool-logs/2-1790890661789873462.stdout.log`.

Required quality checks passed through:

```sh
foundry capture -- env HEX_HOME=/tmp/starter-c6-tools/hex ERL_FLAGS='+S 4:4' MIX_ENV=test MIX_TEST_PARTITION=_release_c6_75dc08 sh -c 'mix deps.get && mix compile --warnings-as-errors && for task in precommit format compile deps.unlock test credo dialyzer docs hex.audit deps.audit sobelow; do mix help "$task" > /dev/null || exit; done; mix precommit'
```

Exit 0, `/home/svetzal/.foundry/tool-logs/2-1790890214861246746.stdout.log`:
357 tests passed (12 doctests and 345 tests), coverage 94.11% against threshold
90%; strict Credo found no issues; Dialyzer reported zero errors; format,
unused-dependency checks, Hex audit, dependency vulnerability audit, Sobelow and
docs with warnings as errors passed. Upstream dependency compilation emitted
Elixir-version warnings; no new application warning or advisory was suppressed.
`rg -n send_after lib/business_web/live` returned no matches. The dedicated test
database is removed after validation. Final documentation checks are linked in
the proof record. The brief's required JSON shape and every referenced evidence
path are checked before handoff.

Second full-build rerun passed (exit 0):
`/home/svetzal/.foundry/tool-logs/2-1790890966765630962.stdout.log`;
source SHA-256 `a5534389a107447ec91235ec405ddea7faa6eec68784fd0dd06b4ad2c31d422b`,
artifact SHA-256 `e1edccfd448d2a2b87473e77c0acd0ffe826bf8abb9d2092354268f4b33215c4`.
The retained-record, enquiry and authentication smoke ran in
`/home/svetzal/.foundry/tool-logs/527-1790890995185848081.stdout.log`; server log
`/home/svetzal/.foundry/tool-logs/release-1e4f91c7105644da.log` records the real
HTTP responses. Final SIGTERM/SIGINT observer logs respectively:
`/home/svetzal/.foundry/tool-logs/2-1790890904625971987.stdout.log` and
`/home/svetzal/.foundry/tool-logs/2-1790890850428749123.stdout.log` (both exit 0).
Final `mix docs --warnings-as-errors` passed (exit 0):
`/home/svetzal/.foundry/tool-logs/2-1790891046880691744.stdout.log`.
`mix hex.outdated --all` returned 1 for available upgrades including Sobelow
0.16.0; this visibility command is not an acceptance blocker and the required
audits found no vulnerabilities or retired packages. No advisory was allowlisted
or suppressed. Its output follows successful format/compile/docs checks in
`/home/svetzal/.foundry/tool-logs/2-1790890967934571058.stdout.log`.
`foundry capture -- dropdb --if-exists --force business_test_release_c6_75dc08`
passed (exit 0): `/home/svetzal/.foundry/tool-logs/2-1790891086998947397.stdout.log`.

The boundary verifies persisted enquiry fields and authenticated staff HTTP
reads, not merely record IDs or successful command receipts. Retained source,
timestamps, status and notes are compared against the exact pre-start record;
staff HTTP verifies contact, request, received timestamp and follow-up notes.
A Contacted status does not prove a reply was sent or electrical service was
delivered. Mail delivery, published-scene preparation, scoped hosted roles,
database TLS, ARM container equivalence, public HTTPS, live customer records and
deployment remain separate acceptance obligations. This change adds no UI and
makes no accessibility-conformance claim or new assistive-technology verification.
No caller-owned defect was demonstrated in this release boundary; the owning
starter defect was the absence of an executable release gate before publication.
