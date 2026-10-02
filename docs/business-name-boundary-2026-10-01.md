# Business name boundary — 2026-10-01

Evidence ran on 2026-10-02 UTC (the Canadian workstation evening of
2026-10-01); this record uses the campaign date.

This Canadian-workstation rehearsal uses only stock committed source and
synthetic local systems. Starter baseline:
`f624a5ba331ce0e2354274e39f12fe52b7bf7c9c`. Bedrock archive:
`78767528c45c0d9412c4cbc90d395c724ed1c5ee`. Toolchain remains Elixir
`1.20.2-otp-29`, OTP `29.0.2`; CI still reads exact `.tool-versions` pins.
No production, customer checkout, cloud credential or external mail was used.

## First behavioral proof

Before expanding fixtures or running the full suite:

- `foundry capture -- env HEX_HOME=/tmp/starter-c9-tools/hex python3 scripts/qualify_business_name.py --reject-substitution`
  exited 1: quotes broke the generated Elixir config before formatting.
  Log: `/home/svetzal/.foundry/tool-logs/2-1790900066034524005.stdout.log`;
  diagnostic: `/home/svetzal/.foundry/tool-logs/2-1790900066034524005.stderr.log`.
- `foundry capture -- env HEX_HOME=/tmp/starter-c9-tools/hex python3 scripts/qualify_business_name.py --characterize --source-revision f624a5ba331ce0e2354274e39f12fe52b7bf7c9c --port 0`
  exited 0: real startup/HTTP legacy configuration, each override, both overrides
  and explicitly empty `BUSINESS_NAME`. Baseline titles remained baked.
  Log: `/home/svetzal/.foundry/tool-logs/2-1790900319414319093.stdout.log`.
- `foundry capture -- env HEX_HOME=/tmp/starter-c9-tools/hex python3 scripts/qualify_business_name.py --port 0`
  exited 0: the same hostile name, JSON encoded, preserved in `Business.name()`,
  actual HTTP title/header/home and mail sender. Legacy cases also passed.
  Log: `/home/svetzal/.foundry/tool-logs/2-1790900320593709273.stdout.log`.

`.foundry/proof.json` retains the rejecting/corrected behavioral commands and
existing logs. Reproduce the old producer with `--reject-substitution
--source-revision f624a5ba331ce0e2354274e39f12fe52b7bf7c9c` after this change.
The proof creates unique synthetic databases, source snapshots and loopback HTTP
listeners; successful probes remove their database and snapshot after stopping
all listener process-group members. Two redundant port-4000 queued probes were
interrupted before listeners started; explicit removal of their databases and
snapshots is recorded in `.foundry/name-interrupted-cleanup.json`.

The first dependency fetch rejected because the sandbox cannot write the user's
Hex cache. A copy at `/tmp/starter-c9-tools/hex` resolved this without dependency,
policy or toolchain changes. Build logs remain in Foundry's external log directory.

## Contract and limits

The authored input is optional `priv/business.json`, string key `name`.
Resolution preserves `BUSINESS_NAME` > `SHOP_NAME` > JSON > baked configuration,
including existing empty-string overrides. Only missing data falls back; invalid
data fails startup without an override. Restart loads changes. The stock fallback
is `Business`; the file ships as release data, separate from publication output.
All naming consumers obtain the resolved name through `Business.name()`.

The extended name matrix and quality commands are recorded under `.foundry/`.
Current-caller qualification uses the committed Bedrock preparation commands,
`MIX_ENV=prod`, deployed assets, port 4000 and `scripts/smoke.exs`, with the shared
port lock held through listener shutdown. It checks both publication states and
retained synthetic enquiry fields. Fixture hashes are not repaired or replaced.

HTTP text preservation does not establish accessibility conformance. Browser
keyboard, focus and both-theme verification is separate; assistive-technology
verification remains outstanding. Disabled/test mail does not prove delivery.
Contacted follow-up does not prove that a reply was sent or the customer goal
was achieved. Nothing here claims acceptance, deployment or repaired current
Bedrock generation; its remaining producer change is in
[owner journey findings](owner-journey-findings.md).

## Completed verification

Final candidate materialization:
`46e76e59298d22b5778f5e330c48ce989c6b2ced96ef59aca238b39ef19cff84`.
The name matrix and current-caller qualification used this identical source.
Individual behavioral-source digests and the unchanged fixture/model identity
are in `.foundry/name-source-identities.json`. These evidence-only documentation
additions follow that materialization; application and probe source is unchanged.

