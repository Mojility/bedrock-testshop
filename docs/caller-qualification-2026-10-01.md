# Starter caller qualification — 2026-10-01 (historical c1 run)

This preserves the original run record. Its worktree-local log references below
are historical identifiers, not current logging instructions or current proof.
Those raw logs did not accompany the source snapshot. The c1 marker-based form
and staff negatives did not prove capability loss, and c1 did not prove SIGTERM
cleanup or ownership of Bedrock's shared lock. See the
[reconciliation record](caller-reconciliation-2026-10-01.md) for corrected
boundary evidence. Use `foundry capture --` with its default external logs and
`/tmp/bedrock-port-4000.lock`; never create `.foundry/logs/` in this repository.

This is sanitized local execution evidence on the Canadian workstation
`mojility-ops-01`. It contains synthetic inputs only. Foundry owns Git
finalization; no commit, push, ref change or deployment was performed.

## Sources and environment

- Starter baseline: `963f5db9f0017f7dba6a56459697d5c79efb058a`, plus the
  source changes in this worktree. The final review patch is the correction;
  this log does not invent an already committed correction SHA.
- Initial Bedrock trunk: `6fc8d8eda5806ddbfe9f271699bc67e45ad8cf70`.
  Final qualification trunk: `aaec254d96299f17c4a846a2dc04e5d1f068d15b`.
  The clean local `main` matched `origin/main` at each run start. Both preparation
  modules retained the hashes below across the trunk advancement. No customer
  repository was read.
- `bootstrap.ex` SHA-256: `24be9947207a50d9f108c68960351a715cc49fb6cbfeeffaee099f309306ae84`.
- `preparation.ex` SHA-256: `635f421f32ba3dc5fb1bd523329c4d072110666960cd2eef80011a9251f380f9`.
- Elixir `1.20.2-otp-29`, OTP `29.0.2`, unchanged and checked against
  `.tool-versions`. CI already reads exact pins and caches `priv/plts/`.
- Local PostgreSQL `16.15`; CI remains pinned to PostgreSQL `18`. This run
  does not claim execution against CI's PostgreSQL service.
- Application proof: `MIX_ENV=prod`, `CUSTOMER_EXPLORATION=true`, loopback
  port `4000`, explicit synthetic HTTPS origins, new ephemeral secret,
  disabled mail and lead notifications, and no provider credentials.
- Quality checks: `MIX_ENV=test`, local Mix/Hex directories, `ERL_FLAGS='+S 4:4'`,
  and worktree-specific database `business_test_caller_0ffc42`. The initial
  focused tests used another newly created synthetic database,
  `business_test_caller_c1`. No existing business database was used.

## Proof before expansion

Historical command (then wrapped in `foundry capture --log-dir .foundry/logs --`;
current runs use the default external capture directory):

```sh
python3 scripts/qualify_callers.py --bedrock /path/to/bedrock --proof
```

The original `Business.Smoke` rejected the real prod holding page at
`stylesheets_present` (exit **1**). `mix assets.deploy` had generated the
stylesheet manifest; the root layout's digested stylesheet URL included
`?vsn=d`, which the suffix-only filter missed. The correction parses the URI
path to identify CSS, requests the original URL, and requires HTTP 200,
nonempty content and `text/css`. Repeating the clean prod probe passed
(exit **0**), including enquiry persistence, anonymous staff denial, CSRF
denial, magic-link session creation and staff reading.

Reviewable evidence is `.foundry/proof.json`. Rejecting log:
`.foundry/logs/2-1790866518642603087.stdout.log`; corrected log:
`.foundry/logs/2-1790866683420392917.stdout.log`. The nested smoke logs are
`708-1790866647909850754.stdout.log` (rejecting) and
`707-1790866868519038627.stdout.log` (passing), under the same directory.
These are actual application/SQL runs, not mocked command receipts.

Early harness attempts stopped before HTTP testing: the default capture log
location and shared Hex cache were unwritable, an invented origin was outside
Bedrock's accepted suffix, and a source-copy operation dereferenced LiveView's
dangling `node_modules` link. The harness now uses writable local tool/log paths,
accepted synthetic origins and preserves symlinks. These attempts are not
counted as behavioral rejection evidence. An initial focused-test attempt used
a Unix socket path as Postgrex's TCP hostname; the quality environment was
corrected to the local TCP service. Initial fault-wrapper setup mistakes
(a missing pass-through case and missing synthetic media origin) were fixed
before recording the behavioral regression failures; those fixture errors are
not counted as capability-loss evidence.

