# Quality checks

Run `mix deps.get` to install development tools.
Run `mix precommit` before committing changes.
Use the exact Elixir and OTP versions in `.github/workflows/build.yml`.

The checks stop on the first failure:

- Formatting must match `mix format --check-formatted`.
- Test compilation treats warnings as errors.
- The lockfile must contain no unused dependencies.
- Tests must pass with at least 90% line coverage.
- Credo runs in strict mode.
- Dialyzer checks types and caches PLTs in `priv/plts/`.
- MixAudit checks known dependency vulnerabilities.
- Hex checks retired packages.
- Sobelow checks Phoenix security, including low-confidence findings.
- ExDoc builds this guide and API documentation with warnings as errors.

Run each reported command separately to investigate failures.
Run `mix quality.security` to repeat the security checks.
Run `mix hex.outdated --all` to inspect available dependency upgrades.
Upgrade visibility is advisory in CI; it does not approve an upgrade.

The first Dialyzer run builds a cache and takes longer.
CI caches PLTs separately for each exact Elixir and OTP version.
Development tools are excluded from production dependencies.
Use Mox for gateway behaviours when a test needs an external boundary mock.

Review `send_after` calls in LiveViews before completing changes.
A repeating timer must not re-read data; subscribe to change events instead.
One-shot expiry and debounce timers are permitted.
Review changed interfaces in both light and dark modes.

Do not suppress findings or lower the coverage threshold to pass a check.
Resolve findings before treating the application as ready for release.
