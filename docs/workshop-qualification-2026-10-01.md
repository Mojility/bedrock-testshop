# Workshop caller qualification — 2026-10-01

Beneficiary: `bedrock.actor.field_service_owner`. Outcome:
`bedrock.goal.own_business_system`. Interaction:
`bedrock.interaction.open_workshop_promptly`. This increment qualifies the starter
boundary using caller-owned execution, so a green starter suite cannot conceal a
failure when an owner opens or completes a Workshop.

Source identities:

- Starter baseline: `23e0fd64940bcbec23edd766034fb93c82330eca`, plus the working
  source changes identified by the candidate hash and file manifest in
  `.foundry/workshop.json`.
- Workshop committed archive: `9bfe35ffc6cca45fc83d260193208d44fd934cc7`.
- Bedrock committed archive: `12d15697b629235d7c4bfeaf4753ff2f899a1ed5`.

Both caller sources were obtained using `git -C <owning-repository> archive HEAD`
from the permitted Mojility projects and extracted into private `/tmp` directories.
No uncommitted caller files, customer repositories or records were read. Workshop
`Contract`, `Command`, `Runner`, `Source`, `LocalSmoke`, `LocalCommand`, `broker.py`
and its coverage, asset, test-build, qualification-runtime and audit helpers were
read before execution. Workshop file hashes and its exact release advisory
revision are retained in the report. No caller code is copied into application
modules. Publication outputs and the fixture compatibility hash are untouched.

## Rejection before correction

Executed through `foundry capture --`:

```sh
elixir -r /tmp/starter-workshop-trunk/lib/workshop_executive/source.ex -e 'result = WorkshopExecutive.Source.separation(File.cwd!()); IO.inspect(result); if result["status"] != "passed", do: System.halt(1)'
```

Before correction: exit 1, failed with
`files=["lib/business_web/live/catalogue/blueprints.html.heex"]`. The HEEx
sentence at line 58 ended in `Bedrock.`, matching the unchanged caller regex.
After rewording it to “no Bedrock runtime calls”: exit 0, `files=[]` and
`status=passed`. `.foundry/proof.json` contains the exact command and existing
external logs. Loading Source alone emitted undefined-module warnings for unused
write paths; those paths were not invoked. The landed preparation proof is preserved at `.foundry/preparation-proof.json`.
The subsequent regression executes
`Runner.check` and its real journal within the compiled Workshop.

## Execution

Commands (each outer invocation uses `foundry capture --`):

```sh
python3 scripts/qualify_workshop.py --workshop /tmp/starter-workshop-trunk --workshop-revision 9bfe35ffc6cca45fc83d260193208d44fd934cc7 --bedrock /tmp/starter-bedrock-trunk --bedrock-revision 12d15697b629235d7c4bfeaf4753ff2f899a1ed5
python3 scripts/verify_qualification_cleanup.py --bedrock /tmp/starter-bedrock-trunk --bedrock-revision 12d15697b629235d7c4bfeaf4753ff2f899a1ed5 --case success
```

Writable execution caches: `MIX_HOME=/tmp/starter-c3-tools/mix`,
`HEX_HOME=/tmp/starter-c3-tools/hex`. Elixir `1.20.2-otp-29`, OTP `29.0.2`,
`ERL_FLAGS=+S 4:4`. No toolchain pins changed. The first attempt using the default
Hex home rejected with `eaccess`; both synthetic databases and its source snapshot
were removed. A writable cache fixes that environmental restriction. The next setup attempt
rejected because the committed Workshop archive omits derived guidance inputs.
The corrected runner reads the canonical Bedrock archive and resolves the public
profile to a committed SHA, then uses Workshop producer validation, provenance
and checks to hydrate packaging inputs. These setup failures are harness
responsibilities; neither establishes a caller gate defect.

The report records every named gate with its executed broker argv and artifact
log. Broker environment construction is unchanged: format/compile/migration/boot/
smoke use prod; coverage/credo/dialyzer/security/docs/audits use test.
`CUSTOMER_EXPLORATION=false` for coverage and true otherwise; `PHX_SERVER=true`
only for boot. Forced compilation runs in the same Mix process before applicable
gates. The real coverage wrapper copies fixture assets into the test build and
uses the uniquely named test database. Protected audits use the release advisory
snapshot and no advisory suppressions.

