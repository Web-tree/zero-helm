{{/*
Expand the name of the chart.
*/}}
{{- define "zero.name" -}}
{{- default .Chart.Name .Values.nameOverride | trunc 63 | trimSuffix "-" }}
{{- end }}

{{/*
Create a default fully qualified app name.
*/}}
{{- define "zero.fullname" -}}
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
Create chart name and version as used by the chart label.
*/}}
{{- define "zero.chart" -}}
{{- printf "%s-%s" .Chart.Name .Chart.Version | replace "+" "_" | trunc 63 | trimSuffix "-" }}
{{- end }}

{{/*
Common labels
*/}}
{{- define "zero.labels" -}}
helm.sh/chart: {{ include "zero.chart" . }}
{{ include "zero.selectorLabels" . }}
{{- if .Chart.AppVersion }}
app.kubernetes.io/version: {{ .Chart.AppVersion | quote }}
{{- end }}
app.kubernetes.io/managed-by: {{ .Release.Service }}
{{- end }}

{{/*
Selector labels
*/}}
{{- define "zero.selectorLabels" -}}
app.kubernetes.io/name: {{ include "zero.name" . }}
app.kubernetes.io/instance: {{ .Release.Name }}
{{- end }}

{{/*
ServiceAccount name
*/}}
{{- define "zero.serviceAccountName" -}}
{{- if .Values.serviceAccount.create }}
{{- default (include "zero.fullname" .) .Values.serviceAccount.name }}
{{- else }}
{{- default "default" .Values.serviceAccount.name }}
{{- end }}
{{- end }}

{{/*
Container image
*/}}
{{- define "zero.image" -}}
{{- printf "%s:%s" .Values.image.repository (default .Chart.AppVersion .Values.image.tag) }}
{{- end }}

{{/*
Replication Manager fullname
*/}}
{{- define "zero.replicationManager.fullname" -}}
{{- printf "%s-replication-manager" (include "zero.fullname" .) | trunc 63 | trimSuffix "-" }}
{{- end }}

{{/*
Replication Manager labels
*/}}
{{- define "zero.replicationManager.labels" -}}
{{ include "zero.labels" . }}
app.kubernetes.io/component: replication-manager
{{- end }}

{{/*
Replication Manager selector labels
*/}}
{{- define "zero.replicationManager.selectorLabels" -}}
{{ include "zero.selectorLabels" . }}
app.kubernetes.io/component: replication-manager
{{- end }}

{{/*
View Syncer fullname
*/}}
{{- define "zero.viewSyncer.fullname" -}}
{{- printf "%s-view-syncer" (include "zero.fullname" .) | trunc 63 | trimSuffix "-" }}
{{- end }}

{{/*
View Syncer labels
*/}}
{{- define "zero.viewSyncer.labels" -}}
{{ include "zero.labels" . }}
app.kubernetes.io/component: view-syncer
{{- end }}

{{/*
View Syncer selector labels
*/}}
{{- define "zero.viewSyncer.selectorLabels" -}}
{{ include "zero.selectorLabels" . }}
app.kubernetes.io/component: view-syncer
{{- end }}

{{/*
Database secret name
*/}}
{{- define "zero.databaseSecretName" -}}
{{- if .Values.existingSecrets.database }}
{{- .Values.existingSecrets.database }}
{{- else }}
{{- printf "%s-database" (include "zero.fullname" .) }}
{{- end }}
{{- end }}

{{/*
AWS secret name
*/}}
{{- define "zero.awsSecretName" -}}
{{- if .Values.existingSecrets.aws }}
{{- .Values.existingSecrets.aws }}
{{- else }}
{{- printf "%s-aws" (include "zero.fullname" .) }}
{{- end }}
{{- end }}

{{/*
Admin secret name
*/}}
{{- define "zero.adminSecretName" -}}
{{- if .Values.existingSecrets.admin }}
{{- .Values.existingSecrets.admin }}
{{- else }}
{{- printf "%s-admin" (include "zero.fullname" .) }}
{{- end }}
{{- end }}

{{/*
Auth secret name
*/}}
{{- define "zero.authSecretName" -}}
{{- if .Values.existingSecrets.auth }}
{{- .Values.existingSecrets.auth }}
{{- else }}
{{- printf "%s-auth" (include "zero.fullname" .) }}
{{- end }}
{{- end }}

