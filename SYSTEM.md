# TestShop's system

This document describes the system as it is now. Bedrock's generators keep
it current: every change that adds, removes, or moves something updates
the sections below in the same commit.

## What it is

A Phoenix 1.8 application (Elixir, LiveView, Ecto on PostgreSQL) in this
repository, built to how TestShop works. It runs as one container
from the `Dockerfile` here, in front of one PostgreSQL database.

## What it contains

- **Accounts** (`lib/shop/accounts/`): who can sign in. Sign-in is by
  magic link sent to the account's email; there are no passwords. A user
  may change their own email from Settings. Tables: `users`,
  `users_tokens`. Owner and staff access is invitation-only; see `BUSINESS.md`.

- **Website** (`lib/shop/website/`, `lib/shop_web/website_html.ex`): renders a
  versioned scene from `priv/published_site/scene.json`. The renderer and
  component model belong to this repository. Public content can come from this
  application's database through `Shop.Website.Content`. See `WEBSITE.md`.
  Publishing updates scene/assets; it never replaces component implementations.

- **Leads** (`lib/shop/leads/`): public enquiry submission and authenticated
  follow-up at `/app/leads`. Pending email notifications retry independently.
  `/app/team` lets the owner invite staff and revoke access. Tables: `leads`.

Private-media delivery, trusted proxy address resolution, initial owner
provisioning, and release validation remain deployment integrations.

## How it is deployed

Every push to `main` runs the test suite (`mix precommit`), builds the
image, and pushes it to an Amazon ECR repository tagged `latest` and with
the commit SHA (`.github/workflows/build.yml`). An instance running
Docker pulls that image and runs it behind Caddy, which terminates TLS
with a Let's Encrypt certificate. On start, the container runs pending
migrations and then serves.

Two renderings of the same deployment exist, with identical code:

- **Hosted by Bedrock**: the container runs on Bedrock's infrastructure
  in ca-central-1, with its own database on a shared PostgreSQL instance.
- **Standalone**: `infra/standalone.yaml` stands everything up in an AWS
  account of TestShop's own, in ca-central-1.

## Where its data lives

All business data is in the system's PostgreSQL database, and only there.
Hosted, that is a database of its own on Bedrock's RDS instance in
ca-central-1 (Montréal); standalone, it is the RDS instance the template
creates. Nothing is replicated outside Canada. The schema is the
migrations under `priv/repo/migrations/`, and `pg_dump` of the database is
a complete export.

Secrets (database credentials, `SECRET_KEY_BASE`) live in AWS Secrets
Manager in the deploying account. No secret and no customer data is in
this repository.
