# Routine maintenance

Bedrock keeps this system on current releases of Elixir, Erlang/OTP,
PostgreSQL, Phoenix, and the other dependencies. It does this by dispatching
the `Maintenance` workflow (`.github/workflows/maintenance.yml`) with a
*baseline*: the versions the stock system template currently uses.

## What maintenance may change

A maintenance run changes only toolchain and dependency declarations:

| File | What changes |
| --- | --- |
| `.tool-versions` | The `elixir`, `erlang` and `postgres` lines. Other lines stay. |
| `Dockerfile` | The `ELIXIR_VERSION`, `OTP_VERSION` and `DEBIAN_VERSION` defaults. |
| `mix.exs` | Requirement strings of dependencies this system already declares. |
| `mix.lock` | The result of `mix deps.update --all`. |
| `config/config.exs` | The `version:` of the `tailwind` and `esbuild` asset tools. |
| Vendored assets | Files such as `assets/vendor/daisyui.js`, if they already exist here. |

In `mix.exs`, a dependency the baseline names takes the baseline requirement.
Any other patch-level requirement, such as `~> 1.2.3`, is loosened to `~> 1.2`.
Only the requirement string changes. Dependency options (`only:`, `runtime:`,
`override:`), comments and layout stay as they are. A vendored file is replaced
only with the official release download whose SHA-256 digest the baseline
states. A download with a different digest is refused, and nothing is written.

## What maintenance never touches

Maintenance never adds or removes a dependency and never copies code from the
template. It does not change the shop's code, tests, migrations, scene,
components, assets, documents, or GitHub workflows. It reads no business
records. The publish job checks the patch and refuses any change outside the
files in the table above.

## How a run works

1. Validate the maintenance id and the baseline. An invalid baseline ends the
   run with status `invalid`.
2. Apply the baseline with `scripts/maintenance/apply_baseline.exs`. The script
   uses only the Elixir standard library, so it runs before dependencies exist.
3. Update dependencies, reinstall the asset tools, and build the assets.
   Build outputs are gitignored and are never committed.
4. Run every gate of the `quality` alias (the same checks as `mix precommit`)
   against PostgreSQL at the major version in `.tool-versions`.
5. If nothing changed, the status is `current`. If a step failed, the status is
   `failed` and names that step. Otherwise the publish job commits the change
   to a `maintenance/<id>` branch, and the status is `changed`.

Every run uploads a `maintenance-result` artifact with the status and the
versions before and after. It also lists updates that are still blocked by a
requirement the baseline does not cover, such as a new major version.

The run never builds an image, never deploys, and never changes `main`.
Bedrock moves `main` to the maintenance commit only if `main` has not moved.
The normal build then runs, and Bedrock verifies and releases that commit.
Updated dependencies are compiled and tested in a job with read-only access to
this repository. Only the publish job can push, and it runs no project code.

## Keeping the toolchain in one place

`.tool-versions` states the toolchain. CI reads Elixir and Erlang/OTP from it,
and it runs PostgreSQL at the major it names. No workflow file contains a
version. The Dockerfile's build-argument defaults must match. A test
(`test/maintenance/toolchain_consistency_test.exs`) fails when they differ.
To check by hand, run:

```sh
elixir scripts/maintenance/apply_baseline.exs check-toolchain
```

To see what a baseline would change, apply it to a scratch copy:

```sh
elixir scripts/maintenance/apply_baseline.exs apply --baseline baseline.json --root ../copy
```
