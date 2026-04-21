# Helm Chart Hygiene Batch (B-3 + B-5 + BL-99) — Implementation Plan

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:subagent-driven-development (recommended) or superpowers:executing-plans to implement this plan task-by-task.

**Goal:** Fix three related chart-hygiene issues discovered in the Phase C dry run:
1. **B-3** — NOTES.txt prints `vv0.2.7` (double `v`) because the template has `v{{ .Chart.AppVersion }}` and `appVersion` already starts with `v`.
2. **B-5** — Root `README.md` version table lists `0.1.3 | v0.1.0` — two full minor versions behind. Customers reading README before install see wrong numbers.
3. **BL-99** — console-backend pod crashes 4-5 times on fresh install while Postgres is still starting up. Fix: initContainer that waits for `postgres:5432` before main container starts.

**Architecture:** All three changes are in `charts/foggy/*` and the repo README — single chart, single PR. Chart version bumps from `0.2.3` → `0.2.4` (PATCH — bug fixes only, no behavior change for existing healthy installs). `appVersion` stays at `v0.2.7` — no Foggy app changes.

**Tech Stack:** Helm 3.12+, Kubernetes 1.27+. InitContainer uses `busybox:1.36` (1.4 MB, has `nc` built in — the canonical choice across Bitnami, Grafana, Linkerd helm charts for "wait for TCP port" patterns).

---

## Peer grounding for initContainer (BL-99)

| Chart | Image | Command | Condition |
|---|---|---|---|
| Bitnami `postgresql-ha` consumers | `docker.io/bitnami/os-shell` | `until pg_isready -h ... -p 5432; do ...` | when chart depends on postgres |
| Grafana chart | `busybox:1.x` | `until nc -z {{ .Release.Name }}-postgresql 5432; do sleep 2; done` | when `postgresql.enabled=true` |
| Linkerd / Cert-Manager | `busybox` or custom `wait-for` | `nc -z` pattern | service-dependency wait |

All converge on: `busybox` + `nc -z` + short sleep loop, gated on the dependency being in-cluster. For Foggy: service name is `{{ .Release.Name }}-postgresql` (Bitnami subchart convention, matches the secret reference at `console-backend-deployment.yaml:48`). Port 5432.

Do NOT use `pg_isready` — requires pulling full postgres client image (~20-50 MB) just to check TCP port reachability. `nc -z` is sufficient; the app container's asyncpg pool will handle connection-level retries once TCP is up.

Do NOT use `latest` image tag — pin to `busybox:1.36` for reproducibility (standard operational hygiene).

---

## File Structure

**Modify:**
- `charts/foggy/Chart.yaml`
  - Bump `version: 0.2.3` → `version: 0.2.4`.
  - Update `annotations.artifacthub.io/changes` with new entries for B-3, B-5, BL-99 (ArtifactHub renders these on the chart listing).
  - `appVersion: "v0.2.7"` UNCHANGED — no app-layer changes.
- `charts/foggy/templates/NOTES.txt`
  - Line 1: `v{{ .Chart.AppVersion }}` → `{{ .Chart.AppVersion }}` (remove the literal `v` — `appVersion` already begins with `v`).
- `charts/foggy/templates/console-backend-deployment.yaml`
  - Add `initContainers:` block (under `spec.template.spec`, above `containers:`), gated on `{{- if .Values.postgresql.enabled }}`.
  - Runs `busybox:1.36` with `nc -z {{ .Release.Name }}-postgresql 5432` poll.
- `README.md` (repo root)
  - Chart table row: `0.1.3 | v0.1.0` → `0.2.4 | v0.2.7`.
  - Verify install commands still match reality (no change expected).
  - Verify RBAC review commands still match reality (no change expected).

**NOT touched:**
- `charts/foggy/values.yaml` — no new knobs. The initContainer uses hard-coded `busybox:1.36` and port 5432 because those are invariants of the Bitnami postgres subchart we depend on, not user-configurable deployment concerns. Adding `consoleBackend.waitForDatabase.enabled` etc. would be YAGNI.
- `charts/foggy/templates/agent-deployment.yaml` — the agent service is stateless and doesn't touch the database. No initContainer needed.
- `charts/foggy/templates/_helpers.tpl` — no new helpers required.

**Why one PR for three items:** They touch the same chart, all three are chart-hygiene bugs found in the same dry run, and bundling them means one `chart version` bump (`0.2.3 → 0.2.4`) instead of three. Each commit inside the PR is separate so the history is still readable (B-3 commit, B-5 commit, BL-99 commit, then chart-version bump commit).

---

