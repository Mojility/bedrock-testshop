# Caller reconciliation — 2026-10-01

The field-service owner benefits from opening a workshop promptly and customers
reaching the business from its website. This increment verifies preparation,
enquiry capture and staff reading. Contacted does not establish a sent reply or
the customer's completed service goal. No deployment or owner acceptance is claimed.

Source is the preserved c1 candidate `6170f522e52879016fdcfac7d48feef74f4ae049`
plus this correction, without commits or ref changes. Bedrock is a fresh, clean snapshot of committed local `main`; the
GitHub HTTPS fetch required credentials and was not used. No sibling working
files, customer systems/data, cloud services or Docker were used. Exact source
identities and external capture receipts are recorded below.
One earlier application run passed both states, but its observer failed because
it scanned concurrent snapshots and removed another run's temporary directory.
Those runs are not accepted proof. Final runs use private snapshot parents and
execute sequentially. The failed observer logs remain external:
`2-1790872917196635925.stdout.log`, `2-1790873471507017800.stdout.log`,
and `2-1790874046721778468.stdout.log`.

The qualifier uses `/tmp/bedrock-port-4000.lock`, stops complete owned process
groups before releasing it, and protects teardown from interrupts. It removes
the unique disposable database and source snapshot on normal completion, actual
smoke-command failure, SIGINT and SIGTERM. The lock file remains for future users.
The observer allocates a unique private snapshot parent under `/tmp` and
passes it to the qualifier; discovery and rescue cleanup never scan other runs.
Run the observer separately for each case:

```sh
foundry capture -- python3 scripts/verify_qualification_cleanup.py \
  --bedrock /path/to/clean/bedrock-trunk --case sigterm
# Repeat with --case sigint, failure, success.
```

Signal cases pause the real BEAM listener before interruption, forcing ten-second
termination escalation. The observer checks shared-lock ownership while the
listener persists, then independently checks live children, listener binding,
SQL database existence and snapshot removal before any rescue cleanup. Failure
removes real disposable deployed CSS; it does not replace a command receipt.
Success executes full Bootstrap/Preparation commands and both publication states
from fresh archive-plus-candidate source snapshots, with deployed assets,
`MIX_ENV=prod`, port 4000 and `scripts/smoke.exs`.

HTTP negatives remove the complete enquiry form, authenticated enquiry list, or
retained enquiry content. IDs remain; the form placeholder also retains CSRF so
a synthetic direct POST cannot conceal the loss of visitor controls. Smoke now
requires a POST form with enabled enquiry fields and a submit control. Tests
assert missing usable HTTP content, intact retained SQL fields, and a restored
endpoint passing smoke. Existing stylesheet, submitted-field, retained-field,
authentication and CSRF checks remain.

Raw logs stay in Foundry's default `~/.foundry/tool-logs/`. `.foundry/proof.json`
contains the rejecting and corrected behavioral receipts; `.foundry/gates.json`
contains final quality receipts. The original c1 record remains historical and
its marker/cleanup claims are explicitly superseded.

Limitations: this is local execution on the Canadian workstation, PostgreSQL 16
rather than CI's pinned 18. Toolchain pins, published compatibility hashes,
publication provenance and customer runtime obligations are unchanged. It does
not prove live mail, Workshop-wide integration, Roost release, CI smoke,
PostgreSQL policy, hosted isolation, production migration readiness or deployment.
UI source is unchanged; browser keyboard/light/dark and assistive-technology
acceptance have not been newly verified by this increment.

## Sources and outcomes

Final Bedrock snapshot: `12d15697b629235d7c4bfeaf4753ff2f899a1ed5` (current
committed main at acquisition). The first successful run used
`aaec254d96299f17c4a846a2dc04e5d1f068d15b`; both producer modules and all emitted
commands are byte-identical. `.foundry/command-equivalence.json` and
`2-1790879254507311749.stdout.log` record the real producer comparison.
Its clean `main` matches its trunk reference. The qualifier called these actual
modules; source acquisition alone is represented by archive-plus-overlay, with
sandbox paths, lockfile comparison and the synthetic database role remapped.
Elixir `1.20.2-otp-29`, OTP `29.0.2`, local PostgreSQL `16.15` are unchanged.
Both preparation snapshots reported identical candidate content SHA-256
`a6631ab829282e5624d1b3ca3e7eb419a5aee32230bec61b14012bcf22861bc6`.
Evidence and inventory prose were finalized afterward; executable source
remained unchanged.

