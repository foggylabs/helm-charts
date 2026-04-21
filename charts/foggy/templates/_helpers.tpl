{{/*
Expand the name of the chart.
*/}}
{{- define "foggy.name" -}}
{{- default .Chart.Name .Values.nameOverride | trunc 63 | trimSuffix "-" }}
{{- end }}

{{/*
Create a default fully qualified app name.
Truncated at 63 chars because some Kubernetes name fields are limited to this.
*/}}
{{- define "foggy.fullname" -}}
{{- if .Values.fullnameOverride }}
{{- .Values.fullnameOverride | trunc 63 | trimSuffix "-" }}
{{- else }}
{{- $name := default .Chart.Name .Values.nameOverride }}
{{- if contains $name .Release.Name }}
{{- .Release.Name | trunc 63 | trimSuffix "-" }}
{{- else }}
{{- printf "%s-%s" .Release.Name $name | trunc 63 | trimSuffix "-" }}
{{- end }}
{{- end }}
{{- end }}

{{/*
Chart label.
*/}}
{{- define "foggy.chart" -}}
{{- printf "%s-%s" .Chart.Name .Chart.Version | replace "+" "_" | trunc 63 | trimSuffix "-" }}
{{- end }}

{{/*
Common labels applied to every resource the chart creates.
*/}}
{{- define "foggy.labels" -}}
helm.sh/chart: {{ include "foggy.chart" . }}
{{ include "foggy.selectorLabels" . }}
app.kubernetes.io/version: {{ .Chart.AppVersion | quote }}
app.kubernetes.io/managed-by: {{ .Release.Service }}
app.kubernetes.io/part-of: foggy
{{- end }}

{{/*
Selector labels — stable across upgrades (do not include version).
*/}}
{{- define "foggy.selectorLabels" -}}
app.kubernetes.io/name: {{ include "foggy.name" . }}
app.kubernetes.io/instance: {{ .Release.Name }}
{{- end }}

{{/*
Per-component selector labels (agent / console-backend / console-frontend).
Usage: {{ include "foggy.componentSelectorLabels" (dict "ctx" . "component" "agent") }}
*/}}
{{- define "foggy.componentSelectorLabels" -}}
{{ include "foggy.selectorLabels" .ctx }}
app.kubernetes.io/component: {{ .component }}
{{- end }}

{{/*
Name of the ServiceAccount used by the Agent pod.
*/}}
{{- define "foggy.serviceAccountName" -}}
{{- if .Values.serviceAccount.create }}
{{- default (include "foggy.fullname" .) .Values.serviceAccount.name }}
{{- else }}
{{- default "default" .Values.serviceAccount.name }}
{{- end }}
{{- end }}

{{/*
Name of the read-only ClusterRole the chart creates.
*/}}
{{- define "foggy.clusterRoleName" -}}
{{- if .Values.rbac.customClusterRoleName }}
{{- .Values.rbac.customClusterRoleName }}
{{- else }}
{{- printf "%s-readonly" (include "foggy.fullname" .) }}
{{- end }}
{{- end }}

{{/*
Name of the Secret holding app-level secrets (JWT_SECRET, AGENT_API_TOKEN,
CONNECTOR_ENCRYPTION_KEY). Customer-provided Secret takes precedence.
*/}}
{{- define "foggy.secretName" -}}
{{- if .Values.secrets.existingSecret }}
{{- .Values.secrets.existingSecret }}
{{- else }}
{{- printf "%s-secrets" (include "foggy.fullname" .) }}
{{- end }}
{{- end }}

{{/*
Name of the admin bootstrap Secret.
*/}}
{{- define "foggy.adminSecretName" -}}
{{- if .Values.admin.existingSecret }}
{{- .Values.admin.existingSecret }}
{{- else }}
{{- printf "%s-admin" (include "foggy.fullname" .) }}
{{- end }}
{{- end }}

{{/*
Image reference helper. Falls back to chart appVersion when `tag` is unset.
Usage: {{ include "foggy.image" (dict "ctx" . "image" .Values.agent.image) }}
*/}}
{{- define "foggy.image" -}}
{{- $registry := .ctx.Values.global.image.registry | default "ghcr.io" -}}
{{- $repo := .image.repository -}}
{{- $tag := .image.tag | default .ctx.Chart.AppVersion -}}
{{- printf "%s/%s:%s" $registry $repo $tag -}}
{{- end }}

{{/*
PostgreSQL connection URL. Prefers external DB when configured; otherwise
derives from the bundled Bitnami subchart service + auth values.
The returned URL uses the `postgresql+asyncpg://` scheme that Foggy's
SQLAlchemy engine expects; the backend entrypoint rewrites it to plain
`postgresql://` for dbmate migrations.
*/}}
{{- define "foggy.databaseUrl" -}}
{{- if .Values.postgresql.enabled -}}
{{- $host := printf "%s-postgresql" .Release.Name -}}
{{- $user := .Values.postgresql.auth.username -}}
{{- $db := .Values.postgresql.auth.database -}}
{{- /* Bundled Bitnami PostgreSQL subchart does not enable TLS by default,
   so we explicitly set sslmode=disable here. The foggy-console-backend
   entrypoint (v0.2.3+) respects any sslmode already in DATABASE_URL and
   only defaults to sslmode=require when none is specified. Operators
   supplying their own Postgres via externalDatabase.url keep full control
   over sslmode — nothing here interferes with that branch. */ -}}
{{- printf "postgresql+asyncpg://%s:$(POSTGRES_PASSWORD)@%s:5432/%s?sslmode=disable" $user $host $db -}}
{{- else -}}
{{- .Values.externalDatabase.url -}}
{{- end -}}
{{- end }}
