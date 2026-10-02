# Public customer CI correction — 2026-10-02

Actor: business owner. Goal: publish a working customer system. Interaction:
generate/reset a public repository and obtain a CI-built release.

Source baseline and remote main: `8bc52f349496124d3230d59603bab9a0dc89cf4a`,
verified by `git rev-parse HEAD` and `git ls-remote origin refs/heads/main`.
Foundry forbids ref mutations; no fetch updating refs, rebase, commit, push or PR.
Shared producer fixture: Bedrock `78767528c45c0d9412c4cbc90d395c724ed1c5ee`,
SHA-256 `da1dac5fe25a61dbd0096f988269c58ab36d71458f7afb02f16258e34d8b4a06`.
No sibling working tree or customer source/records were used as evidence.

The private reusable call was replaced with ordinary starter-only jobs, preserving
all nonpublishing producer validation and invoking shared scripts on resolved
runtime checkouts. Removed steps were already inactive (`publish-image=false`);
no active platform acceptance was removed. Integration OTP now uses the existing
project pin `29.0.2`; project Elixir/OTP versions are unchanged. Local build reuse
runs unchanged quality/release checks again after integration, before an image.
Bedrock must remove `.bedrock/starter-only.json`'s listed paths during generation
and reset. Until then a customer copy loads and skips the platform jobs safely.
Starter-specific maintenance checks skip when their removed source is absent;
customer workflow scanning, standalone publication and quality parity still run.

All verbose commands use `foundry capture --` and keep full output outside Git.
Rejecting: `env MIX_ENV=test ERL_FLAGS='+S 4:4'
MIX_TEST_PARTITION=_workflow_85e3db7f mix test test/maintenance/build_workflow_test.exs`
with only the new private-reference regression added to the baseline exited 2:
6/7 tests passed, and the new test identified the private Bedrock `uses:`.
Initial compilation printed existing dependency warnings; no dependencies changed.
See `.foundry/proof.json` for exact rejecting/corrected log paths.

Final verification:

- Focused workflow regression: 7 passed; corrected exit 0. The unchanged customer
  quality/release fixture and producer validation parity both passed.
- Synthetic generated copy with all manifest-listed paths removed: 3 applicable
  tests passed, 4 starter-specific tests skipped; exit 0. Load-safety and standalone
  customer publication assertions remain active.
- `MIX_ENV=test mix deps.get`, `mix format --check-formatted`,
  `mix compile --warnings-as-errors`, `mix deps.unlock --check-unused`,
  `mix test --cover`, `mix credo --strict`, `mix dialyzer`,
  `mix docs --warnings-as-errors`, `mix hex.audit`, `mix deps.audit`,
  `mix sobelow --config` and `mix precommit` all passed on the final implementation.
  Precommit: 365 passed (12 doctests, 353 tests), 94.12% coverage against 90%,
  no Credo issues, no Dialyzer errors. Audits reported no vulnerable/retired packages.
- The initial strict Credo run found one nesting issue in the new test helper;
  the helper was refactored and the standalone retry and final precommit passed.
  The original failure and retry remain recorded in `.foundry/public-ci-quality.json`.
- `mix hex.outdated --all` exited 1 for the optional Finch 0.23.0 → 0.24.0
  upgrade visibility check. No security audit finding accompanied it; dependency
  changes are outside this workflow correction's scope.
- No `send_after` matches in `lib/business_web/live`; no UI changes require browser
  or theme verification for this increment. `git diff --check` passed.

Cleanup: all three unique proof databases were dropped, and the synthetic
customer snapshot was removed. No listener was started by this task, and every
command it started has finished. Toolchain caches remain ignored under
`priv/plts/`, `_build/` and `deps/`. Raw logs remain in Foundry's external log
directory; sanitized command/result metadata is in `.foundry/public-ci-*.json`.
No customer data, publication outputs, compatibility hashes, dependency locks,
credentials or Git refs changed. Changes are left in the working tree for Foundry.

Local workflow contracts do not prove a hosted public GitHub run, actual shared
platform integration, owner acceptance or deployment. No production services,
cloud credentials, customer data, mail or listeners were used. Actionlint is not
installed; no dependency was added to obtain it. No UI behaviour changed.