## Capability regressions

Real Bandit listeners wrap the actual application endpoint, with explicit
faults at the HTTP/database boundary. They do not substitute successful build
or smoke receipts. Before strengthening field checks, smoke still passed with
a corrupted submitted enquiry, a corrupted retained enquiry, and a deleted
retained enquiry. The regression suite failed **3 of 12** tests because no
exception was raised; evidence:
`.foundry/logs/2-1790867246610573973.stdout.log` (exit **2**).

The correction compares all submitted contact/request values and the retained
record's ID, contact/request values, source, legacy identity, insertion and
follow-up timestamps, status and notes. Staff HTTP reads must contain meaningful
request/contact/follow-up content. An externally seeded retained record is
never deleted by smoke. Ordinary callers without an expectation still use a
self-contained synthetic retained record; their command contract is preserved.

The 24 focused contract/exploration tests then passed. Evidence:
`.foundry/logs/2-1790867503535612072.stdout.log` (exit **0**). Historical negative cases
cover a renamed enquiry-form marker, empty CSS, HTML returned as CSS, missing persistence,
changed submitted fields, missing/changed retained records, anonymous staff
access, missing CSRF protection, broken magic-link sign-in and renamed staff
content markers. These two cases are superseded by actual capability removals
in the reconciliation; the other regressions are preserved. The existing incompatible-scene and missing-stylesheet checks remain.
One further regression found that a published home page's valid site CSS
could conceal missing staff CSS. Empty inbox CSS incorrectly passed smoke:
`.foundry/logs/2-1790869350294696229.stdout.log` (exit **2**, one failing
regression). Smoke now fetches and validates CSS from the authenticated staff
response as well. All **25** focused tests passed after that change:
`.foundry/logs/2-1790869543988942117.stdout.log` (exit **0**).

No fixture compatibility hash was replaced: the supplied scene hash is
`704b1cb9a5421ef6593108152d8065afec9b070dd59a0d5fe085b0f92a99dbee`, which
matches the starter's empty extension model.

The first full coverage run failed two later HTTP tests after earlier tests
consumed their shared loopback rate-limit budget. The test harness now resets
only that synthetic visitor's ETS budget before and after independent tests;
production limits and rejection tests remain unchanged. The corrected run
passed **355 checks (343 tests and 12 doctests)** with **94.14% coverage**,
above the unchanged **90%** threshold. Evidence:
`.foundry/logs/213-1790867873530750042.stdout.log`.

## Preparation and two publication states

The full command is:

```sh
python3 scripts/qualify_callers.py --bedrock /path/to/clean/bedrock-trunk
```

The runner compiles and calls Bedrock's actual Bootstrap and Preparation modules
for stage, compile, service and smoke. Source acquisition uses `git archive`
of the exact baseline with this worktree's source overlaid; no source refs are
modified. The lockfile comparison uses `cmp` against the archived lockfile.
Preparation's `git ls-files` reads this repository's index with an explicit
snapshot worktree for file hashes. Sandbox paths are remapped into disposable
local directories. Only the snapshot's runtime config overrides the local
PostgreSQL role/database; shipped exploration defaults and auth are unchanged.

Executed stage boundaries include:

```sh
mix local.hex --force
mix local.rebar --force
MIX_ENV=dev mix deps.get --check-locked
MIX_ENV=dev mix deps.compile
MIX_ENV=dev mix compile --warnings-as-errors
MIX_ENV=test mix deps.get --check-locked
MIX_ENV=test mix deps.compile
MIX_ENV=test mix compile --warnings-as-errors
MIX_ENV=prod mix deps.get --check-locked
MIX_ENV=prod mix deps.compile
MIX_ENV=prod mix compile --warnings-as-errors
MIX_ENV=prod mix assets.deploy
```

The retained-preparation branch also executes the helper's source/toolchain
fingerprint, dependency build namespace, content manifest, dependency promotion
and Hex registry promotion. The copied runtime executes the actual prod compile
command. Existing migrations run once against a newly created, uniquely named
synthetic database. `scripts/qualification_seed.exs` creates an enquiry before
the listener starts: invented contact details, a lighting request, source and
legacy identity, historical insertion/follow-up timestamps, Contacted status
and a note awaiting the preferred date. The same record must survive both states.

