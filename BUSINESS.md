# Business workspace

The business operates this application independently of Bedrock. Leads,
follow-up, accounts, and session tokens live in this application's database.

## Staff access

The first owner must be established through trusted deployment access. There
is no public registration or bootstrap endpoint. Run database migrations first.
Call `Shop.Release.bootstrap_owner(email)` in the release with the intended
owner's verified provisioning email. The function creates an unconfirmed owner
account. It rejects subsequent bootstrap attempts once an owner exists.
The owner requests a magic link at `/users/log-in` and confirms their email.
No password or Bedrock session is copied.

The owner invites staff at `/app/team`. Staff can work with leads; only the
owner can manage access. Revocation invalidates tokens and disconnects sessions.
Existing accounts have an unassigned role until the owner explicitly invites
them or trusted bootstrap selects the owner. New invited accounts have the staff
role. Owner transfer and a separate administrator role are future extensions.

## Leads

The scene-rendered website submits to `POST /leads`. The route checks CSRF,
validates contact details, and stores the enquiry before returning a thank-you.
A missing or incompatible website release refuses submissions explicitly.

Signed-in staff work at `/app/leads`. The workspace shows the latest 200
messages, contact links, status, and follow-up notes. Older records remain in
the database. Search and pagination can extend this initial workspace.

Notifications go to confirmed owners using this application's mailer. Pending
leads retry every 30 seconds. A failed email never removes the lead. A crash
at the delivery boundary can send a duplicate notification. Historical imports
are marked as already notified.

The initial rate limiter allows ten attempts per network peer each hour. It
uses the connection address, never an untrusted forwarding header. Set
`TRUSTED_PROXY_IPS` to the exact proxy peer addresses before use behind
a shared proxy;
otherwise visitors behind that proxy share the limit. Counters are per node
and reset when the application restarts.

## Transfer existing leads

Keep the old records until the transfer has been checked. Transfer files must
stay in Canadian infrastructure and must not appear in source control or logs.

1. Deploy and check this release, its database, and owner sign-in.
2. Stop submissions to the old endpoint during the final export.
3. Export only the intended tenant with `Bedrock.Leads.export_legacy(tenant)`.
4. Transfer the JSON array to a protected file beside this release.
5. Call `Shop.Release.import_legacy_leads(path)` through trusted release access.
6. Compare identifiers, content, timestamps, and record counts.
7. Route the public website to this application.
8. Remove the transfer file after the records have been checked.

The importer is transactional and replay-safe. It preserves the original
identifier in `legacy_id` and keeps existing follow-up on repeated imports.
It does not call Bedrock or require a live platform connection.
