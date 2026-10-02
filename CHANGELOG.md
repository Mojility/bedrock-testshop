# Changelog

## [Unreleased]

### Fixed

- Public customer CI no longer resolves a private platform reusable workflow.
  Starter publication remains gated by shared platform validation in a load-safe,
  starter-only workflow declared in `.bedrock/starter-only.json`.

- Unpublished systems accept validated, CSRF-protected enquiries, so a fresh
  workshop passes the same lead, asset and staff checks as a published site.
- The holding form retains invalid input, associates errors and contact help, and
  focuses the first invalid field using the shared controls in both themes.
- Smoke failures report a bounded check name without exception messages or records.