The service and smoke commands retain Bedrock's environment and readiness loop:

```sh
MIX_ENV=prod PHX_SERVER=true PORT=4000 mix phx.server
MIX_ENV=prod PHX_SERVER=false mix run --no-start scripts/smoke.exs
```

The first full preparation attempt completed the unretained and retained helper
builds, runtime compile, migration and pre-start seed, then passed the baseline
smoke. Its HTTP asset URL was
`/assets/css/app-3aecb787d45ad122b1f4204162da52d0.css?vsn=d`.
The published-state preflight then rejected the just-closed listener's TIME_WAIT
sockets (`EADDRINUSE`). Evidence:
`.foundry/logs/2-1790867503544754232.stdout.log` and its stderr log (exit **1**).
The listener was stopped and its synthetic database was dropped. The harness
now uses `SO_REUSEADDR` for its availability probe, which still rejects an
active listener. This did not establish ownership of Bedrock's shared lock or signal-safe shutdown.
The complete two-state run was restarted after this correction and passed
both states (exit **0**): `.foundry/logs/2-1790868491603021025.stdout.log`.
This was followed by the additional staff-CSS regression below; the final
implementation is qualified separately again.

The final source's complete two-state run passed (exit **0**):
`.foundry/logs/2-1790869544039433218.stdout.log`. The run started against
Bedrock trunk `aaec254d96299f17c4a846a2dc04e5d1f068d15b` and executed the
same Bootstrap/Preparation source hashes recorded above.

| Capability checked through HTTP/SQL | Unpublished baseline | Synthetic publication |
| --- | --- | --- |
| Readiness, public page and enquiry form | Passed | Passed |
| Public and authenticated staff CSS: HTTP 200, nonempty, `text/css` | Passed; digested app URL | Passed; site CSS and digested app URL |
| Missing-CSRF submission: HTTP 403 and no saved enquiry | Passed | Passed |
| Anonymous `/app/leads`: redirect to `/users/log-in` | Passed | Passed |
| Valid submission: exact name, phone, email and request persisted | Passed | Passed |
| Magic-link token creates staff session and reaches `/app/leads` | Passed | Passed |
| Staff HTTP read contains new enquiry contact/request values | Passed | Passed |
| Pre-start enquiry: exact retained contact/request, source, identity, timestamps and follow-up | Passed | Passed; same record across restart |
| Staff HTTP read contains retained enquiry and private follow-up | Passed | Passed |

The bounded smoke JSON reported `passed` in both states; this table describes
assertions executed against actual responses and rows, not deductions from the
JSON check count. The nested smoke/SQL evidence is
`.foundry/logs/2826-1790870539420416205.stdout.log` (baseline) and
`.foundry/logs/3031-1790870545282403945.stdout.log` (published).

Cleanup completed on the rejecting and passing paths. The final run's unique
synthetic database was dropped (exit **0**):
`.foundry/logs/3084-1790870547887234741.stdout.log`. Final verification found
no listener on port 4000, no `qualification-*` snapshot directories, and none
of this task's known synthetic databases. The original run used a different lock filename and waited only for the
service launcher. Signal-safe group termination and shared-lock ownership
required the subsequent reconciliation. The empty shared lock file remains as a
synchronization resource; unlinking it could split cooperating writers' locks.
Only public dependency/tool caches, quality artifacts and review logs remain;
no runtime secret, scene copy or business records remain.

## Limits of the claim

This verifies local starter preparation, enquiry capture/persistence and staff
access. It does not verify sending a reply, SES/mail delivery, the customer's
service Goal, customer upgrade compatibility, hosted account/mount isolation,
ARM image publication, public HTTPS readiness or deployment. No customer, production or cloud-infrastructure resources were contacted.
Dependency downloads and public audits used upstream registries. There were no production data reads,
destructive migrations, toolchain bumps, regenerated existing systems or
suppression/allowlist changes. UI source was unchanged; no new keyboard,
light/dark-mode or assistive-technology conformance claim is made.

## Quality gates

The final implementation passed **356 checks (344 tests and 12 doctests)**
with **94.15% coverage**. All required gates returned **0**; the table also includes the optional upgrade
visibility check. Historical receipts were recorded in `.foundry/gates.json`; the table lists
the old worktree-local log names. Current receipts supersede them in that file,
with raw logs kept outside the repository.

