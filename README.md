# {{SHOP_NAME}}

The business system for {{SHOP_NAME}}: a Phoenix application in its own
repository, with its own database, deployable on its own.

This repository was generated and is maintained by
[Bedrock](https://mybedrock.ca), a product of Mojility Inc. Bedrock's
generators belong to Mojility; everything they produced here belongs to
{{SHOP_NAME}} (see `LICENSE`). Nothing in this repository depends on
Bedrock at build time or at run time. A competent Elixir shop can pick it
up cold, and this README is written for one.

`SYSTEM.md` says what the system contains and where its data lives. It is
kept current by the same generators that change the code.

## What you need

- Elixir 1.20 on Erlang/OTP 29 (`.github/workflows/build.yml` pins the
  versions CI uses)
- PostgreSQL 14 or later, reachable as `postgres`/`postgres` on
  `localhost` for development and test (change `config/dev.exs` and
  `config/test.exs` if yours differs)
- Docker, to build the production image

## Run it locally

```sh
mix setup          # deps, database, assets
mix phx.server     # http://localhost:4000
```

Sign-in is passwordless. Register with an email address at
`/users/register`, then open the link the system sends. In development
the email lands in the local mailbox at `/dev/mailbox`.

## Run the tests

```sh
mix test
```

`mix precommit` is what CI runs: compile with warnings as errors, prune
unused dependencies, format, test. Run it before every commit.

## Build the image

```sh
docker build -t shop .
```

The image runs pending migrations and then starts the server
(`rel/overlays/bin/entrypoint.sh`). A migration that fails stops the
container, so a broken schema is never served.

## Environment variables

The release reads these at start (`config/runtime.exs`):

| Variable          | Required | Meaning                                                                             |
| ----------------- | -------- | ----------------------------------------------------------------------------------- |
| `DATABASE_URL`    | yes      | `ecto://user:password@host:5432/database`. The connection uses TLS.                 |
| `SECRET_KEY_BASE` | yes      | Signs cookies and tokens. Generate one with `mix phx.gen.secret`.                    |
| `PHX_HOST`        | yes      | The hostname the system is served at, for links in pages and email.                 |
| `PORT`            | no       | HTTP port the server listens on. Default `4000`.                                    |
| `MAIL_FROM`       | no       | Sender address for email, optionally `Name <address>`. Default `noreply@$PHX_HOST`. |
| `AWS_REGION`      | no       | Region for Amazon SES. Default `ca-central-1`.                                      |
| `SHOP_NAME`       | no       | Overrides the shop's name from `config/config.exs`.                                 |
| `POOL_SIZE`       | no       | Database connection pool size. Default `10`.                                        |

Email is sent through Amazon SES using the credentials of the instance
role the container runs under; no access key is configured anywhere.

## Deploy it on your own

`infra/standalone.yaml` is a CloudFormation template that stands the whole
system up in a fresh AWS account in ca-central-1: network, database,
container registry, one instance running the image behind Caddy with a
Let's Encrypt certificate, and an optional DNS record. `infra/README.md`
walks through it and explains how this standalone rendering relates to the
hosted one Bedrock runs. The code is identical in both.

## Continuous integration

`.github/workflows/build.yml` runs `mix precommit` against a PostgreSQL
service on every push to `main`, builds the Docker image, and pushes it to
an Amazon ECR repository. Pushing needs two repository variables:

- `AWS_ROLE_ARN`: an IAM role GitHub assumes through OIDC (no long-lived
  keys). The standalone template can create it.
- `ECR_REPOSITORY`: the name of the ECR repository to push to.

Without `AWS_ROLE_ARN`, the workflow still checks and builds; it skips the
push and says so in the run summary.

## Layout

```
lib/shop/          business logic (contexts, schemas), no web dependencies
lib/shop_web/      the web layer: router, LiveViews, controllers, components
config/            compile-time and runtime configuration
priv/repo/         migrations and seeds
test/              the test suite; CI refuses a change that breaks it
rel/               release overlays, including the container entrypoint
infra/             the standalone CloudFormation template
```