{{/*
Shared environment variables for both replication manager and view syncer.
This renders env: entries for database connections, app config, and secrets.
*/}}
{{- define "zero.sharedEnv" -}}
- name: ZERO_UPSTREAM_DB
  valueFrom:
    secretKeyRef:
      name: {{ include "zero.databaseSecretName" . }}
      key: ZERO_UPSTREAM_DB
{{- if or .Values.database.cvrDb .Values.existingSecrets.database }}
- name: ZERO_CVR_DB
  valueFrom:
    secretKeyRef:
      name: {{ include "zero.databaseSecretName" . }}
      key: ZERO_CVR_DB
      optional: true
{{- end }}
{{- if or .Values.database.changeDb .Values.existingSecrets.database }}
- name: ZERO_CHANGE_DB
  valueFrom:
    secretKeyRef:
      name: {{ include "zero.databaseSecretName" . }}
      key: ZERO_CHANGE_DB
      optional: true
{{- end }}
{{- if or .Values.adminPassword .Values.existingSecrets.admin }}
- name: ZERO_ADMIN_PASSWORD
  valueFrom:
    secretKeyRef:
      name: {{ include "zero.adminSecretName" . }}
      key: ZERO_ADMIN_PASSWORD
{{- end }}
{{- if or .Values.zero.authSecret .Values.existingSecrets.auth }}
- name: ZERO_AUTH_SECRET
  valueFrom:
    secretKeyRef:
      name: {{ include "zero.authSecretName" . }}
      key: ZERO_AUTH_SECRET
{{- end }}
{{- if or .Values.litestream.aws.accessKeyId .Values.existingSecrets.aws }}
- name: AWS_ACCESS_KEY_ID
  valueFrom:
    secretKeyRef:
      name: {{ include "zero.awsSecretName" . }}
      key: AWS_ACCESS_KEY_ID
{{- end }}
{{- if or .Values.litestream.aws.secretAccessKey .Values.existingSecrets.aws }}
- name: AWS_SECRET_ACCESS_KEY
  valueFrom:
    secretKeyRef:
      name: {{ include "zero.awsSecretName" . }}
      key: AWS_SECRET_ACCESS_KEY
{{- end }}
{{- if .Values.zero.appId }}
- name: ZERO_APP_ID
  value: {{ .Values.zero.appId | quote }}
{{- end }}
{{- if .Values.zero.logLevel }}
- name: ZERO_LOG_LEVEL
  value: {{ .Values.zero.logLevel | quote }}
{{- end }}
{{- if .Values.zero.logFormat }}
- name: ZERO_LOG_FORMAT
  value: {{ .Values.zero.logFormat | quote }}
{{- end }}
{{- if .Values.zero.autoReset }}
- name: ZERO_AUTO_RESET
  value: {{ .Values.zero.autoReset | quote }}
{{- end }}
{{- if .Values.zero.queryUrl }}
- name: ZERO_QUERY_URL
  value: {{ .Values.zero.queryUrl | quote }}
{{- end }}
{{- if .Values.zero.mutateUrl }}
- name: ZERO_MUTATE_URL
  value: {{ .Values.zero.mutateUrl | quote }}
{{- end }}
{{- if .Values.zero.queryApiKey }}
- name: ZERO_QUERY_API_KEY
  value: {{ .Values.zero.queryApiKey | quote }}
{{- end }}
{{- if .Values.zero.mutateApiKey }}
- name: ZERO_MUTATE_API_KEY
  value: {{ .Values.zero.mutateApiKey | quote }}
{{- end }}
{{- if .Values.zero.websocketCompression }}
- name: ZERO_WEBSOCKET_COMPRESSION
  value: {{ .Values.zero.websocketCompression | quote }}
{{- end }}
{{- if .Values.zero.nodeEnv }}
- name: NODE_ENV
  value: {{ .Values.zero.nodeEnv | quote }}
{{- end }}
{{- if .Values.litestream.backupUrl }}
- name: ZERO_LITESTREAM_BACKUP_URL
  value: {{ .Values.litestream.backupUrl | quote }}
{{- end }}
{{- if .Values.litestream.endpoint }}
- name: ZERO_LITESTREAM_ENDPOINT
  value: {{ .Values.litestream.endpoint | quote }}
{{- end }}
{{- if .Values.database.upstreamMaxConns }}
- name: ZERO_UPSTREAM_MAX_CONNS
  value: {{ .Values.database.upstreamMaxConns | quote }}
{{- end }}
{{- if .Values.database.cvrMaxConns }}
- name: ZERO_CVR_MAX_CONNS
  value: {{ .Values.database.cvrMaxConns | quote }}
{{- end }}
{{- if .Values.database.changeMaxConns }}
- name: ZERO_CHANGE_MAX_CONNS
  value: {{ .Values.database.changeMaxConns | quote }}
{{- end }}
{{- end }}