- Final name matrix: `foundry capture -- env HEX_HOME=/tmp/starter-c9-tools/hex python3 scripts/qualify_business_name.py --port 0`, exit 0.
  Log: `/home/svetzal/.foundry/tool-logs/2-1790900998153025469.stdout.log`.
  JSON inputs were present during each format/compile check, then real startup,
  HTTP DOM text and magic-link email subject/body were checked. The matrix covers
  legacy/no-file, each override, both overrides, empty overrides, quotes,
  backslashes, literal interpolation, HTML characters, Unicode and 63/120 characters.
- Invalid-data startup: `foundry capture -- python3 .foundry/name-config-rejection.py`, exit 0.
  Log: `/home/svetzal/.foundry/tool-logs/2-1790902062701229887.stdout.log`.
  Expected runtime rejections for malformed JSON, missing key and non-string name
  each exited 1 with the expected diagnostic. All override cases exited 0.
  The disposable snapshot was removed; no database or listener was started.
- Browser: `foundry capture -- python3 .foundry/name-browser-run.py`, exit 0.
  Log: `/home/svetzal/.foundry/tool-logs/2-1790900996979254596.stdout.log`.
  A 120-character unbroken ASCII name first failed mobile reflow; wrapping in the
  existing header/home name consumers corrected it. Chromium verified exact
  title/text, visible keyboard focus, both themes at 375px, contact error focus
  and association, input retention, correction, saved enquiry records and no
  horizontal overflow. Source and rejection/pass records are retained under
  `.foundry/name-browser*`; the owned database was dropped. Browser tools were
  preinstalled locally; no frontend dependency was added.
- Quality: `foundry capture -- python3 .foundry/name-quality.py`, exit 0.
  Log: `/home/svetzal/.foundry/tool-logs/2-1790901074075808085.stdout.log`.
  All eleven required individual gates and `mix precommit` passed. The suite
  passed 352 tests and 12 doctests, coverage **94.12%** against **90%**. Credo found
  no issues; Dialyzer, docs, retired-package/dependency audits and Sobelow passed.
  Optional `mix hex.outdated --all` exited 1 for available upgrades, with no audit
  finding; this visibility check is not a required gate. The first new DOM
  assertion required trimming HEEx indentation; the initial failed record is
  retained in `.foundry/name-quality-initial.json`. The unique quality database
  was removed. No advisory suppression, dependency, gate or toolchain change was made.
- Current caller: `foundry capture -- python3 scripts/qualify_callers.py --bedrock /tmp/name-bedrock-trunk --bedrock-revision 78767528c45c0d9412c4cbc90d395c724ed1c5ee --snapshot-parent /tmp`, exit 0.
  Log: `/home/svetzal/.foundry/tool-logs/2-1790901202146219571.stdout.log`.
  Cold/cached preparation and both unpublished/published states passed with
  deployed assets, `MIX_ENV=prod`, port 4000 and the real `scripts/smoke.exs`.
  Assertions verified nonempty digested CSS, CSRF refusal without a write,
  anonymous staff denial, exact new enquiry persistence, real magic-link session
  creation and authenticated reads of new/retained records. Retained contact,
  request, source, legacy identity, insertion/seen timestamps and follow-up
  remained equal in SQL before/after smoke in both states. Staff HTTP renders
  contact/request, submission time and follow-up; source/history integrity was
  checked in SQL, not claimed as separately rendered UI fields.
  The shared port lock remained held through all listener-process shutdown.
  `qualification_95b8f6d947dfa9c60490` and `/tmp/qualification-smsdzshr` were removed.
  An earlier run correctly rejected source changes made during preparation and
  removed its snapshot; `.foundry/name-caller-initial.json` retains that result.

Local PostgreSQL was **16.15**, while `.tool-versions` retains PostgreSQL **18**
for CI. This run does not establish PostgreSQL-18, hosted HTTPS, live mail or
assistive-technology verification. The Bedrock archive and owned temporary probe
file were removed after verification; the temporary Hex cache is tooling only.
Application-backed business state and publication source remain untouched.

Final documentation/format checks and the closing `mix precommit` run are
recorded in `.foundry/name-final-checks.json`; application/probe digests remain
equal to the qualified materialization.
