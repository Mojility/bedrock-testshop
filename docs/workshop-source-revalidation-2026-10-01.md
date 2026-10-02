# Workshop source revalidation — 2026-10-01

Beneficiary: `bedrock.actor.field_service_owner`. Goal:
`bedrock.goal.own_business_system`. Interaction:
`bedrock.interaction.open_workshop_promptly`. Scope is the Workshop source-drift
gap from cycle 4; the preparation and interrupted-cleanup corrections are retained.
Foundry owns Git finalization. No refs, sibling sources, customer records, runtime
requirements, publication provenance or compatibility hashes were changed.

## Immutable inputs and source checks

On Canadian workstation `mojility-ops-01`, caller HEAD and `origin/main` agreed:
Workshop `6dc82a749f77548ed5488b7fa25d303d0c655795`; Bedrock
`426ba1ba37c550a4fc793e598bb984d8b8a817b2`. Each was acquired with
`git -C <owning-repository> archive <identified-HEAD>` into a fresh disposable
archive directory. No caller worktree files were read as source. Starter candidate
`7d102f2d760e1d4be07195f17910e2d41e35ec7a` is extracted from its committed archive,
without any overlay of the supervisor worktree. Its archive SHA-256 is
`bd3f44035ef53ee28df8d1ff3cef0d90c3a868918f1f5d904945c909538be362`.

`scripts/qualify_workshop.py` now resolves full commit identities from read-only
Git object stores and compares every committed file with the executing archive
before execution. It records the caller and candidate manifests before building,
checks candidate source and lock preservation after gates, and checks caller
preservation after snapshot cleanup on success or failure. Derived guidance is
hydrated through Workshop's existing producer and retains separate revision/hash
provenance. Advisory revisions and matching commands cannot establish identity.
`.foundry/source-identities-c5.json` identifies the supervisor and retained external
source; `.foundry/workshop-c5.json` contains the committed file manifests.

Cycle-4's recorded executing Workshop hashes still match its declared commit
`9bfe35ffc6cca45fc83d260193208d44fd934cc7`. Twelve recorded executable paths differ
from current Workshop trunk. Earlier evidence remains valid for its older source;
it does not qualify today's caller. All earlier proof files are preserved,
including `.foundry/proof-c4.json`.

## Real boundary rejection and smallest starter correction

Labeling the fresh current Workshop archive with the older cycle-4 revision was
rejected before application startup: exit 1, external stderr
`/home/svetzal/.foundry/tool-logs/2-1790887316862707468.stderr.log`. The rejection
lists mismatching committed files, including `runner.ex`, `source.ex`,
`local_command.ex` and `scripts/qualify_starter.*`; this is a byte mismatch,
not a marker or command-count check.

The first correctly identified full run reached the real `Runner.check` boundary
and exited 1 (nested boundary command exit 2). The starter-owned
`scripts/check_workshop_boundaries.exs:49` still required harmless HEEx prose
ending in `Bedrock.` to fail. Current Workshop parses template expressions and
correctly accepts prose. Actual result was `status=passed, files=[]`, so the
starter assertion rejected a correct caller outcome. External log:
`/home/svetzal/.foundry/tool-logs/2-1790887333463680286.stdout.log`.
`.foundry/workshop-boundary-rejection-c5.json` preserves its report; independent
PostgreSQL, socket and filesystem observations in
`.foundry/rejecting-cleanup-c5.json` found both databases and snapshot removed,
with no listener and no observer recovery required.

The smallest correction makes the negative input `{Bedrock.Sites.name()}` and
retains the assertion that the real source-separation gate rejects it, followed
by acceptance of explanatory prose. The retained-test removal/restoration
assertions remain. No gate implementation or assertion was weakened. The pinned
corrected boundary command exits 0:

```sh
# cwd: /tmp/starter-c5-sources/bedrock-workshop
foundry capture -- env MIX_HOME=/tmp/starter-c3-tools/mix HEX_HOME=/tmp/starter-c3-tools/hex ERL_FLAGS='+S 4:4' mise exec elixir@1.20.2-otp-29 erlang@29.0.2 -- mix run --no-start /home/svetzal/.foundry/worktrees/bedrock-system-template/starter-caller-contracts-v1-c5-3683f7/scripts/check_workshop_boundaries.exs
```

