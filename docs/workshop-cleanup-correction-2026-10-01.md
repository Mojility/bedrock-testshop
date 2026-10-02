# Workshop cleanup correction — 2026-10-01

Beneficiary: `bedrock.actor.field_service_owner`. Goal:
`bedrock.goal.own_business_system`. Interaction:
`bedrock.interaction.open_workshop_promptly`. An owner completing a Workshop
needs the starter's qualification resources removed even when its operator
interrupts final cleanup. This increment corrects only that starter harness.

Starter baseline: `116969003b5c4d5c332d0169d3db613eab64af34`, incorporating the
existing c3 work. Foundry owns Git finalization; no refs were changed. The
preserved qualifier SHA-256 is
`4d860c64f69d8a07187c6bd6bb642c8d67134b7e711c65e3a97e380b7f2e86f7`;
the correction SHA-256 is
`054f7296d82403820281e4be5d31c66eab547b1ab574a4293cc2cf4dbc069b4d`.
The preserved file is retained externally at
`/home/svetzal/.foundry/tool-logs/workshop-cleanup-preserved-c4.py`.

## Rejection and correction through real cleanup boundaries

Commands below ran through `foundry capture --`; logs are external under
`/home/svetzal/.foundry/tool-logs/`. The executable observer extracts the actual
qualifier finalizer with Python AST, executes it in the real monitored snapshot
and shared port-lock contexts, and uses the actual `stop_pid`, PostgreSQL
commands and filesystem cleanup. No cleanup function is mocked. A real Python
TCP listener on port 4000 acknowledges SIGTERM but survives until SIGKILL, so
shutdown interruption occurs during the real wait. In the database case, a
transparent executable pauses before exec of real `dropdb`, creating a
repeatable signal window without replacing its database operation or result.
A second unique database reveals a skipped remainder of the cleanup loop.

```sh
foundry capture -- python3 scripts/verify_workshop_cleanup.py --source /tmp/workshop-cleanup-preserved-c4.py --stage shutdown
foundry capture -- python3 scripts/verify_workshop_cleanup.py --source /tmp/workshop-cleanup-preserved-c4.py --stage database --signal SIGINT
foundry capture -- python3 scripts/verify_workshop_cleanup.py --stage shutdown
foundry capture -- python3 scripts/verify_workshop_cleanup.py --stage database --signal SIGINT
```

| Boundary | Observer exit | Qualifier exit | Log |
| --- | ---: | ---: | --- |
| Preserved shutdown, SIGTERM | 1 | 143 | `2-1790885157603867015.stdout.log` |
| Preserved database cleanup, SIGINT | 1 | 130 | `2-1790885185357622365.stdout.log` |
| Corrected shutdown, SIGTERM | 0 | 143 | `2-1790885195788449768.stdout.log` |
| Corrected database cleanup, SIGINT | 0 | 130 | `2-1790885220922544422.stdout.log` |

Shutdown rejection observed a surviving owned listener and database after the
lock was released. Database rejection independently queried PostgreSQL and found
the second database retained after the first drop completed. Corrected runs
observed no live owned group, no matching databases, no snapshot, and no
listener-after-lock-release violation. Observer recovery happens only after
these acceptance observations, and removed every resource leaked by rejection.
The worker's signal exit is expected; observer exit zero means resource and
ordering assertions passed, not that the interrupt vanished.

`.foundry/proof.json` uses the brief's required behavioral shape and links the
shutdown red/green evidence. Previous Workshop proof is preserved as
`.foundry/proof-c3.json`; accumulated preparation and smoke regressions remain.
The full corrected signal matrix invokes the observer for each combination of
`--stage shutdown|database` and `--signal SIGTERM|SIGINT`, through the retained
external driver `starter-c4-signal-matrix.py`. Results and exact argv are in
`.foundry/workshop-cleanup-c4.json`.

Two initial observers timed out waiting for the shared port; another encountered
port reuse after a prior listener stopped. These setup failures are not rejecting
behavioral evidence. They were recovered, including their empty synthetic
snapshots. The listener now uses SO_REUSEADDR and the observer tolerates the
shared lock queue. No other caller's listener or lock ownership was disturbed.

## Current committed caller revalidation

