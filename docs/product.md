# Product

TestShop owns the source, business records, and deployment choices for this
application. It combines a public website with a private workspace for enquiries
and staff access. It can operate without the service that originally generated
it.

## People and capabilities

| Person | Available capability | Current limit |
| --- | --- | --- |
| Website visitor | Read published content and submit an enquiry | Submission validation and a per-node rate limit apply |
| Invited staff member | Sign in by email link and record follow-up | Workspace lists the latest 200 leads |
| Business owner | Work with leads, invite staff, revoke staff access | Owner transfer is not implemented |
| Deployment operator | Establish the first owner and operate the release | Requires trusted infrastructure access |

A successful submission stores the lead before email notification.
Email failures leave the lead available in the workspace. Pending notifications
retry; a crash around delivery can result in duplicate notifications.
The application does not provide public account registration or password login.

## Website ownership

The repository owns the scene renderer, component definitions, and native
components. A publication updates the scene, media manifest, and public assets.
It must preserve customized application code and business data.
Public application content can change independently of the published scene.

The stock starter is an origin for new repositories. An existing business
repository is maintained selectively; replacing it wholesale from the starter
would discard its ownership and customization boundaries.

## Growth and limits

This source currently provides website publication support, lead follow-up,
passwordless staff access, and owner-managed invitations. It does not establish
a complete scheduling, invoicing, accounting, or customer relationship system.

Possible additions include lead search and pagination, owner transfer, and
business-specific modules. Each addition needs its own behavior, authorization,
accessibility, migration, and recovery checks.

The intended data location is Canada. Storage, media, backups, credentials,
mail,
and operational diagnostics require Canadian infrastructure and operator review.
The application rejects a non-Canadian AWS region, but code alone cannot prove
where every external service or backup stores data.
