# Zero Helm Chart

A Helm chart for deploying [Rocicorp Zero](https://zero.rocicorp.dev) sync engine to Kubernetes.

## Architecture

Zero consists of two components in a multi-node deployment:

- **Replication Manager** — A singleton StatefulSet that manages the upstream Postgres replication slot, maintains the SQLite replica, and backs it up to S3 via Litestream.
- **View Syncers** — Horizontally scalable workers that handle client WebSocket connections, restore their SQLite replica from S3, and pull change streams from the Replication Manager.

```
                    ┌─────────────────┐
                    │   PostgreSQL     │
                    │   (upstream)     │
                    └────────┬────────┘
                             │ replication
                    ┌────────▼────────┐
                    │   Replication    │
                    │    Manager       │───── S3 (Litestream backup)
                    │  (port 4849)    │
                    └────────┬────────┘
                             │ change stream
              ┌──────────────┼──────────────┐
              │              │              │
     ┌────────▼──────┐ ┌────▼───────┐ ┌────▼───────┐
     │  View Syncer  │ │ View Syncer│ │ View Syncer│
     │  (port 4848)  │ │ (port 4848)│ │ (port 4848)│
     └───────────────┘ └────────────┘ └────────────┘
              │              │              │
              └──────────────┼──────────────┘
                             │ WebSocket
                        ┌────▼────┐
                        │ Clients │
                        └─────────┘
```

The chart also supports **single-node mode** where one pod handles both replication and client serving.

## Prerequisites

- Kubernetes 1.23+
- Helm 3.x
- PostgreSQL database with `wal_level=logical`
- S3-compatible storage (required for multi-node mode)

## Installation

```bash
helm repo add zero https://web-tree.github.io/zero-helm
helm repo update
helm install zero zero/zero
```

## Quick Start

### Single-Node Mode

```bash
helm install zero zero/zero \
  --set viewSyncer.enabled=false \
  --set database.upstreamDb="postgresql://user:pass@postgres:5432/mydb" \
  --set adminPassword="your-admin-password"
```

### Multi-Node Mode

```bash
helm install zero zero/zero \
  --set database.upstreamDb="postgresql://user:pass@postgres:5432/mydb" \
  --set adminPassword="your-admin-password" \
  --set litestream.backupUrl="s3://my-bucket/zero-replica" \
  --set litestream.aws.accessKeyId="AKIAIOSFODNN7EXAMPLE" \
  --set litestream.aws.secretAccessKey="wJalrXUtnFEMI/K7MDENG/bPxRfiCYEXAMPLEKEY"
```

## Configuration

### Deployment Mode

| Parameter | Description | Default |
|-----------|-------------|---------|
| `viewSyncer.enabled` | Enable multi-node mode with separate view syncers | `true` |

When `viewSyncer.enabled=false`, the chart deploys a single combined pod.

### Image

| Parameter | Description | Default |
|-----------|-------------|---------|
| `image.repository` | Docker image repository | `rocicorp/zero` |
| `image.tag` | Image tag (defaults to Chart appVersion) | `""` |
| `image.pullPolicy` | Image pull policy | `IfNotPresent` |

### Database

| Parameter | Description | Default |
|-----------|-------------|---------|
| `database.upstreamDb` | Direct Postgres connection string (required, no pgbouncer) | `""` |
| `database.cvrDb` | CVR database connection string | `""` (uses upstreamDb) |
| `database.changeDb` | Change log database connection string | `""` (uses upstreamDb) |
| `database.upstreamMaxConns` | Max upstream connections | `""` |
| `database.cvrMaxConns` | Max CVR connections (default: 30) | `""` |
| `database.changeMaxConns` | Max change connections (default: 5) | `""` |

### Zero Configuration

| Parameter | Description | Default |
|-----------|-------------|---------|
| `zero.appId` | Unique app identifier | `""` |
| `zero.logLevel` | Log level (debug/info/warn/error) | `"info"` |
| `zero.logFormat` | Log format (text/json) | `"text"` |
| `zero.autoReset` | Auto wipe/resync on replication halt | `""` |
| `zero.authSecret` | Symmetric key for JWT verification | `""` |
| `zero.queryUrl` | Query API endpoint URL | `""` |
| `zero.mutateUrl` | Mutation API endpoint URL | `""` |
| `zero.nodeEnv` | Node environment | `"production"` |
| `adminPassword` | Admin password for /statz endpoint | `""` |

### Litestream / S3 Backup

Required for multi-node mode. View syncers restore their SQLite replica from this backup.

| Parameter | Description | Default |
|-----------|-------------|---------|
| `litestream.backupUrl` | S3 backup URL (e.g., `s3://bucket/path`) | `""` |
| `litestream.endpoint` | S3-compatible endpoint (for MinIO, etc.) | `""` |
| `litestream.aws.accessKeyId` | AWS access key ID | `""` |
| `litestream.aws.secretAccessKey` | AWS secret access key | `""` |

### Secret Management

The chart creates Kubernetes Secrets by default. To use existing secrets (e.g., from ExternalSecrets Operator, Sealed Secrets, or Vault):

| Parameter | Description | Expected Keys |
|-----------|-------------|---------------|
| `existingSecrets.database` | Existing database secret name | `ZERO_UPSTREAM_DB`, `ZERO_CVR_DB`, `ZERO_CHANGE_DB` |
| `existingSecrets.aws` | Existing AWS secret name | `AWS_ACCESS_KEY_ID`, `AWS_SECRET_ACCESS_KEY` |
| `existingSecrets.admin` | Existing admin secret name | `ZERO_ADMIN_PASSWORD` |
| `existingSecrets.auth` | Existing auth secret name | `ZERO_AUTH_SECRET` |

### Replication Manager

| Parameter | Description | Default |
|-----------|-------------|---------|
| `replicationManager.replicaFile` | SQLite replica path | `/data/replica.db` |
| `replicationManager.persistence.enabled` | Enable PVC | `true` |
| `replicationManager.persistence.size` | PVC size | `10Gi` |
| `replicationManager.persistence.storageClass` | Storage class | `""` |
| `replicationManager.service.port` | Change streamer port | `4849` |
| `replicationManager.resources` | Resource requests/limits | `{}` |
| `replicationManager.nodeSelector` | Node selector | `{}` |
| `replicationManager.tolerations` | Tolerations | `[]` |
| `replicationManager.affinity` | Affinity rules | `{}` |
| `replicationManager.podDisruptionBudget.enabled` | Enable PDB | `false` |

### View Syncer

| Parameter | Description | Default |
|-----------|-------------|---------|
| `viewSyncer.replicaCount` | Number of view syncer replicas | `2` |
| `viewSyncer.replicaFile` | SQLite replica path | `/data/zero.db` |
| `viewSyncer.numSyncWorkers` | Number of sync workers | `""` (auto) |
| `viewSyncer.yieldThresholdMs` | Yield threshold in ms | `""` |
| `viewSyncer.persistence.enabled` | Enable PVC (StatefulSet) vs emptyDir (Deployment) | `true` |
| `viewSyncer.persistence.size` | PVC size | `10Gi` |
| `viewSyncer.service.port` | Sync/WebSocket port | `4848` |
| `viewSyncer.autoscaling.enabled` | Enable HPA | `false` |
| `viewSyncer.autoscaling.minReplicas` | HPA min replicas | `2` |
| `viewSyncer.autoscaling.maxReplicas` | HPA max replicas | `10` |
| `viewSyncer.autoscaling.targetCPUUtilizationPercentage` | HPA CPU target | `70` |
| `viewSyncer.podDisruptionBudget.enabled` | Enable PDB | `true` |
| `viewSyncer.podDisruptionBudget.maxUnavailable` | Max unavailable pods | `1` |

### Ingress

| Parameter | Description | Default |
|-----------|-------------|---------|
| `ingress.enabled` | Enable ingress | `false` |
| `ingress.className` | Ingress class name | `""` |
| `ingress.annotations` | Ingress annotations | `{}` |
| `ingress.hosts` | Ingress hosts configuration | see values.yaml |
| `ingress.tls` | TLS configuration | `[]` |

#### Nginx WebSocket Configuration

Zero uses WebSockets for client connections. Example nginx ingress annotations:

```yaml
ingress:
  enabled: true
  className: nginx
  annotations:
    nginx.ingress.kubernetes.io/proxy-read-timeout: "3600"
    nginx.ingress.kubernetes.io/proxy-send-timeout: "3600"
    nginx.ingress.kubernetes.io/proxy-http-version: "1.1"
    nginx.ingress.kubernetes.io/upstream-hash-by: "$arg_clientID"
    nginx.ingress.kubernetes.io/configuration-snippet: |
      proxy_set_header Upgrade $http_upgrade;
      proxy_set_header Connection "upgrade";
```

### Extra Environment Variables

Pass any additional environment variables using:

```yaml
extraEnv:
  - name: ZERO_ENABLE_TELEMETRY
    value: "false"

extraEnvFrom:
  - secretRef:
      name: my-extra-secret
```

Component-specific extra env vars:

```yaml
replicationManager:
  extraEnv:
    - name: ZERO_LITESTREAM_SNAPSHOT_BACKUP_INTERVAL_HOURS
      value: "6"

viewSyncer:
  extraEnv:
    - name: ZERO_REPLICA_PAGE_CACHE_SIZE_KIB
      value: "65536"
```

## IRSA / Workload Identity

For AWS IRSA (IAM Roles for Service Accounts):

```yaml
serviceAccount:
  annotations:
    eks.amazonaws.com/role-arn: arn:aws:iam::123456789012:role/zero-s3-role

# Leave AWS credentials empty when using IRSA
litestream:
  backupUrl: "s3://my-bucket/zero-replica"
```

For GCP Workload Identity:

```yaml
serviceAccount:
  annotations:
    iam.gke.io/gcp-service-account: zero@my-project.iam.gserviceaccount.com
```

## References

- [Rocicorp Zero Documentation](https://zero.rocicorp.dev)
- [Deploying Zero](https://zero.rocicorp.dev/docs/deployment)
- [zero-cache Config Reference](https://zero.rocicorp.dev/docs/zero-cache-config)
- [Docker Image](https://hub.docker.com/r/rocicorp/zero)
