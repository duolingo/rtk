# Security Policy

## Reporting

Report vulnerabilities via GitHub Security Advisories for this repository.

## Current security baseline

- `cargo audit` in CI
- Dependabot updates for Cargo and GitHub Actions
- PR dependency review (`actions/dependency-review-action`)
- dependency graph submission workflow (`cargo-lock-submission`)

## Non-goals in this fork

- no outbound telemetry
- no local analytics/tracking database
