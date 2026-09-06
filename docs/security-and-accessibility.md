# Security and accessibility

These are implemented controls and evidence gaps in the current source.
They do not establish certification, an assurance report, or accessibility
conformance for a deployed system.

## Implemented controls

| Area | Source behavior | Evidence to retain |
| --- | --- | --- |
| Staff access | Invitation-only magic links, staff scopes, owner-managed revocation | Authorization tests and periodic access review |
| Browser requests | CSRF checks, CSP, security headers, HTTPS redirects behind the trusted edge | Controller tests and deployment header checks |
| Public enquiries | Validation, durable storage, per-node rate limiting | Submission tests and monitoring of abuse patterns |
| Website rendering | Version/hash checks, bounded data-only models, escaped HEEx | Renderer and malformed-input tests |
| Private media | Scoped credentials, published manifests, signed preview links, raster MIME allowlist | Signature, expiry, path, and MIME tests |
| Release checks | Local precommit and blocking CI before image publication | Results tied to source SHA and image digest |
| Dependency review | Weekly scheduled security checks | Triage record and corrective changes |

Sobelow exceptions are narrow reviewed boundaries, described in the
[quality guide](../guides/quality.md#reviewed-security-boundaries).
A passing scan does not prove the absence of vulnerabilities.

## Operational gaps and improvements

- Replace database `verify_none` with certificate-chain and hostname
  verification.
- Define and rehearse database and media recovery, with measured recovery goals.
- Record owner and operator access reviews, revocation, and secret rotation.
- Define incident response, reporting, retention, and deletion procedures.
- Qualify scoped credential renewal, mail delivery, and proxy behavior per
  deployment.
- Review rate-limit behavior before adding nodes or serving shared proxy
  traffic.
- Preserve evidence of changes and releases over time, not only one passing
  build.

Development uses `main`, local precommit, and blocking release CI. It does not
require branch protection or mandatory pull-request approvals. Weekly checks
repeat vulnerability and quality analysis. Release toggles remain a deferred
prelaunch decision; these documents introduce no toggle mechanism.

## Accessibility evidence

The renderer has semantic landmarks and headings, labelled fields, error/help
relationships, image alternatives, and status messages. Component tests exercise
these structures. Theme behavior supports light, dark, and system preferences.
Those tests do not measure every contrast pair or establish usability with
assistive technology.

[WCAG 2.2](https://www.w3.org/TR/WCAG22/) Level AA is a proposed future target.
No conformance claim is made. Assess complete user processes, including enquiry
submission, magic-link login, staff invitations, and follow-up.

Combine automated checks with human evaluation:

- Keyboard navigation, visible focus, and focus order.
- Screen-reader names, landmarks, errors, and live status announcements.
- Contrast in both themes, zoom, reflow, and text spacing.
- Pointer target sizes, reduced motion, and understandable authentication.
- Published customer components and real content, including photo alternatives.

Record the tested revision, browser, assistive technology, process, results,
and unresolved barriers. Recheck changed components and customer customizations.

## Future assurance work

[AICPA SOC
2](https://www.aicpa-cima.com/topic/audit-assurance/audit-and-assurance-greater-than-soc-2/)
addresses controls associated with security, availability, processing integrity,
confidentiality, and privacy. Any future examination needs a defined scope and
sustained operational evidence. Source tests alone cannot establish those
controls
across an organization or an operating period.

Decide the intended service scope and evidence owners before choosing an
assurance program. Document access reviews, change records, recovery exercises,
incident handling, vendor review, and data lifecycle practices as applicable.
