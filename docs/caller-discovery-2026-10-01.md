# Caller discovery — 2026-10-01

Actor: the starter maintainer preparing an owner's workshop. Goal: discover
the real caller qualification's scope before supplying or acquiring Bedrock
source. Interaction: run `python3 scripts/qualify_callers.py --list-checks`.
Discovery now prints a behavioral inventory and exits without qualification
operations. It is never passing behavioral evidence. `--list-checks --proof`
describes the smaller prod-only, unpublished probe, including its omitted
cache/publication/pre-start seed checks. Normal execution still requires
`--bedrock`. Imported helpers and qualification execution are unchanged.

Foundry owns finalization; no commit, push, ref change or deployment occurred.
No customer repository, record, messaging, cloud credentials or production
platform was used. All database records in this run are synthetic.

## Source identities

- Starter baseline: `cf4dd34bbdd8af822a6d70f89ba9a7c97059d600`, plus this
  worktree's correction. No invented correction commit identity.
- Bedrock archive: `78767528c45c0d9412c4cbc90d395c724ed1c5ee`, acquired with
  `git -C /home/svetzal/Work/Projects/Mojility/bedrock archive HEAD` and extracted
  into `.foundry/bedrock-source`. At acquisition, HEAD, local main and origin/main
  matched. Only committed archive contents were inspected, including
  `apps/bedrock/lib/bedrock/explorations/bootstrap.ex` and `preparation.ex`.
- Bootstrap SHA-256:
  `24be9947207a50d9f108c68960351a715cc49fb6cbfeeffaee099f309306ae84`.
- Preparation SHA-256:
  `635f421f32ba3dc5fb1bd523329c4d072110666960cd2eef80011a9251f380f9`.
- Changed `scripts/qualify_callers.py` SHA-256:
  `03525ef867ca8df85be765a410fc1f6fd466a017e1f787468d01637b0224ea62`.
- New `scripts/verify_caller_discovery.py` SHA-256:
  `bab1499e1d50820d4d2bba6fc33f1a008ce2281cf6ea7cab3e3eb8edbd26fa06`.
- Unchanged scene fixture SHA-256:
  `d218c9f590f28e6d986348f32567ed654b81fada3bdf2fc0370633f89e8aaeb2`.
  Compatibility hash and publication provenance were preserved.
- Unchanged `lib/business/smoke.ex` SHA-256:
  `7ccbe5e6381144d569acc19ceb21dacf2dc46612e254e37d0e58bd8b13c88527`.
- Both cold/cached candidates reported content SHA-256
  `7df9c1eb694cf43927d1d92b1d759e2a45e257765821bfd06e5ed861fc5add49`.
  This dated record was added afterward; executable sources were unchanged.
- Elixir `1.20.2-otp-29`, OTP `29.0.2` unchanged and verified by the runner.
  Local PostgreSQL is `16.15`; CI's PostgreSQL 18 was not exercised here.

## Rejecting and corrected discovery

Logs below are basenames under `/home/svetzal/.foundry/tool-logs/`. Every verbose
execution used `foundry capture --`; raw logs stay outside the repository.
`.foundry/proof.json` retains the audited real CLI regression rejection and
correction, with the exact reproducing commands. This is evidence of discovery
behavior; the full qualification has separate execution evidence below.

| Boundary command | Exit | External log |
| --- | --- | --- |
| Original `python3 scripts/qualify_callers.py --list-checks` | 2 | `2-1790903833520469476.stderr.log` |
| Corrected same CLI command, before documentation expansion | 0 | `2-1790903871381539478.stdout.log` |
| New discovery regression suite against HEAD's original CLI | 1 (three failures) | `3-1790903943766878267.stderr.log` |
| `python3 scripts/verify_caller_discovery.py` against corrected CLI | 0 (four tests) | `2-1790903963252500361.stderr.log` |
| Import caller, workshop, release, business-name, cleanup and release-regression modules | 0 | `3-1790904147997389966.stdout.log` |

The rejecting regression run loaded the repository-owned unittest module with
`importlib.util`, wrote `git show HEAD:scripts/qualify_callers.py` into a private
temporary `scripts/` directory, assigned that path to the suite's `CLI`, and
ran `unittest.defaultTestLoader.loadTestsFromModule`. Its discovery tests failed
through real subprocess CLI invocations; the execution-source requirement passed.
The temporary directory was removed on exit.

The passing suite checks meaningful full/proof inventory contents, missing source
rejection for both execution paths, and discovery with unavailable caller and
snapshot paths. Child CLI processes use an empty PATH and a Python audit hook
that rejects subprocess execution, socket/network/listener operations, lock
acquisition, temporary snapshot allocation and filesystem mutations. It asserts
no requested snapshot directory was created. This does not replace full execution.