Fresh synthetic `SECRET_KEY_BASE` is redacted. Mail is disabled outside coverage,
which retains the test Swoosh adapter. No provider credentials are passed.
Workstation socket role and unique database names are the only database remaps.
The protected candidate is never patched to accommodate a gate. Source and
`mix.lock` preservation are checked after all gates. LocalSmoke receives a
separate disposable copy with the socket role and database remapped in runtime
configuration; its actual port-0 server and smoke program remain caller-owned.

## Limits

The broker's actual argv/environment construction and command execution are
qualified off guest. This host cannot establish installed sudo/binding validation,
read-only source mounts, guest developer identity, systemd filesystem isolation,
private temporary directories, proxy/network isolation, cgroups, process/memory/
file limits or installed lifecycle lease enforcement. These are unverified guest
boundaries, not passing receipts. No Docker or production/provider calls are used.

HTTP/database smoke verifies deployed CSS (including digested URLs), CSRF denial
without a write, anonymous staff denial, enquiry field persistence, magic-link
session creation, and staff reads of both the new and pre-seeded retained enquiry
including contact, request, source, timestamps and follow-up. This demonstrates
capture and staff reading; Contacted does not prove a reply was sent or the
owner/customer Goal achieved. No mail delivery, live owner journey, assistive
technology conformance, deployment or current customer data compatibility is claimed.
The UI change is prose only; controls, keyboard behavior and theme styles are
unchanged. The existing accessibility contract remains applicable.

## Real coverage rejection and starter correction

The first fully packaged qualification ran all 14 gates. Thirteen passed; the
protected coverage wrapper exited 2 with 11 smoke regression failures despite
93.36% line coverage. The whole qualifier exited 1, as required. Exact command:

```sh
MIX_HOME=/tmp/starter-c3-tools/mix HEX_HOME=/tmp/starter-c3-tools/hex python3 scripts/qualify_workshop.py --workshop /tmp/starter-workshop-trunk --workshop-revision 9bfe35ffc6cca45fc83d260193208d44fd934cc7 --bedrock /tmp/starter-bedrock-trunk --bedrock-revision 12d15697b629235d7c4bfeaf4753ff2f899a1ed5
```

Run log: `/home/svetzal/.foundry/tool-logs/2-1790881972890438388.stdout.log`.
Protected coverage argv and output:
`/home/svetzal/.foundry/tool-logs/workshop-_b_iy82t/coverage.artifact.json`.
For example the CSRF regression expected `smoke_failed:csrf_denial` but received
`smoke_failed:stylesheet_delivery`. This is a starter test-fixture defect:
`test/business/smoke_contract_test.exs` wrote source `priv` while the actual
Workshop `test_build.exs` correctly isolates runtime fixtures in the test build.
The fixture keys now resolve through `Application.app_dir(:business, path)`,
matching the application's own scene and static-asset readers. Assertions,
coverage threshold and caller helpers are unchanged. Candidate source and
`mix.lock` stayed intact in that rejecting run; local boot and smoke passed.
No processes, databases or candidate snapshot remained after its nonzero exit.

The corrected qualifier additionally checks isolated-workshop `GET /users/log-in`
through the real browser pipeline, follows its redirect to staff enquiries,
checks the retained contact/request/follow-up in HTTP, and checks that an owner
session exists in the synthetic database. Cookies and session values are never
recorded. It then executes local `LocalCommand` boot and smoke independently.

## Completed run outcomes

Corrected Workshop invocation: exit 0. Full capture: `/home/svetzal/.foundry/tool-logs/2-1790882945019975639.stdout.log`. Candidate source identity: `cae572b346679e776b3484d08415c19605f60fd98ef5310328ebd7d451b84983`. The complete file manifest, exact executed argv and gate environment overlays are in `.foundry/workshop.json`.

| Owning gate | Outcome | Command exit |
| --- | --- | --- |
| format | passed | 0 |
| compile | passed | 0 |
| coverage | passed | 0 |
| credo | passed | 0 |
| dialyzer | passed | 0 |
| hex_audit | passed | 0 |
| dependency_audit | passed | 0 |
| security | passed | 0 |
| docs | passed | 0 |
| migration | passed | 0 |
| boot | passed | 0 |
| smoke | passed | 0 |
| source_separation | passed | in-process Runner check |
| test_integrity | passed | in-process Runner check |

Both source preservation and `mix.lock` preservation are true. The unchanged compatible scene fixture SHA-256 is `d218c9f590f28e6d986348f32567ed654b81fada3bdf2fc0370633f89e8aaeb2`. Protected coverage is 94.11%, with all 357 tests/doctests passing. The actual Runner boundary regressions also pass and explicitly assert failed source and test-removal outcomes before their corrections.

