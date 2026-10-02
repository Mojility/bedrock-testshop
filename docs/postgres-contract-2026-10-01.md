# PostgreSQL major contract ownership — 2026-10-01

Actor: `bedrock.actor.field_service_owner`. Goal:
`bedrock.goal.own_business_system`. Interaction:
`bedrock.interaction.open_workshop_promptly`. This increment resolves only who
owns the unresolved PostgreSQL major discrepancy. It adds an ownership finding
and synchronizes `SYSTEM.md`; it changes no executable application behavior.

## Source acquisition and reproduction

Read the campaign `BRIEF.md` and starter inbox under
`/home/svetzal/Work/Operations/Planning/campaigns/2026-10-01-bedrock-owner-journey/`
before inspection. The brief's PostgreSQL item is a lead to verify, not authority
to infer a hosted major from CI. Starter baseline:
`8864e85fb8e2ec61bf9593b6d3b2cea6d2929e3f`.

Read only immutable archives of permitted sibling repositories. At acquisition,
HEAD and local `origin/main` agreed for each:

| Repository | Exact source |
| --- | --- |
| Bedrock | `c87fbdbe7213546445340140a464ccff478bba70` |
| Roost | `bb57e6d0bf2bff3af72d40ad9adb5fa7c34d81b8` |
| Workshop | `96dcc50c5015a9986f7d7573c0be9b698baf27c4` |

Acquisition command, repeated for `bedrock`, `roost`, `bedrock-workshop`:

```sh
repo=bedrock
git -C /home/svetzal/Work/Projects/Mojility/$repo rev-parse HEAD refs/remotes/origin/main
git -C /home/svetzal/Work/Projects/Mojility/$repo archive HEAD -o /tmp/postgres-contract-$repo.tar
mkdir -p /tmp/postgres-contract-$repo
tar -xf /tmp/postgres-contract-$repo.tar -C /tmp/postgres-contract-$repo
```

For later reproduction, archive the exact recorded commit rather than a moving
HEAD. No sibling working-tree content, customer repository, operational record,
credentials or remote service was used. Local remote-tracking equality is not a
fresh fetch; the identities delimit this observation.

The smallest acceptance probe ran **before** documentation expansion and the
quality suite:

```sh
foundry capture -- python3 .foundry/postgres-ownership-probe.py
```

It exited **0**, with external log
`/home/svetzal/.foundry/tool-logs/2-1790905302613923857.stdout.log`.
The retained probe asserts the starter 18 pin and CI's use of it; the two caller
CI services at 16; Roost's recorded 18.6 guest/RDS qualification; and the guest
major rejection before restore. It creates a UUID-named synthetic database,
executes `psql --no-psqlrc -d <synthetic-database> -Atc 'SHOW server_version'`,
and drops it in `finally`. The real local server returned
`16.15 (Ubuntu 16.15-0ubuntu0.24.04.1)`. That observation is local, not hosting.
No application tables or production database contents were inspected.

`.foundry/proof.json` uses `kind=direct` because the authorized outcome is a
source-grounded ownership finding, not a starter behavior change. It points to
this passing probe and explains the boundary. The previous caller-discovery
behavioral proof remains in `.foundry/caller-discovery-proof.json`; no earlier
qualification or smoke assertion was replaced or weakened.

## Observed declarations and ownership

| Boundary | Exact location | Evidence |
| --- | --- | --- |
| Starter pin/CI | `.tool-versions:3`, `.github/workflows/build.yml:45`, `:58`, `:139` | Pin 18; CI service reads that pin |
| Bedrock integration | `.github/workflows/integration.yml:86`, `:170` | Service 16 and `postgresql-16` tools |
| Roost CI | `.github/workflows/check.yml:16`, `:41` | Service 16 and `postgresql-16` tools |
| Roost provisioned guest record | `docs/development-environment-qualification.md:10`, `:134` | Recorded 18.6 AMI toolchain; successor reuses it |
| Roost installed guest contract | `infra/environments/install.py:76`, `priv/cell/environment_guest.py:65` | Operator profile supplies `postgres_major`; server mismatch rejects before restore |
| Roost guest provisioning | `priv/cell/environment.py:116` | EC2 image comes from the operator profile's `image_id`, not starter CI |
| Roost RDS record/clone selection | `docs/postgresql-18-maintenance.md:5`, `priv/cell/runner.py:363`, `:642` | Recorded RDS upgrade to 18.6; distinct pinned RDS image selected for bound database rehearsals |
| Starter local Compose | `docker-compose.yml:18` | Local service 16, unchanged; separate from workshop provisioning |

Source hashes printed by the probe:

| Source | SHA-256 |
| --- | --- |
| Starter `.tool-versions` | `811d30dd301032838b35f9db20977d6d0a503cdbfd522a526596a7951178e554` |
| Starter build workflow | `caa6b5c79f1eadbd446a206cdaf7784f42f7d0f95550d02c65a0417ec05ccedd` |
| Bedrock integration workflow | `da1dac5fe25a61dbd0096f988269c58ab36d71458f7afb02f16258e34d8b4a06` |
| Roost CI workflow | `94de99b5232ed99cebb7b1aee5528aa965f7750d2a51c220e0e69f6ad2dd51f1` |
| Roost guest executor | `0ea639dda1dbd4d5715924bb4ea6a7c9865955607ad5a217fc5b2c6adaa0997c` |
| Roost guest qualification record | `51a0cb4be2a07040093cd9e5270881329bca4ca0fd1406b394d47c445f4034a3` |
| Roost engine maintenance record | `ca5d37822c032cd6395991891f670188b9a7a7c0add8c7cc26cab22022c29120` |
| Roost runner | `15cd443d9bdbb25b1129025af29e9a22e55091c61ffecc4837b56f35691ed13f` |