## Project gates

`MIX_ENV=test mix deps.get` passed (external log
`2-1790904051992995365.stdout.log`). `MIX_ENV=test mix precommit` passed
(`2-1790904076356187589.stdout.log`, corresponding stderr retained).
The alias executed Hex audit, dependency audit, configured Sobelow, format
check, compilation with warnings as errors, unused-dependency check,
`mix test --cover`, strict Credo, Dialyzer and docs with warnings as errors.
Result: 364 passed (12 doctests, 352 tests), 94.12% coverage above 90%, no Credo
issues, zero Dialyzer errors/skips, no retired/advisory packages, no known
dependency vulnerabilities and completed Sobelow scan. Dependency/OTP compilation
emitted upstream Erlang warnings; application compilation and all required gates
passed. No suppressions or dependency/toolchain changes were made.

Quality tools used private Mix/Hex storage in `.foundry/quality-tools`,
`ERL_FLAGS='+S 4:4'` and
`MIX_TEST_PARTITION='_caller_discovery_c10_096740'`. Initial default-storage
attempts failed before tests because the host Hex cache/tool installation is
read-only (`2-1790903974382719047.stderr.log`,
`2-1790903975576115098.stderr.log`, `2-1790904028657492506.stderr.log`).
The corrected environment redirects MIX_HOME, MIX_ARCHIVES and HEX_HOME without
changing pins. `mix hex.outdated --all` returned 1 for available updates
(`2-1790904221119894818.stdout.log`); upgrade visibility is advisory.
`guides/quality.md` still matches the implementation. No `send_after` calls were
found in `lib/business_web/live`. This increment changes no UI or generated-system
behavior, so browser keyboard, light/dark and assistive-technology claims are not
made.

## Full qualification and cleanup

The following command passed with exit 0, invoking the full current-Bedrock
qualifier (no `--proof`) inside the cleanup observer:

```sh
foundry capture -- python3 scripts/verify_qualification_cleanup.py \
  --bedrock .foundry/bedrock-source \
  --bedrock-revision 78767528c45c0d9412c4cbc90d395c724ed1c5ee \
  --case success
```

Full observer log: `2-1790903963738608389.stdout.log` (stderr retained).
Cold preparation: `96-1790903964930416832.stdout.log`.
Cached preparation: `1323-1790904322529730779.stdout.log`.
Production compile/promotion: `2619-1790904649359945260.stdout.log`.
Pre-start retained seed: `2733-1790904662209252644.stdout.log`.
Unpublished smoke: `2825-1790904665525112830.stdout.log`.
Published asset deployment: `2878-1790904676632112647.stdout.log`.
Published smoke: `3029-1790904680696478765.stdout.log`.

Both states exercised real `MIX_ENV=prod` startup on port 4000 and Bedrock's
actual `scripts/smoke.exs` invocation. The unpublished page delivered nonempty
digested CSS with `?vsn=d`; the synthetic published page delivered its published
stylesheet and authenticated staff pages delivered deployed CSS. Actual HTTP
and database assertions verified CSRF refusal without a write, anonymous staff
denial, enquiry field persistence, magic-link sign-in followed by protected
staff reads, exact retained contact/request/source/timestamps/follow-up fields,
and rendered new/retained enquiries. The same retained record was seeded before
startup and checked in both states. Successful check counts alone are not proof.

Cleanup observer reported `listener=false`, `database_exists=false`, empty
snapshots and live children, no shared-lock violations, `lock_released=true`,
and `snapshot_parent_removed=true`. The qualifier removed synthetic database
`qualification_c3b8461351db12c0eea4` (drop log
`3082-1790904693068380744.stdout.log`) and its private snapshot parent.
The quality test database was separately dropped successfully
(`2-1790904645781911934.stdout.log`). The shared lock file remains for other runs.
This run observes success cleanup; failure/SIGINT/SIGTERM handlers are unchanged,
and discovery inventories those existing paths without claiming they were rerun.

The Bedrock archive and private quality tool caches were removed after use.
Only source changes, this sanitized record and `.foundry/proof.json` remain;
raw logs remain external. Final discovery regressions passed again
(`2-1790904475776713167.stderr.log`), proof shape/log existence and
`git diff --check` passed. No published output, component compatibility hash,
dependency, toolchain version, sibling repository or generated-system behavior
was changed.

This verifies local synthetic preparation/enquiry/staff behavior. It does not
verify email delivery, a customer's completed service Goal, live customer data,
hosted isolation, public HTTPS readiness, deployment or owner acceptance.
A Contacted status does not prove a reply was sent. Browser keyboard and
assistive-technology verification remain outside this CLI-only increment.
