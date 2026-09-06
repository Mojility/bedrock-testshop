# Deploying this customer system

This repository owns its application, business database, and website renderer.
Hosted and standalone deployments use the same ARM64 image. Read SYSTEM.md
and BUSINESS.md before transferring a live system.

## Hosted by Roost

Bedrock updates the customer's repository. CI runs the tests and pushes an
immutable commit image to the customer's Canadian ECR repository. Bedrock
verifies the exact build and rehearses it against a private database copy in
Canada, then asks Roost to deploy the image by digest. A source push alone does
not authorize a hosted restart.

The isolated pilot gives each customer a database container and credentials,
private S3 storage with separate editor/runtime roles, and a Caddy hostname.
The host renews the read-only AWS credential file every ten minutes. Roost runs
migrations separately from the server and checks public `/health/ready` before
success. General hosting and off-host backup qualification remain outstanding.

## Standalone recipe

`standalone.yaml` provisions a VPC, encrypted private RDS database, ECR,
an ARM `t4g.small` instance, Caddy, an Elastic IP, and optional DNS/SES
resources
in ca-central-1. The instance uses SSM instead of SSH. Secrets Manager holds
its database and session secrets. This recipe has not received the hosted
pilot's full operational qualification.

Required inputs are `DomainName`, `SecretKeyBase`, and an explicit 40-character
commit SHA in `ImageTag`. `ImageRepositoryName` defaults to `shop` and must
match the CI repository variable. `HostedZoneId` and `CreateSesIdentity` control
DNS and SES setup. `InstanceType` must be an ARM type accepted by the template.

For GitHub CI, set `GitHubRepository` to `owner/name`. For an immutable subject,
also provide both `GitHubOwnerId` and `GitHubRepositoryId`. Obtain those numeric
IDs from the repository API and check its actual OIDC subject configuration.
Older name-based subjects omit both IDs. Both forms trust only `main`; neither
uses wildcard branches. `GitHubOidcProviderArn` can reuse an existing account
provider. The returned role may push images and cannot restart the runtime.

Validate the template before creating or updating resources:

```sh
aws cloudformation validate-template --region ca-central-1 \
  --template-body file://infra/standalone.yaml
```

Create the stack with the explicit parameters through a protected deployment
configuration. Do not put secrets in shell history or commit them. Set the
repository's `AWS_ROLE_ARN` and `ECR_REPOSITORY` from the stack outputs, then
run
the build for the exact `ImageTag` commit. The instance retries its first pull
until that image exists. Point the domain at the `PublicIP` output if DNS is
managed separately. Check SES identity verification and Canadian sending access.

For subsequent releases, qualify the image and migrations, then update the
protected `/opt/shop/image` file to the qualified full ECR image reference
(`repository-uri@sha256:digest`) and restart the service
through trusted SSM access. Restarting a service with the old image reference
does not deploy a new image. The current bootstrap uses the stack image setting
on first boot; a stack parameter update alone does not re-run user data on an
existing host. Do not roll application code back across incompatible database
migrations. Rehearse restore as a separate operation.

## Media, owner access, and recovery

The standalone recipe's database and compute resources are not a complete
customer exit procedure. Preserve or migrate the customer's private S3 bucket,
and configure `MEDIA_BUCKET` plus a renewed, application-scoped
`AWS_CREDENTIALS_FILE` for media reads. The current standalone template does not
automatically create that bucket or renewer. Do not silently lose photographs
or grant fleet permissions to make them load.

Establish the intended owner through `Shop.Release.bootstrap_owner/1` and check
sign-in before switching traffic. The recipe trusts only local Caddy peers
`127.0.0.1` and `::1`. Keep forwarding headers from other peers untrusted. When
moving leads, freeze old submissions, transfer records only within Canada,
compare all source fields, retain source records, and remove temporary exports.
Historical imports must not resend notifications.

RDS retains seven days of automated backups and takes a final snapshot on
stack deletion. Database export and S3 protection are separate responsibilities.
The hosted pilot's local recovery points do not provide off-host backups.
Email remains subject to the deploying account's Canadian SES sandbox and
identity permissions; there is no cross-region fallback.
