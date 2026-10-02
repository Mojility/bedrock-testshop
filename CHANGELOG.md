# Changelog

## [Unreleased]

### Fixed

- Unpublished systems accept validated, CSRF-protected enquiries, so a fresh
  workshop passes the same lead, asset and staff checks as a published site.
- The holding form retains invalid input, associates errors and contact help, and
  focuses the first invalid field using the shared controls in both themes.
- Smoke failures report a bounded check name without exception messages or records.
