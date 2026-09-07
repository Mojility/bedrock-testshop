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

Private photographs are served from this application's Canadian S3 bucket.
The runtime reads short-lived credentials from `AWS_CREDENTIALS_FILE` on each
request. The host renews that file. Only explicitly configured proxy addresses
may supply the visitor address used by submission rate limits. The health
endpoint checks both the application and its database. Authenticated previews
use short-lived, signed photograph links so a draft can include photographs
that have not yet been published.

## How it is deployed

Every push to `main` runs the [quality checks](guides/quality.md),
builds an ARM64 container, and pushes
an immutable commit SHA tag to ECR. Roost deploys the image by digest after
Bedrock verifies the build and rehearses it against a private database copy in
Canada. Roost runs `/app/bin/migrate` before `/app/bin/server`; the server does
not repeat migrations on restart. Caddy terminates TLS.

The standalone CloudFormation recipe uses an ARM instance in ca-central-1 and
requires an explicit commit image tag and exact main-branch CI identity. ECR
tags are immutable; the first start resolves the tag to a digest saved in
`/opt/shop/image`. Restarts use that selected digest. Both
the runtime and infrastructure reject a non-Canadian AWS region. Its container
entrypoint runs migrations
before starting. A trusted deployment operator establishes the first owner with
`Shop.Release.bootstrap_owner/1`; no public account bootstrap endpoint exists.

## Where its data lives

All business records live in this system's PostgreSQL database. Roost's isolated
pilot uses a dedicated database container on a Canadian host; standalone uses
the RDS instance created by `infra/standalone.yaml`. Photographs live in the
customer's Canadian S3 bucket. Back up both the database and photographs.
Customer records and runtime secrets are never committed to this repository.

Hosted secrets are protected host files. Runtime containers receive their own
database credentials, session secret, optional preview credential, and scoped
short-lived AWS credentials; they receive no fleet management credentials.
Standalone secrets are owned by the deploying account. SES delivery remains
subject to that account's Canadian-region sending permissions. Set
`LEAD_NOTIFICATIONS=false` and `MAIL_ADAPTER=disabled` for an isolated rehearsal.
The disabled adapter neither delivers nor logs message contents, even when a
credential file is present. Rehearsal credentials must also deny SES delivery.

## Isolated exploration mode

The application can run against a temporary database copy with
`CUSTOMER_EXPLORATION=true`. This mode uses PostgreSQL peer authentication for
local user `developer`, database `exploration`, and socket `/var/run/postgresql`.
It ignores production database, mail, and cloud credential configuration.
Set `EXPLORATION_HOST`, a new private `SECRET_KEY_BASE`, and the exact HTTPS
`EXPLORATION_PARENT_ORIGIN`; optionally set `EXPLORATION_MEDIA_ORIGIN` to the
existing public media origin. Only already published image paths are reused.
Media files are not part of the database checkpoint in this initial mode.

Boot with `PHX_SERVER=true MIX_ENV=prod mix phx.server` after compilation and
asset preparation. A private authenticated gateway is required: this mode
allows a local owner sign-in to the copied system, and must never be enabled on
an internet-accessible production server. Session cookies are host-only,
Secure, SameSite=None and Partitioned; frame ancestors allow only the configured
parent and optional `EXPLORATION_PLATFORM_ORIGIN`, an explicit HTTPS origin for
the platform console. No wildcard ancestors are admitted. Mail delivery is
disabled. The application has no management-platform runtime dependency.

With the server running, execute the actual smoke suite using the same isolated
configuration and `PHX_SERVER=false MIX_ENV=prod mix run --no-start scripts/smoke.exs`.
It checks readiness, public pages and CSS, protected staff access, CSRF denial,
a synthetic lead write, and authenticated staff reading. It deletes only its own
test user, tokens and lead in cleanup. It refuses production mode and non-loopback
HTTP targets. Passing compilation alone does not establish database compatibility;
this suite exercises the selected source and copied schema without migrations.
