# Self-hosting

The source and production image operate independently. Moving a live business
also requires its database, media, secrets, domain, mail permissions, and a
checked recovery procedure. Copying the repository alone does not move them.

## Prepare the deployment

1. Read the infrastructure recipe in `infra/README.md`.
2. Review [standalone.yaml](../infra/standalone.yaml) in the deploying account.
3. Select Canadian infrastructure and an explicit source commit.
4. Run `mix precommit` with the pinned Elixir and OTP versions.
5. Build the ARM64 image for that revision.
6. Record the immutable image digest and the completed check results.

The recipe provisions private encrypted RDS, ECR, an ARM instance, TLS proxy,
and supporting network resources in `ca-central-1`. It uses SSM administration.
Its operational qualification is incomplete. Rehearse it before moving traffic.

GitHub image publication uses `AWS_ROLE_ARN` and `ECR_REPOSITORY` repository
variables. OIDC trust is restricted to the repository's `main` subject.
Without the role variable, CI builds the image but does not push it.
Weekly and pull-request checks do not publish images.

## Configure runtime access

Use protected configuration for secrets. Do not put secret values in shell
history, commits, screenshots, or shared logs.

| Configuration | Operator responsibility |
| --- | --- |
| `DATABASE_URL`, `SECRET_KEY_BASE` | Supply independent production secrets |
| `PHX_HOST` | Set the public hostname; the code fallback is not a deployment value |
| `AWS_REGION` | Use `ca-central-1`; another region is rejected |
| `MEDIA_BUCKET`, `AWS_CREDENTIALS_FILE` | Supply private media storage and scoped renewable credentials |
| `MAIL_FROM` | Use a sender verified for Canadian SES |
| `TRUSTED_PROXY_IPS` | Name exact proxy peers; keep the application port private |
| `WEBSITE_PREVIEW_SECRET` | Configure only if machine preview is needed; use at least 32 bytes |

The environment-variable table in the repository-root `README.md` lists more
settings. The authoritative behavior is in [runtime.exs](../config/runtime.exs).
Database TLS verifies the certificate chain and the hostname in `DATABASE_URL`.
The release bundles the Canadian RDS CA roots for standalone deployments.
`DATABASE_CA_CERT_PATH` selects an operator-provided PEM trust bundle when needed.
Maintain that bundle as database certificates rotate. `DATABASE_SSL=false` is
for controlled local use. These source changes do not prove a deployed release
uses verified TLS; retain connection and configuration evidence.

The standalone template does not create the media bucket or credential renewer.
Provide both explicitly. The runtime rereads renewed credentials and rejects
expired files. Standalone mail may use the application's instance role.
Credential-file deployments use customer-scoped credentials for mail and media.
SES sending access and identity verification must be resolved in Canada.

## Start and check a release

Do not replay a migration with an uncertain outcome. An application rollback
may be incompatible with a completed database migration.

1. Back up the database and media before a production change.
2. Rehearse migrations and application checks against an isolated Canadian copy.
3. Select the qualified image digest through trusted deployment access.
4. Run migrations before serving the release.
5. Establish the first owner with `Shop.Release.bootstrap_owner/1` if none
   exists.
6. Request a magic link at `/users/log-in` using the intended owner's email.
7. Check staff access, an enquiry, mail delivery, and public HTTPS readiness.
8. Record the live image digest and migration outcome.

The default container entrypoint migrates, then starts the server. A deployment
that runs `/app/bin/migrate` separately should start `/app/bin/server`
afterward.

For later standalone releases, update the protected `/opt/shop/image` reference
as described in the infrastructure guide. Changing the stack image parameter
alone does not rerun initialization on an existing instance.

## Preview and recovery

Machine preview uses a credential separate from staff login. Preview responses
contain HTML and may contain signed draft-photo links valid for 15 minutes.
Keep those responses private. There is no public endpoint that writes scenes.

For isolated rehearsals, set `LEAD_NOTIFICATIONS=false` and
`MAIL_ADAPTER=disabled`. Deny SES delivery in rehearsal credentials as well.
The disabled adapter sends no message and logs no message body.

The standalone RDS resource retains seven days of automated backups and requests
a final snapshot on deletion. These settings are not proof of a successful
restore. S3 protection, database exports, retention, access controls, and
recovery
exercises remain operator responsibilities.

Before accepting a recovery plan, restore the database and photographs into an
isolated environment. Check record counts, owner access, preview isolation, and
public media. Record recovery duration, acceptable data loss, and evidence.
Retain source records until a transfer is checked. Remove temporary exports
securely after the transfer is accepted.