| Command | Exit | Stdout log in `.foundry/logs/` |
| --- | ---: | --- |
| `MIX_ENV=test mix deps.get` | 0 | `13-1790869599962680551.stdout.log` |
| `MIX_ENV=test mix format --check-formatted` | 0 | `65-1790869602970790303.stdout.log` |
| `MIX_ENV=test mix compile --warnings-as-errors` | 0 | `115-1790869605378260804.stdout.log` |
| `MIX_ENV=test mix deps.unlock --check-unused` | 0 | `165-1790869609487894983.stdout.log` |
| `MIX_ENV=test mix test --cover` | 0 | `213-1790869610502269745.stdout.log` |
| `MIX_ENV=test mix credo --strict` | 0 | `349-1790869623734753306.stdout.log` |
| `MIX_ENV=test mix dialyzer` | 0 | `399-1790869626138536299.stdout.log` |
| `MIX_ENV=test mix docs --warnings-as-errors` | 0 | `451-1790869636347072540.stdout.log` |
| `MIX_ENV=test mix hex.audit` | 0 | `501-1790869638472661497.stdout.log` |
| `MIX_ENV=test mix deps.audit` | 0 | `553-1790869642287818414.stdout.log` |
| `MIX_ENV=test mix sobelow --config` | 0 | `607-1790869644216931919.stdout.log` |
| `MIX_ENV=test mix hex.outdated --all` | 1 | `657-1790869647888172562.stdout.log` |
| `MIX_ENV=test mix precommit` | 0 | `709-1790869651448903001.stdout.log` |

The optional `hex.outdated --all` returned **1** to report possible updates to
`dns_cluster`, `finch` and `sobelow`; it is a visibility check, not a required
gate. No retired/security-advisory packages or dependency vulnerabilities were
reported. Sobelow passed the unchanged repository configuration. No findings
were suppressed, no dependency requirement or lockfile was changed, and no
advisory waiver was added. Credo reported no issues; Dialyzer reported zero
errors, skipped checks or unnecessary skips. Docs compiled without warnings.
`mix precommit` repeated the full required quality alias successfully. A source
search found no `send_after` in `lib/business_web/live/`; no LiveView polling
was introduced. Cold builds emitted existing dependency deprecation warnings;
the starter's own warnings-as-errors compile passed in all three environments.

## Executable source fingerprints

SHA-256 values identify the uncommitted source tested in this worktree:

| File | SHA-256 |
| --- | --- |
| `lib/business/smoke.ex` | `35bd46ba352d93dfe7d929f7f366fd9953bf2e71854855f0bfb594af1f3d54ba` |
| `scripts/smoke.exs` | `38629cdcc13af245262bf927df1519090d6cdf54061124c057d9e1a9b9e39010` |
| `scripts/qualification_seed.exs` | `7e8e78379eef629571d9abc1d2b48d224e210050abd09d902758d890ce848904` |
| `scripts/qualify_callers.py` | `527e51880ba8fd62131055730229cd3abadcce3292546d1d0be5d6c8d89ddbbd` |
| `test/business/smoke_contract_test.exs` | `a5f96b990fa37a7aaf306fc935d5cd945f66135adc17e95b75a02d3b11346321` |
| `test/support/smoke_fault.ex` | `caba76821da0b5b34b496c894b4cbf2a0795fe8fc1ee18364cbce31ae3d41e06` |
| `test/business/exploration_test.exs` | `31e2cf4dd363685817bd2f9392f9eb5a122191fb0c9a2ceeb4a2d2ccb1354cbd` |

The corrected availability probe also passed a real kernel socket check:
`.foundry/logs/2-1790868959099656521.stdout.log` (exit **0**). An active
listener rejected the probe with `EADDRINUSE`; the same listener after closure
with TIME_WAIT permitted the probe. The actual two-state run separately tests
this shutdown/restart behavior with Phoenix on port 4000.

The two quality-test databases were dropped successfully:
`.foundry/logs/2-1790869107851588737.stdout.log` and
`.foundry/logs/2-1790869108236794377.stdout.log` (both exit **0**).

The final quality-run database was removed again after the staff-CSS gates:
`.foundry/logs/2-1790869862023261695.stdout.log` (exit **0**).
The smoke and seed scripts also passed an explicit formatter check (they are
outside the existing default formatter inputs):
`.foundry/logs/2-1790869154240921791.stdout.log` (exit **0**).