Independent local boot and smoke passed. Isolated-owner login returned a staff HTTP 200 with retained name, phone, email, request and follow-up visible; the database confirmed `owner:true` for the owner session. The probe verifies Secure, HttpOnly, SameSite=None and Partitioned attributes, then transports the cookie explicitly over loopback HTTP, as Business.Smoke does. This does not verify browser behavior at the guest HTTPS/iframe edge. The initial cookie-jar probe rejected with a redirect loop because it correctly withheld the Secure cookie on HTTP; no application cookie policy was changed.

Canonical packaging inputs: Bedrock `12d15697b629235d7c4bfeaf4753ff2f899a1ed5`, public Phoenix profile `ccd0b4b574dbe21f6152e8381541b491b7362453`, release advisories `5246bccd929b29309a014670b41ed2f2c6918c39`. Their producer hashes are recorded.

Cleanup on corrected success: no live groups, no matching database rows, no cleanup errors and the snapshot removed. The same checks passed after the coverage rejection. `.foundry/workshop-rejecting.json` preserves its gate-level failure evidence; `.foundry/proof.json` links the red and green invocations.

Bedrock full preparation, stable dependency-cache promotion, production compile and deployed-asset HTTP/database smoke passed in both unpublished and compatible synthetic published states. Success observer: `/home/svetzal/.foundry/tool-logs/2-1790882529384865827.stdout.log` (exit 0). The retained enquiry was seeded before startup and verified across both states. 1055 observations found no listener-after-lock-release violation. All owned children, database and snapshot were gone before the lock was released.

Actual failure probe command (also through Foundry capture):

```sh
python3 scripts/verify_qualification_cleanup.py --bedrock /tmp/starter-bedrock-trunk --bedrock-revision 12d15697b629235d7c4bfeaf4753ff2f899a1ed5 --case failure
```

Failure observer: `/home/svetzal/.foundry/tool-logs/2-1790882550458637127.stdout.log` (observer exit 0, qualifier exit 1). It emptied real delivered CSS in the disposable running app; smoke rejected `stylesheet_delivery`. 532 observations found no lock-order violation. No owned listener, child, database or snapshot remained. Existing signal-cleanup evidence is retained with the landed preparation proof; signals were not rerun in this increment.

Local PostgreSQL is 16.15; the project pin remains 18. This establishes the workstation rehearsal, not PostgreSQL 18 hosting acceptance. No Elixir/OTP pin, dependency lock, publication output, scene compatibility hash or sibling source changed.

Repository quality: all eleven required commands and `mix precommit` exit 0 in `.foundry/quality-c3.json`. Coverage is 94.11%; strict Credo, Dialyzer, Hex audit, dependency audit, Sobelow and docs are clean. `hex.outdated --all` exits 1 for available updates (including Sobelow 0.16.0), a visibility result rather than a security finding or acceptance blocker. No advisories were ignored. No LiveView `send_after` occurrence was found.

Browser check: `foundry capture -- python3 /tmp/starter-c3-browser.py`, exit 0;
`/home/svetzal/.foundry/tool-logs/2-1790883526736938383.stdout.log`. Chromium
rendered the actual catalogue blueprints in light and dark modes at 375×812;
all footnotes displayed the correction. Keyboard Tab exposed visible native
focus, keyboard Enter changed the catalogue theme, and neither mode overflowed
horizontally. `.foundry/browser-c3.json` records the observations. The executed
driver and Playwright script are retained in the external tool-log directory.
The first browser setup attempt used an unmigrated synthetic database and
rejected; the corrected setup migrates the unique database and disables mail
and notifications. Both attempts stopped their server groups and dropped their
databases. These limited browser checks do not establish WCAG conformance;
assistive-technology verification remains outstanding.

After the final documentation sync, standalone `MIX_ENV=test mix test` and
`MIX_ENV=test mix precommit` both passed; `.foundry/final-c3.json` records exact
argv and capture paths. Outer capture:
`/home/svetzal/.foundry/tool-logs/2-1790883830299456520.stdout.log`.
The source-separation red/green proof and landed preparation proof are also
preserved separately under `.foundry/`. Git finalization is left to Foundry.

Before removal, every executed Workshop source file and both invoked Bedrock
preparation modules were byte-compared with their declared committed archives.
They matched. Both caller archive directories were then removed;
`.foundry/caller-archive-cleanup.json` records this final cleanup. The final docs
check after the run-record update exited 0.