| Source | SHA-256 |
| --- | --- |
| Bedrock `bootstrap.ex` | `24be9947207a50d9f108c68960351a715cc49fb6cbfeeffaee099f309306ae84` |
| Bedrock `preparation.ex` | `635f421f32ba3dc5fb1bd523329c4d072110666960cd2eef80011a9251f380f9` |
| `lib/business/smoke.ex` | `7ccbe5e6381144d569acc19ceb21dacf2dc46612e254e37d0e58bd8b13c88527` |
| `scripts/qualify_callers.py` | `01c6abe76881b82e7fbf965e67f3aaccc0f30877f6dd29faacadb2152364eb9a` |
| `scripts/verify_qualification_cleanup.py` | `bc96b0ea1ad465362e0d73866b70f941e64cc5797dce2a9d2a30298f81fe55cf` |
| `scripts/qualification_seed.exs` | `7e8e78379eef629571d9abc1d2b48d224e210050abd09d902758d890ce848904` |
| `test/business/smoke_contract_test.exs` | `c1a77633e8bde1842502bbfa464fc51208c0cff691c1ec2882b25c8e053d1fde` |
| `test/support/smoke_fault.ex` | `27e829d829086e20fcf93e2c53180e9e312f7ad4eadc11434c854a0d49dcdcd3` |
| `test/fixtures/website_scene.json` | `d218c9f590f28e6d986348f32567ed654b81fada3bdf2fc0370633f89e8aaeb2` |

Fixture compatibility hash remains
`704b1cb9a5421ef6593108152d8065afec9b070dd59a0d5fe085b0f92a99dbee`;
it was not replaced. Root publication outputs were not repaired or authored.

All log names below are under `/home/svetzal/.foundry/tool-logs/`.
The cleanup command is the observer command above with the indicated case;
observer exit **0** means the independently measured cleanup assertions passed.

| Boundary | Qualifier exit | Observer exit | Log |
| --- | ---: | ---: | --- |
| `sigterm` | 143 | 0 | `5-1790874470709578392.stdout.log` |
| `sigint` | 130 | 0 | `766-1790874601770961000.stdout.log` |
| `failure` | 1 | 0 | `1523-1790874735386445075.stdout.log` |
| `success` | 0 | 0 | `2-1790879622021481626.stdout.log` |

Every case left no live owned children, listener, database, snapshot or observer
parent. Lock probes found no release while a listener remained. SIGTERM/SIGINT
paused the real listener and forced escalation; failure genuinely returned
`stylesheet_delivery`. The successful run verified HTTP and SQL in both states,
including the pre-start enquiry's contact, request, source, legacy ID, insertion
and follow-up timestamps, Contacted status and notes. Its unpublished stylesheet
was `/assets/css/app-3aecb787d45ad122b1f4204162da52d0.css?vsn=d`; publication
used the synthetic site stylesheet plus digested staff assets.

The original qualifier's SIGTERM probe left its listener, database and snapshot
and did not own the canonical lock: observer exit **1**,
`2-1790871554930672913.stdout.log`. The form regression then proved that the old
ID-only check accepted a missing form despite successful direct HTTP/SQL writes:
`mix test test/business/smoke_contract_test.exs --trace`, exit **2**,
`5-1790872771244302743.stdout.log`. After correction, actual form/list/retained
content removals rejected through HTTP, retained SQL fields stayed intact, and
restoring the endpoint passed: `mix test test/business/smoke_contract_test.exs
test/business/exploration_test.exs --trace`, exit **0**,
`55-1790872894103824568.stdout.log`.

All required quality commands and `mix precommit` returned **0**: 345 tests,
12 doctests, **94.11%** coverage against the unchanged **90%** threshold; strict
Credo had no findings, Dialyzer had zero errors, docs and security audits passed.
`mix hex.outdated --all` returned **1** only for upgrade visibility; no advisory
was suppressed and no dependency/pin changed. Final receipts are in
`.foundry/gates.json`. `rg send_after lib/business_web/live` found no matches.
The isolated `business_test_caller_c2_5a77a2` quality database was dropped;
`2-1790874737280195766.stdout.log` records successful cleanup. Remaining local
artifacts are public source/tool caches, quality artifacts and external logs.
Foundry owns finalization; the correction remains uncommitted in this worktree.

An independent later probe found the shared lock busy again. The completed
run's observer recorded release and a free port after termination; no other
caller's processes or lock ownership were disturbed.

The first latest-main rerun completed preparation, migration and seeding but
waited behind another holder of the mandatory shared lock. Its observer timed
out before listener startup (exit **1**, `2-1790876540191403410.stdout.log`),
then removed its isolated resources. This is an environmental queue failure,
not accepted runtime proof. The final latest-main rerun above passed both
publication states and independently verified cleanup.
