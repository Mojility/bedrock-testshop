# TestShop

The business system for TestShop: a Phoenix application in its own
repository, with its own database, deployable on its own.

This repository was generated and is maintained by
[Bedrock](https://mybedrock.ca), a product of Mojility Inc. Bedrock's
generators belong to Mojility; everything they produced here belongs to
TestShop (see `LICENSE`). Nothing in this repository depends on
Bedrock at build time or at run time. A competent Elixir shop can pick it
up cold, and this README is written for one.

`SYSTEM.md` says what the system contains and where its data lives. It is
kept current by the same generators that change the code.

For product, architecture, independent operation, and evidence gaps, read the
[documentation index](docs/README.md).

## What you need

- Elixir 1.20 on Erlang/OTP 29 (`.github/workflows/build.yml` pins the
  versions CI uses)
- PostgreSQL 14 or later, reachable as `postgres`/`postgres` on
  `localhost` for development and test (change `config/dev.exs` and
  `config/test.exs` if yours differs)
- Docker, to build the production image

## Run it locally

The quickest way, with Docker and no Elixir installed:

```sh
docker compose up --build   # http://localhost:4000 (APP_PORT=4001 to change)
docker compose logs -f app  # sign-in links are printed here
```

With Elixir installed, for development:

```sh
mix setup          # deps, database, assets
mix phx.server     # http://localhost:4000
```

The dev and test config expect a Postgres role `postgres` with password
`postgres` on localhost, or whatever `PGUSER`, `PGPASSWORD`, and `PGHOST`
say. Postgres from Homebrew on macOS has no `postgres` role; run
`createuser -s postgres` once, or `export PGUSER=$USER PGPASSWORD=`.

Sign-in is passwordless and staff access is invitation-only. For local
setup, call `Shop.Accounts.Staff.bootstrap_owner("owner@example.com")` in
`iex -S mix`. Request a login link at `/users/log-in`. Development email
lands in `/dev/mailbox`. See `BUSINESS.md` for deployment and lead transfer.

## Run the tests

```sh
mix test
```

Run `mix precommit` before every commit. It checks formatting, compilation,
coverage, Credo, types, security, and documentation. CI runs the same checks
as separate steps so each result remains visible. See [quality
checks](guides/quality.md).

## Build the image

```sh
docker build -t shop .
```

The image runs pending migrations and then starts the server
(`rel/overlays/bin/entrypoint.sh`). A migration that fails stops the
container, so a broken schema is never served.

## Environment variables

The release reads these at start (`config/runtime.exs`):

| Variable                 | Required           | Meaning                                                                             |
| ------------------------ | ------------------ | ----------------------------------------------------------------------------------- |
| `DATABASE_URL`           | yes                | `ecto://user:password@host:5432/database`. The connection uses TLS.                 |
| `DATABASE_SSL`           | no                 | `false` disables TLS for local Postgres; hosted databases keep the default.         |
| `SECRET_KEY_BASE`        | yes                | Signs cookies and tokens. Generate one with `mix phx.gen.secret`.                   |
| `PHX_HOST`               | yes                | The hostname the system is served at, for links in pages and email.                 |
| `PORT`                   | no                 | HTTP port the server listens on. Default `4000`.                                    |
| `MAIL_FROM`              | no                 | Sender address for email, optionally `Name <address>`. Default `noreply@$PHX_HOST`. |
| `AWS_REGION`             | no                 | Region for Amazon SES. Default `ca-central-1`.                                      |
| `SHOP_NAME`              | no                 | Overrides the shop's name from `config/config.exs`.                                 |
| `MEDIA_BUCKET`           | for photos         | This customer's private Canadian S3 bucket.                                         |
| `AWS_CREDENTIALS_FILE`   | hosted             | Read-only, atomically renewed customer AWS credentials.                             |
| `TRUSTED_PROXY_IPS`      | behind a proxy     | Comma-separated trusted proxy peer addresses.                                       |
| `WEBSITE_PREVIEW_SECRET` | for remote preview | Separate machine credential, at least 32 bytes.                                     |
| `LEAD_NOTIFICATIONS`     | no                 | Set `false` for isolated rehearsals.                                                |
| `POOL_SIZE`              | no                 | Database connection pool size. Default `10`.                                        |

Hosted media and mail read renewable customer-scoped credentials from
`AWS_CREDENTIALS_FILE`. The host renews that read-only file. Standalone mail can
use the application's instance role; hosted containers receive no host metadata
or fleet permissions. Runtime configuration refuses any AWS region other than
ca-central-1. SES sandbox restrictions must be resolved in Canada.

## Deploy it on your own

`infra/standalone.yaml` is a CloudFormation template that stands the whole
system up in a fresh AWS account in ca-central-1: network, database,
container registry, one instance running the image behind Caddy with a
Let's Encrypt certificate, and an optional DNS record. `infra/README.md`
walks through it and explains how this standalone rendering relates to the
hosted one Bedrock runs. The code is identical in both.

## Continuous integration

`.github/workflows/build.yml` runs the quality checks against a PostgreSQL
service on every push to `main`, builds an ARM64 Docker image, and pushes its
immutable commit tag to
an Amazon ECR repository. Pushing needs two repository variables:

- `AWS_ROLE_ARN`: an IAM role GitHub assumes through OIDC (no long-lived
  keys). The standalone template can create it.
- `ECR_REPOSITORY`: the name of the ECR repository to push to.

Without `AWS_ROLE_ARN`, the workflow still checks and builds; it skips the
push and says so in the run summary.

## Layout

```text
lib/shop/          business logic (contexts, schemas), no web dependencies
lib/shop_web/      the web layer: router, LiveViews, controllers, components
config/            compile-time and runtime configuration
priv/repo/         migrations and seeds
test/              the test suite; CI refuses a change that breaks it
rel/               release overlays, including the container entrypoint
infra/             the standalone CloudFormation template
```