External log: `/home/svetzal/.foundry/tool-logs/2-1790887834274329254.stdout.log`.
`.foundry/proof.json` links the real rejection and corrected acceptance. Two
preliminary launch commands used the wrong edit working directory; their edits
failed without writing source, and their probes loaded the subsequently corrected
file. They are excluded from acceptance evidence; the pinned command above is
the explicit corrected probe.

## Qualification, remappings and limits

The full current-source revalidation command and its external driver are retained
in `.foundry/full-run-c5.json` and
`/home/svetzal/.foundry/tool-logs/starter-c5-revalidate.py`. It invokes:

```sh
foundry capture -- env MIX_HOME=/tmp/starter-c3-tools/mix HEX_HOME=/tmp/starter-c3-tools/hex python3 scripts/qualify_workshop.py --workshop /tmp/starter-c5-sources/bedrock-workshop --workshop-revision 6dc82a749f77548ed5488b7fa25d303d0c655795 --workshop-repository /home/svetzal/Work/Projects/Mojility/bedrock-workshop --bedrock /tmp/starter-c5-sources/bedrock --bedrock-revision 426ba1ba37c550a4fc793e598bb984d8b8a817b2 --bedrock-repository /home/svetzal/Work/Projects/Mojility/bedrock --starter-revision 7d102f2d760e1d4be07195f17910e2d41e35ec7a --report .foundry/workshop-c5.json
```

Remappings remain the existing off-guest qualification boundaries: disposable
PostgreSQL role/databases on the local socket; canonical generated guidance;
writable local Mix/Hex caches; Workshop's qualification launcher for its real
broker argv/environment and protected wrappers. Independent LocalCommand boot
and smoke run in a separate disposable copy with only local database role/name
appended to runtime configuration. No installed-runtime requirement changes.
Elixir `1.20.2-otp-29`, OTP `29.0.2` and PostgreSQL 18 are unchanged.

The independent observer runs beside the qualifier in the same process namespace,
samples the shared port lock and listener, tracks owned groups, independently
queries PostgreSQL, and checks snapshot removal before any recovery. Lock ordering is sampled, not a
proof against every scheduling race; the earlier interruption matrix is retained.
It also
reads every retained synthetic enquiry field directly from PostgreSQL after boot,
comparing contact, request, source, timestamps, legacy identity and follow-up with
the pre-start seed. PostgreSQL UTC timestamps without time zones are normalized
as UTC instants for this comparison. Receipts and IDs alone are not acceptance.
Initial read-only observers were stopped after the rejected run; they created no
application resources. They are superseded by the final supervising observer.

This proves local command compatibility and behavior, not installed guest sudo,
systemd sandbox, read-only source mounts, network isolation, cgroups, lifecycle
leases, browser HTTPS/partitioned-cookie behavior, live customer data, owner
acceptance or deployment. No UI changes or new accessibility conformance claim
are made; prior keyboard and assistive-technology limits remain. A retained
Contacted status does not prove a reply was sent or the customer's goal achieved.

## Observed full-run results

The supervising command `foundry capture -- python3
/home/svetzal/.foundry/tool-logs/starter-c5-revalidate.py` exits **0**, outer log
`/home/svetzal/.foundry/tool-logs/2-1790887931007491743.stdout.log`. The qualified
command above exits **0**, external log
`/home/svetzal/.foundry/tool-logs/13-1790887931040920136.stdout.log`.
`.foundry/proof.json` now points its corrected object at this full behavior;
`.foundry/workshop-boundary-proof-c5.json` preserves the smallest pinned probe.
`.foundry/identity-rejection-c5.json` records the exact false-label command;
`.foundry/drift-audit-c5.json` records old/current committed-byte comparisons.

All **14 current completion gates passed**, with the real protected coverage
wrapper reporting **94.11%** against the unchanged **90%** threshold. Independent
LocalCommand boot/smoke passed. The isolated owner flow returned the exploration
cookie with Secure, HttpOnly, SameSite=None and Partitioned attributes; the real
staff request returned HTTP 200 and PostgreSQL confirmed `owner:true` session
storage. Real smoke denied the CSRF write without inserting a record, denied
anonymous staff access, delivered nonempty deployed CSS, persisted all submitted
enquiry fields, created the magic-link session and authenticated staff reading of
both new and retained enquiries. It verified retained contact, request, source,
timestamps and follow-up against the pre-start seed. The independent SQL
observation in `.foundry/retained-observation-c5.json` records expected and observed
values for every field, rather than only an ID or a successful receipt.

