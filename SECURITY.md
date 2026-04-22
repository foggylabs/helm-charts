# Security Policy

## Reporting a vulnerability

If you discover a security issue in this Helm chart (templates, values defaults, RBAC definitions, CI configuration) or in the Foggy images the chart deploys, please report it **privately** by email:

**security@foggyhq.com**

Do **not** open a public GitHub issue or PR for security reports. We need to coordinate a fix and publish a patched release before the details are public.

### What to include

- The chart version — `helm list -n <namespace>` or `helm show chart foggy/foggy`.
- A description of the issue and, if possible, steps to reproduce.
- Your assessment of the impact (confidentiality / integrity / availability).
- Any preferred credit name if you'd like acknowledgement in the release notes.

### What to expect from us

- **72 hours** — initial acknowledgement that we received the report and are looking into it.
- **7 days** — triage result, severity classification, and a proposed fix timeline.
- **Coordinated disclosure** — we ship a patched release, then publish the advisory. If you request it, we credit you in the release notes and advisory.

## Supported versions

Foggy is in the `0.x.y` pre-stable phase. We patch the latest minor series only. Older `0.x` lines are not backported to unless the issue is critical and customers are provably still on them — in that case we'll reach out directly.

| Chart version | Supported for security fixes |
| ------------- | ---------------------------- |
| Latest `0.x.y` | Yes |
| Previous minor | Best-effort, case by case |
| Older | No — please upgrade |

Once we ship `1.0.0`, this table will be rewritten with proper LTS windows.

## Scope

This policy covers:

- The Helm chart in `charts/foggy/` of this repository — templates, default `values.yaml`, RBAC manifests.
- The three Foggy images the chart deploys: `ghcr.io/foggylabs/foggy-agent`, `ghcr.io/foggylabs/foggy-console-backend`, `ghcr.io/foggylabs/foggy-console-frontend`. Source lives at <https://github.com/foggylabs/foggy> — private repo; route application-layer reports to the same email address and we'll triage internally.
- The release workflow (`.github/workflows/release.yml`) and CI pipeline (`.github/workflows/lint-test.yml`).

Out of scope:

- Vulnerabilities in Kubernetes itself, in `kubectl`/`helm` CLI tooling, or in the Bitnami PostgreSQL subchart (report those upstream).
- Security issues in customer-configured external connectors (Grafana, Slack, GitHub tokens, etc.) — those are governed by the respective service's policy.

## Disclosure history

Published advisories will be linked here once any exist.
