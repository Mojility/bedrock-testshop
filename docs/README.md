# Application documentation

This repository contains TestShop's independently operated business system.
These guides describe source behavior, deployment responsibilities, and work
that still needs operational evidence. They do not certify a live deployment.

| Need | Start here |
| --- | --- |
| Understand the business capabilities | [Product](product.md) |
| Follow data and trust boundaries | [Architecture](architecture.md) |
| Operate the system independently | [Self-hosting](self-hosting.md) |
| Review controls and remaining evidence | [Security and accessibility](security-and-accessibility.md) |
| Run development and release checks | [Quality checks](../guides/quality.md) |

The repository-root `README.md` covers local setup.
[SYSTEM.md](../SYSTEM.md) records the current application inventory.
[BUSINESS.md](../BUSINESS.md) explains staff access and lead transfer.
[WEBSITE.md](../WEBSITE.md) describes component extensions and publication.

Development uses trunk-based commits on `main`. Run `mix precommit` locally.
Blocking CI checks must pass before image publication. Monday audits repeat the
checks without requiring a source change. Pull requests are optional; mandatory
PR approvals and branch protection are not part of this workflow.
Release toggles remain deferred until the prelaunch design is revisited.
No new toggle mechanism is introduced by these guides.
