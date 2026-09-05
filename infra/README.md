# Deploying this system

The system is one container (built from the `Dockerfile` at the root of
this repository) in front of one PostgreSQL database, behind a reverse
proxy that terminates TLS. That recipe is rendered in two forms. The code,
the image, and the workflow that builds it are identical in both; only the
infrastructure underneath differs.

## Hosted by Bedrock

Bedrock runs the container on its own infrastructure in AWS ca-central-1
(Montréal): the system gets its own database and database role on
Bedrock's shared PostgreSQL instance, its own ECR repository, its own
hostname behind Bedrock's Caddy, and shares the instance fleet, mail
sending, and monitoring. Nothing to do here; every push to `main` builds
and deploys.

Moving from hosted to standalone is a redeploy plus a data move (`pg_dump`
from the hosted database, `pg_restore` into the standalone one), never a
rewrite.

## Standalone: `standalone.yaml`

A CloudFormation template that stands the whole system up in a fresh AWS
account, in ca-central-1, with nothing shared:

- A VPC with two public subnets in two availability zones.
- An RDS PostgreSQL instance (`db.t4g.micro`, encrypted, inside the VPC,
  not publicly reachable), with a generated master password kept in
  Secrets Manager.
- An ECR repository the CI workflow pushes the image to.
- One EC2 instance (`t3.small`, Amazon Linux 2023) running Docker and
  Caddy. Caddy serves the single hostname with a Let's Encrypt certificate
  and proxies to the container; a systemd unit pulls the image from ECR
  and runs it with the secrets from Secrets Manager. No SSH; use SSM
  Session Manager.
- An Elastic IP, and a Route 53 A record for it when you give a hosted
  zone.
- Optionally, an SES identity for the domain, with its DKIM records in
  the hosted zone, so the system can send its sign-in emails.
- Optionally, the IAM role and OIDC provider that let this repository's
  GitHub Actions workflow push images without long-lived keys.

### Parameters

| Parameter                | Meaning                                                                                     |
| ------------------------ | ------------------------------------------------------------------------------------------- |
| `DomainName`             | The hostname the system is served at, for example `app.example.ca`.                         |
| `HostedZoneId`           | Optional. The Route 53 hosted zone of the domain; the A record (and DKIM records) go here.   |
| `SecretKeyBase`          | Phoenix `SECRET_KEY_BASE`; generate with `mix phx.gen.secret`. Kept in Secrets Manager.      |
| `ImageTag`               | The image tag the instance runs. Default `latest`.                                           |
| `ImageRepositoryName`    | Name of the ECR repository to create. Default `shop`. Set `ECR_REPOSITORY` in GitHub to it.  |
| `InstanceType`           | Default `t3.small`.                                                                          |
| `CreateSesIdentity`      | `true` to verify the domain with SES for sending email. Default `true`.                      |
| `GitHubRepository`       | Optional, `owner/name`. Creates the role GitHub Actions assumes to push images.              |
| `GitHubOidcProviderArn`  | Optional. An existing GitHub OIDC provider in the account, if one already exists.            |

### Steps

1. Validate, then create the stack (about 15 minutes, mostly the database):

   ```sh
   aws cloudformation validate-template --region ca-central-1 \
     --template-body file://infra/standalone.yaml

   aws cloudformation deploy --region ca-central-1 \
     --stack-name shop \
     --template-file infra/standalone.yaml \
     --capabilities CAPABILITY_NAMED_IAM \
     --parameter-overrides \
       DomainName=app.example.ca \
       HostedZoneId=Z0123456789ABCDEFGHIJ \
       SecretKeyBase="$(mix phx.gen.secret)" \
       GitHubRepository=your-org/your-repo
   ```

2. Read the outputs:

   ```sh
   aws cloudformation describe-stacks --region ca-central-1 \
     --stack-name shop --query 'Stacks[0].Outputs'
   ```

3. In the GitHub repository's settings, under Variables, set
   `AWS_ROLE_ARN` to the `GitHubActionsRoleArn` output and
   `ECR_REPOSITORY` to the `ImageRepository` output. Push to `main`, or
   run the workflow by hand. The first push builds and pushes the image;
   the instance, which has been retrying the pull, starts the system
   within a minute of it landing.

4. Point the domain at the `PublicIP` output if you did not give a
   hosted zone. Caddy obtains the certificate on the first request.

5. If `CreateSesIdentity` is on and the account's SES is still in the
   sandbox, request production access in the SES console; until then SES
   only delivers to verified addresses.

### After a new image

The workflow pushes every commit to `main`. To run a new image, restart
the service on the instance; the `RestartCommand` output has the exact
command, which uses SSM and needs no SSH:

```sh
aws ssm send-command --region ca-central-1 \
  --document-name AWS-RunShellScript \
  --instance-ids <InstanceId> \
  --parameters 'commands=["systemctl restart shop"]'
```

To roll back, set `ImageTag` to the previous commit's SHA and update the
stack, or edit `/opt/shop/.env` on the instance and restart.

### Backups and export

RDS keeps seven days of automated backups, and deleting the stack takes a
final snapshot of the database. `pg_dump` from the instance (over SSM)
against the `DatabaseEndpoint` output is a complete, plain export.

### Cost

Roughly $35 a month in ca-central-1: the instance, the database, storage,
and the Elastic IP. Free-tier eligible accounts pay less in the first year.