Candidate committed source and `mix.lock` remained unchanged. Both caller
committed-file manifests matched afterward. Generated guidance provenance is
Bedrock `426ba1ba37c550a4fc793e598bb984d8b8a817b2` and public Phoenix profile
`ccd0b4b574dbe21f6152e8381541b491b7362453`; source hashes are in the report.
Workshop's separate advisory revision is
`5246bccd929b29309a014670b41ed2f2c6918c39`; it is not caller identity evidence.

The independent observer made 7,200 lock/listener samples, found no listener
surviving observed lock release, no remaining owned process groups, no matching
synthetic databases and no candidate snapshot. No recovery was needed.
`.foundry/cleanup-c5.json` retains these observations. Ordinary ignored dependency,
build and PLT caches were copied from the completed disposable build to the
supervisor worktree for repository quality checks; no candidate source was
changed. Previous preparation/publication and interrupted-cleanup evidence is
preserved and is not relabeled as a new run against current Bedrock preparation.

No caller-owned defect was confirmed. The caller's dependency compilation emitted
a UUID `use Bitwise` deprecation warning, and initial PLT construction emitted
OTP `xmerl` missing-spec messages; these were external dependency/toolchain output.
The actual starter compile gate used warnings-as-errors and passed, strict Credo
passed, and final Dialyzer reported zero errors and no skips. No suppressions,
allowlists or dependency versions were changed.

## Repository quality and final cleanup

The first repository-quality driver carried qualification's disabled-mail
settings into ordinary tests. The pending-notification regression correctly
failed because its in-memory test mailbox received no message. This was driver
setup, not an application defect; no assertion or business source was changed.
`.foundry/quality-c5-setup-rejection.json` preserves the failing commands/logs,
and `.foundry/quality-setup-cleanup-c5.json` verifies its unique database and Hex
cache were removed. Corrected execution uses the configured test mail adapter.

The corrected quality driver exits **0**, external log
`/home/svetzal/.foundry/tool-logs/2-1790888879596620874.stdout.log`. Every required
gate, standalone `mix test` and `mix precommit` passed. Coverage is **94.11%**
against **90%**, with **345 tests and 12 doctests** passing. Strict Credo found
no issues; compile warnings-as-errors, Dialyzer, documentation warnings-as-errors,
Hex audit, dependency audit and Sobelow passed. `hex.outdated --all` returned 1
for upgrade visibility, not an advisory suppression or a required-gate failure.
`.foundry/quality-c5.json` retains exact commands, pinned environment and external
log paths. `rg send_after lib/business_web/live` found no occurrences. Unique
test database, Hex cache and the attempted runtime-home cache were removed;
`.foundry/quality-cleanup-c5.json` includes the independent database query.

MixAudit's internal refresh attempted to write the read-only shared cache and
printed a Git error despite task exit 0. An Erlang `-home` probe did not change
Elixir's `System.user_home()`, so the second run did not redirect this cache.
Instead, `foundry capture -- python3
/home/svetzal/.foundry/tool-logs/starter-c5-audit-source.py` exits **0**, log
`/home/svetzal/.foundry/tool-logs/2-1790888973334549382.stdout.log`. It freshly
resolved public advisory main to `935abf7410a2bbb18e12579dee6e31267c3ed244`,
downloaded that immutable tarball, and compared the complete set and hashes of
every `packages/**/*.yml` file consumed by MixAudit with the shared cache. All
bytes matched; `.foundry/quality-advisories-c5.json` retains the manifest and empty
difference set. The final audit runs against these independently verified bytes.
No library internals, Git refresh failures or advisories were mocked, hidden,
suppressed or allowlisted. No shared cache or repository refs were edited.

Before removing the task-owned caller archive parent `/tmp/starter-c5-sources`,
every committed caller file was again compared with its declared Git archive;
all matched. Both caller archives and their derived caches were then removed.
`.foundry/archive-cleanup-c5.json` records preservation and independently observed
removal. Shared caches from previous cycles remain untouched. Final exact audit
and documentation commands, results and cache removal are retained in
`.foundry/final-c5.json`. Changes remain uncommitted for Foundry review.