### Task 1: Fix B-3 — NOTES.txt double `v`

**Files:**
- Modify: `charts/foggy/templates/NOTES.txt`

- [ ] **Step 1: Remove literal `v` prefix on line 1**

Before:
```
Thanks for installing {{ .Chart.Name }} v{{ .Chart.AppVersion }}.
```
After:
```
Thanks for installing {{ .Chart.Name }} {{ .Chart.AppVersion }}.
```

`appVersion` is already `"v0.2.7"` — the template had been double-prefixing.

- [ ] **Step 2: Verify with helm template**

Run: `helm template test-release charts/foggy --set postgresql.enabled=true --show-only templates/NOTES.txt 2>/dev/null || helm install --dry-run --debug test-release charts/foggy 2>&1 | grep 'Thanks for installing'`

NOTES.txt doesn't render via `--show-only` (it's NOT a manifest) so `helm install --dry-run` is the path. Expected output: `Thanks for installing foggy v0.2.7.` (single `v`).

---

### Task 2: Fix B-5 — README version table

**Files:**
- Modify: `README.md` (repo root)

- [ ] **Step 1: Update chart version + appVersion in the table**

Before (line 29):
```markdown
| [foggy](./charts/foggy) | `0.1.3` | `v0.1.0` | Foggy Console + Agent + optional bundled PostgreSQL |
```
After:
```markdown
| [foggy](./charts/foggy) | `0.2.4` | `v0.2.7` | Foggy Console + Agent + optional bundled PostgreSQL |
```

- [ ] **Step 2: Sanity-check other claims in README**

Walk the file and verify each factual claim still holds:
- `helm repo add foggy https://foggylabs.github.io/helm-charts` — confirmed by `chart-releaser` publishing target
- `helm install foggy foggy/foggy --namespace foggy` — confirmed, matches `consoleBackend.replicas` default
- `Kubernetes 1.27+` — matches `Chart.yaml` `kubeVersion: ">=1.27.0-0"`
- `helm 3.12+` — unchanged requirement
- `helm template` / `--show-only` commands — verify they produce sensible output on 0.2.4

Fix any other drifts found in the walk. Keep the scope minimal — if something is vague rather than wrong, leave it for a docs pass.

---

### Task 3: Fix BL-99 — initContainer for Postgres wait

**Files:**
- Modify: `charts/foggy/templates/console-backend-deployment.yaml`

- [ ] **Step 1: Add initContainers block**

Insert between `spec.template.spec.imagePullSecrets` (line 25-28) and `containers:` (line 29):

```yaml
      {{- if .Values.postgresql.enabled }}
      initContainers:
        - name: wait-for-postgres
          image: busybox:1.36
          imagePullPolicy: IfNotPresent
          command:
            - sh
            - -c
            - |
              until nc -z {{ .Release.Name }}-postgresql 5432; do
                echo "waiting for {{ .Release.Name }}-postgresql:5432 to accept connections..."
                sleep 2
              done
              echo "postgres is ready."
          resources:
            requests:
              cpu: 10m
              memory: 16Mi
            limits:
              cpu: 100m
              memory: 64Mi
      {{- end }}
```

**Rationale per field:**
- `{{- if .Values.postgresql.enabled }}` — external databases are already up; no wait needed.
- `busybox:1.36` — pinned, 1.4 MB, `nc` built in. Matches Bitnami/Grafana chart pattern.
- `imagePullPolicy: IfNotPresent` — don't re-pull on every restart; fresh pulls happen on first scheduling.
- `sleep 2` — fast enough that recovery is quick, slow enough not to hammer the service.
- Small resource requests/limits — pod scheduler needs them; match common Bitnami patterns.

- [ ] **Step 2: Verify template renders**

Run: `helm lint charts/foggy` — expect zero warnings.

Run: `helm template test charts/foggy --set postgresql.enabled=true | grep -A 20 "initContainers:"` — expect the `wait-for-postgres` container with a rendered `test-postgresql` hostname.

Run: `helm template test charts/foggy --set postgresql.enabled=false | grep -c "initContainers:"` — expect `0`.

- [ ] **Step 3: Verify on kind cluster (if reasonable)**

If the `foggy-dryrun` kind cluster from the 2026-04-21 session still exists, upgrade the test install to this branch's chart and check:

```bash
helm upgrade foggy ./charts/foggy -n foggy --wait
kubectl -n foggy get pods -w
```

Expect: console-backend pod starts with `Init:0/1` briefly, then transitions to `Running` without any `CrashLoopBackOff` cycles.

