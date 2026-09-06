# Quality checks

Run `mix deps.get` to install development tools.
Run `mix precommit` before committing changes.
Use the exact Elixir and OTP versions in `.github/workflows/build.yml`.

Security checks run before compilation so Hex tasks remain available.
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

## Reviewed security boundaries

Sobelow scans all source files. Function-level comments identify these reviewed
boundaries; the scanner honours those comments with `skip: true`.

- The website reader uses fixed application paths.
- The credential reader uses an operator-configured path and rejects invalid or
  expired credentials. No browser request selects that path.
- The legacy import reads a file selected through trusted release access.
- Page and enquiry responses come from the validated HEEx renderer. Tests check
  escaping and rejection of incompatible scenes.
- Media responses allow raster image MIME types only and set `nosniff`. Tests
  reject traversal keys, executable MIME types, and invalid preview signatures.

Browser responses forbid inline scripts and external executable resources.
Theme preferences run in the compiled JavaScript bundle. Inline styles remain
allowed for generated theme tokens and LiveView styling. Production redirects
HTTP browser requests to HTTPS behind the trusted TLS edge. Private localhost
readiness checks remain available without a redirect.

## Ongoing enforcement

CI runs the required quality checks on pushes to main, pull requests, and each
Monday. Scheduled checks can detect newly disclosed dependency vulnerabilities
without a source change. Dependency update reports are informational; vulnerability
and security checks are required. A failed quality job blocks image publication.
Pull requests and scheduled runs cannot publish images or deploy.

Run `mix precommit` before committing. A passing check applies to the tested
revision; it does not prove untested behavior, replace code review, or make future
changes safe automatically. Keep the 90% coverage minimum and strict checks when
changing tooling. Review any new security exception in context and add regression
tests for its safety boundary. GitHub required checks must be configured separately
to prevent unchecked merges; local aliases and workflow files cannot enforce that
repository setting. CI changes take effect only after they are pushed.