Caller sources are permitted `git archive HEAD` copies, with no uncommitted
sibling files read. Bedrock HEAD and origin/main both identify
`426ba1ba37c550a4fc793e598bb984d8b8a817b2`, newer than c3's recorded source.
Workshop archive: `9bfe35ffc6cca45fc83d260193208d44fd934cc7`.

```sh
git -C /home/svetzal/Work/Projects/Mojility/bedrock archive HEAD | tar -x -C /tmp/starter-c4-bedrock
git -C /home/svetzal/Work/Projects/Mojility/bedrock-workshop archive HEAD | tar -x -C /tmp/starter-c4-workshop
foundry capture -- env HEX_HOME=/tmp/starter-c4-hex python3 scripts/qualify_workshop.py --workshop /tmp/starter-c4-workshop --workshop-revision 9bfe35ffc6cca45fc83d260193208d44fd934cc7 --bedrock /tmp/starter-c4-bedrock --bedrock-revision 426ba1ba37c550a4fc793e598bb984d8b8a817b2 --report .foundry/workshop-c4.json
foundry capture -- python3 scripts/verify_qualification_cleanup.py --bedrock /tmp/starter-c4-bedrock --bedrock-revision 426ba1ba37c550a4fc793e598bb984d8b8a817b2 --case success
```

Workshop's first attempt could not persist the sandbox's read-only default Hex
cache. It exited 1 (`2-1790885222126196073.stdout.log`) and removed both databases,
all owned groups and its snapshot; `.foundry/workshop-c4-environment-rejection.json`
retains the report. The retry remaps only HEX_HOME to a disposable writable copy
of public package cache. Existing qualification remaps remain: exact archived
source acquisition plus candidate changes, pinned mise executable paths, local
PostgreSQL role and unique database names via the caller's runtime overlay,
canonical generated packaging guidance, and explicit Secure cookie transport
over loopback HTTP. Local boot uses a separate copy with only its role/database
configuration remapped. No completion gate, caller argv, receipt, compatibility
hash, source model or production cookie policy is substituted.

An initial preparation run completed the real staging build but rejected because
this run updated documentation while the qualifier was checking source stability
(`2-1790885238532466341.stdout.log`, exit 1). It removed its snapshot and never
started a server or created its database. That attempt is not runtime acceptance.
The rerun freezes source during qualification; final evidence prose is completed
afterward. Bedrock producer module hashes remain unchanged:
`bootstrap.ex` = `24be9947207a50d9f108c68960351a715cc49fb6cbfeeffaee099f309306ae84`,
`preparation.ex` = `635f421f32ba3dc5fb1bd523329c4d072110666960cd2eef80011a9251f380f9`.

## Verification boundary

The probes use local PostgreSQL 16.15; the project pin remains 18. Elixir
`1.20.2-otp-29` and OTP `29.0.2` remain pinned exactly. This is Canadian workstation
qualification, not hosted isolation, live customer-data verification, public
HTTPS readiness, deployment, owner acceptance or assistive-technology conformance.
There is no UI behavior change in this increment. Synthetic mail and lead
notifications are disabled. Retained Contacted status does not prove a reply was sent
and establishes no customer service outcome; capture and staff reading are the
verified behaviors. No customer repository, record, mail, cloud credential,
production service or destructive migration was used.

Quality commands and exact capture paths are recorded in `.foundry/quality-c4.json`.
The driver uses a uniquely named `business_test_c4_*` database and a writable
public Hex cache, stops after applicable results are recorded, and drops its
database on exit. Its initial setup tried dependency task help before compilation;
that setup failed (`2-1790885350813283853.stdout.log`) and cleaned its database.
The corrected driver compiles dependencies before reading their task help.

## Completed results and cleanup

Full Workshop command above: exit **0**,
`/home/svetzal/.foundry/tool-logs/2-1790885288568520763.stdout.log`.
All 14 real Contract/Runner gates passed. Protected coverage remained **94.11%**;
source-separation and retained-test integrity rejection probes also passed.
The isolated login returned staff HTTP 200, created a stored `owner:true` session,
and displayed the retained contact, request and follow-up. Independent LocalCommand
boot/smoke passed. The protected candidate SHA-256 is
`f5d064e547a2f28fc2f69c474c255ff280718c51c768b9c34b252445dcaaef90`;
its source and `mix.lock` were unchanged throughout execution. Both Workshop
synthetic databases were removed, all owned process groups stopped, and the
snapshot was removed without cleanup errors. `.foundry/workshop-c4.json` includes
the complete file manifest, exact gate argv, environments and external artifacts.
`.foundry/candidate-preservation-c4.json` byte-compares every executing Workshop
file with its declared committed source. Only documentation evolved afterward.

