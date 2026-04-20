# Foggy Helm Charts

Official Helm charts for [Foggy](https://foggyhq.com) — self-hosted AI-native observability for incident investigation.

## Install

```bash
helm repo add foggy https://foggylabs.github.io/helm-charts
helm repo update

kubectl create namespace foggy
helm install foggy foggy/foggy --namespace foggy
```

Full installation guide, RBAC reference, and upgrade instructions:
**<https://docs.foggyhq.com/self-hosted/getting-started>**

## Requirements

- Kubernetes 1.27+
- `kubectl` and `helm` 3.12+
- Foggy license key (request a 30-day trial at <https://foggyhq.com>)
- Anthropic API key (bring your own; Foggy never proxies LLM traffic)

## Charts

| Chart | Version | App version | Description |
|---|---|---|---|
| [foggy](./charts/foggy) | `0.1.0` | `v0.1.0` | Foggy Console + Agent + optional bundled PostgreSQL |

## Review before installing

Preview every Kubernetes resource the chart will create:

```bash
helm template foggy foggy/foggy | less
```

For a focused RBAC review (recommended for security teams):

```bash
helm template foggy foggy/foggy \
  --show-only templates/clusterrole.yaml \
  --show-only templates/clusterrolebinding.yaml \
  --show-only templates/serviceaccount.yaml
```

Foggy's default Kubernetes access is **read-only** (`get`, `list`, `watch` on pods, events, logs, deployments, services, nodes, namespaces). It never accesses Secrets, never executes into pods, and never writes to your cluster. See [the RBAC page](https://docs.foggyhq.com/self-hosted/rbac) for the full permission table.

## Contributing

Issues and PRs welcome at <https://github.com/foggylabs/helm-charts>. For bugs in the Foggy product itself (not the chart), open an issue at <https://github.com/foggylabs/foggy>.

## License

Apache-2.0 — see [LICENSE](./LICENSE).