If the kind cluster was torn down, skip this step — `helm lint` + `helm template` coverage is sufficient pre-PR; real-cluster verification happens post-merge during the next Manychat install dry-run.

---

### Task 4: Bump chart version + ArtifactHub changelog

**Files:**
- Modify: `charts/foggy/Chart.yaml`

- [ ] **Step 1: Bump `version: 0.2.3` → `version: 0.2.4`**

PATCH bump — all three fixes are backwards-compatible bug fixes, no template schema changes, no values.yaml changes, no new permissions. Existing healthy installs upgrade cleanly.

- [ ] **Step 2: Update `annotations.artifacthub.io/changes`**

Replace the single-entry v0.2.7 description with three entries for v0.2.4 chart release:

```yaml
annotations:
  artifacthub.io/changes: |
    - kind: fixed
      description: "NOTES.txt no longer double-prefixes appVersion — was `vv0.2.7`, now `v0.2.7`. Cosmetic but confusing for customers seeing post-install output for the first time."
    - kind: fixed
      description: "console-backend now waits for Postgres before starting (initContainer, gated on postgresql.enabled=true). Fresh installs previously showed 4-5 CrashLoopBackOff cycles while backend retried TCP connections to a still-initializing Postgres pod. Recovery was eventual but scary — helm install --wait --timeout 5m could also give up before self-healing finished."
    - kind: fixed
      description: "Repo README chart version table updated from stale 0.1.3 / v0.1.0 to 0.2.4 / v0.2.7 — customers reading README before install now see correct current versions."
```

ArtifactHub renders these next to the chart listing so customers see what changed.

---

### Task 5: Commit per item, then open PR

Four commits on the branch (helm-charts uses squash-merge on PR; the per-commit history is branch-local for readability during review):

- [ ] **Commit 1**: `fix(notes): remove double v prefix on appVersion (B-3)` — NOTES.txt only
- [ ] **Commit 2**: `docs(readme): update version table to current chart/app versions (B-5)` — README.md only
- [ ] **Commit 3**: `fix(console-backend): wait for postgres before startup (BL-99)` — console-backend-deployment.yaml only
- [ ] **Commit 4**: `chore(chart): bump to 0.2.4 with hygiene fixes` — Chart.yaml version + ArtifactHub annotations

- [ ] **Step: Push and open draft PR**

```bash
git push -u origin fix/b3-b5-bl99-notes-readme-initcontainer
gh pr create --draft --title "chore(chart): hygiene batch — NOTES, README, initContainer (0.2.4)" --body <see PR template in Task 5 body>
```

PR body: summary per fix, peer grounding for initContainer, test plan, links to foggy repo issues/tickets (B-3, B-5, BL-99).

---

## Out of Scope

- Extracting initContainer image into a configurable value — YAGNI; `busybox:1.36` is a deliberate pin.
- Adding `pg_isready`-based wait — overkill for TCP reachability check.
- Adding initContainer to `agent-deployment.yaml` — agent is stateless.
- Moving `nc -z` to a shared `_helpers.tpl` wait template — one call site; premature abstraction.
- Adding CI check that `appVersion` and `v`-prefix in NOTES.txt stay consistent — nice-to-have, track separately if this class of bug recurs.

## Self-Review

**Spec coverage:** All three BACKLOG items (B-3, B-5, BL-99) each have a dedicated task with before/after shape. Chart version bump + ArtifactHub changelog explicitly listed.

**Placeholder scan:** No TBDs. Every YAML block is full, compilable, and pinned.

**Type consistency:** Chart `version` jumps 0.2.3 → 0.2.4 (PATCH). `appVersion` unchanged (`v0.2.7`). No mismatch risk.

**Scope check:** One PR, three fixes, all chart-hygiene. Could be split, but they co-require the same `chart version` bump so bundling saves churn.

**Gaps I'd flag in review:**
1. InitContainer doesn't handle the case where the user provides an external Postgres (postgresql.enabled=false) but the external DB is unreachable at boot. That's a legitimate concern but out-of-scope — customers with managed Postgres typically use PaaS with high availability and don't need in-cluster wait logic. If it surfaces in a customer install, add a separate `externalDatabase.waitFor: hostname:port` opt-in knob.
2. initContainer resource requests are small but LIMITS could matter on clusters with restrictive LimitRanges. `100m / 64Mi` is conservative and should satisfy most LimitRange constraints.
3. README only fixes the version table — other claims (`Foggy license key (request a 30-day trial at https://foggyhq.com)`, etc.) are still accurate but haven't been exhaustively re-verified. Task 2 Step 2 asks for a walk; anything stale gets fixed inline.