The corrected final-cleanup matrix exited **0** at
`/home/svetzal/.foundry/tool-logs/2-1790885303669489549.stdout.log`:

| Stage | First signal | Observer exit | Worker exit | External log |
| --- | --- | ---: | ---: | --- |
| Shutdown | SIGTERM | 0 | 143 | `13-1790885303718239604.stdout.log` |
| Shutdown | SIGINT | 0 | 130 | `55-1790886021531657582.stdout.log` |
| Database cleanup | SIGTERM | 0 | 143 | `97-1790886282257931106.stdout.log` |
| Database cleanup | SIGINT | 0 | 130 | `139-1790886293381139168.stdout.log` |

Each observation independently found no live owned listener/group, either
synthetic database or snapshot, and no listener surviving lock release. Each
resource observation occurred before observer recovery. Database-specific
red/green evidence is also preserved in
`.foundry/workshop-cleanup-database-proof-c4.json`.

Current Bedrock full preparation command above: exit **0**,
`/home/svetzal/.foundry/tool-logs/2-1790885681999504241.stdout.log`.
Initial and cached-stage source SHA-256 both equal
`79387a14c80d275103f87517c74e5a26669e8f49c4831813bdcf8710c99c0337`.
The difference from the Workshop manifest is documentation; executable source
remained identical. Real staging, cache promotion, runtime compilation and
asset deployment passed. Both unpublished and compatible synthetic published
production scenes passed actual HTTP/database smoke on port 4000 using
`scripts/smoke.exs`. Unpublished CSS was the nonempty delivered
`/assets/css/app-3aecb787d45ad122b1f4204162da52d0.css?vsn=d`; publication delivered
`/assets/published/site.css` and digested staff assets. Smoke denied CSRF writes,
denied anonymous staff access, verified submitted enquiry fields, created a
magic-link session and read both new and pre-start retained enquiries with their
contact, request, source, timestamps and follow-up intact. The retained enquiry
survived both publication states. Publication outputs were changed only in the
disposable runtime, with the existing fixture compatibility hash preserved.

The independent preparation observer found no listener, live child, database or
snapshot after completion, no lock-order violation, and removed its snapshot
parent. Its lock sampling is evidence of observed ordering, not a mathematical
proof against every scheduling race. No gates were weakened. Caller constructor
compilation initially warns about unavailable Ecto.UUID before dependencies
exist in the isolated stage; the real app compilation gates pass without
warnings. This is a constructor-loading limitation, not a confirmed caller
behavior defect. No caller-owned blocker was confirmed by this run.

Exact caller-produced command strings and SHA-256 are retained in
`.foundry/bedrock-command-bytes-c4.json`, before the documented local path and
source-acquisition remappings; the runtime execution log retains their executed
forms. The command-byte extraction itself ran as
`foundry capture -- python3 /tmp/starter-c4-command-bytes.py`, exit 0,
`2-1790886429175666848.stdout.log`; its source is retained externally.
Bedrock's two executing producer files and all Workshop executing source files
were compared with their declared committed archives before those disposable
archives were removed.

All eleven required repository gates, standalone `mix test`, and `mix precommit`
passed. Coverage was **94.11%** against the unchanged **90%** threshold; 345 tests
and 12 doctests passed. Strict Credo reported no findings, Dialyzer no errors,
and Hex audit, dependency audit, Sobelow and documentation checks passed.
`hex.outdated --all` returned 1 for upgrade visibility; no advisory was suppressed
and no dependency was changed. The quality run's outer log is
`/home/svetzal/.foundry/tool-logs/2-1790885420246013222.stdout.log`; its exact
argv, environment and individual log paths are in `.foundry/quality-c4.json`.
`rg send_after lib/business_web/live` found no occurrences. No new UI acceptance
claim is made; existing browser and assistive-technology evidence limits remain.
Final documentation verification and independent cleanup results are retained
in `.foundry/final-c4.json`. Git finalization remains with Foundry.