**Named ownership:** Bedrock integration CI and Roost CI maintainers own the
remaining qualification mismatch. Roost's qualified AMI/profile owns the
workshop runtime choice. The starter's 18 pin agrees with that committed runtime
record, so retain it. Practical consequence: owner-journey CI at 16 does not
prove the runtime behavior at 18. The smallest owning correction is to align
those callers' CI service images and isolated-test PostgreSQL tool packages with
18 and rerun their integration/database checks. No sibling changes were made.

## Limits and cleanup

Committed provisioning records describe prior hosted observations; no live AWS,
RDS, AMI or workshop was contacted. The unbound runner image's digest was not
resolved to a major or executed. No current hosted state, PostgreSQL 18 run,
upgrade compatibility, whole live Journey, owner acceptance or deployment is
established here. The existing local Compose 16 declaration remains unchanged
under the prohibition on changing hosting configuration or retained contents.
Contacted status still does not establish a sent reply or the customer's goal.

No listener or port lock was needed for this documentation probe. The synthetic
probe database was removed. Quality checks use a separate unique test database
and writable temporary Mix/Hex storage; their results and cleanup are recorded
below. Caller archives, temporary tooling and build outputs are removed after
checks. Elixir/OTP, migrations, credentials, hosting configuration, published
outputs, compatibility hashes and all smoke assertions remain unchanged.
Preserved SHA-256 identities: `scripts/qualify_callers.py`
`03525ef867ca8df85be765a410fc1f6fd466a017e1f787468d01637b0224ea62`,
`lib/business/smoke.ex`
`7ccbe5e6381144d569acc19ceb21dacf2dc46612e254e37d0e58bd8b13c88527`,
and `test/fixtures/website_scene.json`
`d218c9f590f28e6d986348f32567ed654b81fada3bdf2fc0370633f89e8aaeb2`.

## Quality gates

All required gates passed. Full logs stay under
`/home/svetzal/.foundry/tool-logs/`; the table gives their stdout basenames.
Corresponding stderr paths and exit codes are retained in
`.foundry/postgres-quality.json` (initial run) and
`.foundry/postgres-quality-final.json` (corrected docs, plain tests and full
precommit rerun). Every verbose command used `foundry capture --`.

| Command | Exit | External stdout log |
| --- | --- | --- |
| `MIX_ENV=test mix deps.get` | 0 | `55-1790905407231869810.stdout.log` |
| `MIX_ENV=test mix format --check-formatted` | 0 | `173-1790905413804883832.stdout.log` |
| `MIX_ENV=test mix compile --warnings-as-errors` | 0 | `495-1790905507329498970.stdout.log` |
| `MIX_ENV=test mix deps.unlock --check-unused` | 0 | `593-1790905517529196627.stdout.log` |
| `MIX_ENV=test mix test --cover` | 0 | `689-1790905518676494434.stdout.log` |
| `MIX_ENV=test mix credo --strict` | 0 | `873-1790905529560628990.stdout.log` |
| `MIX_ENV=test mix dialyzer` | 0 | `971-1790905532469454866.stdout.log` |
| `MIX_ENV=test mix docs --warnings-as-errors` | 0 | `52-1790905734788632163.stdout.log` |
| `MIX_ENV=test mix hex.audit` | 0 | `1169-1790905675888404788.stdout.log` |
| `MIX_ENV=test mix deps.audit` | 0 | `1269-1790905678471532427.stdout.log` |
| `MIX_ENV=test mix sobelow --config` | 0 | `1371-1790905679657453806.stdout.log` |
| `MIX_ENV=test mix precommit` | 0 | `286-1790905743136233486.stdout.log` |
| `MIX_ENV=test mix test` | 0 | `150-1790905736751393763.stdout.log` |

Results: 364 passed (12 doctests, 352 tests); coverage **94.12%**, exceeding
90%; strict Credo found no issues; Dialyzer reported zero errors/skips;
Hex audit found no retired/advisory packages; dependency audit found no
vulnerabilities; configured Sobelow completed. The precommit alias reran all
its quality/security gates successfully. No advisory suppression, dependency
change or toolchain change was made. Dependency compilation/PLT construction
emitted upstream warnings; the application warnings-as-errors gate passed.

The initial docs gate and precommit exited 1 because newly added Markdown links
in `SYSTEM.md` targeted files outside ExDoc's extras. Changing those links to
plain file references fixed the warnings; standalone docs and the full
precommit rerun both exited 0. Initial failure logs remain in the initial-run
JSON. `mix hex.outdated --all` exited 1 for available updates, which is advisory
visibility rather than an audit failure (stdout
`1613-1790905701648385288.stdout.log`). No repeating LiveView `send_after` was
found by `rg -n 'send_after' lib/business_web/live` (exit 1, no matches).
`guides/quality.md` and module documentation need no API changes for this
prose-only finding. No new browser, dark-mode or assistive-technology
verification is claimed.

The suite used pinned Elixir `1.20.2-otp-29` / OTP `29.0.2`, `MIX_ENV=test`,
`ERL_FLAGS='+S 4:4'`, temporary writable `MIX_HOME`, `MIX_ARCHIVES`, `HEX_HOME`
under `/tmp/starter-c11-tools`, and unique `MIX_TEST_PARTITION` suffixes
recorded in the two JSON files. Both finalizers returned 0 from
`dropdb --if-exists --force <synthetic-test-database>`. PostgreSQL truncated the
final run's long database identifier to 63 bytes; creation and removal resolved
to that same isolated name. No default/shared test database was used.
`.foundry/postgres-cleanup.json` records final absence checks and resource
removal. Foundry owns Git finalization; this task made no commit, push or
ref changes and leaves the source modifications for review.
