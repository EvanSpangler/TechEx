# WIZ-005: Kubernetes Secrets Exposure

## Overview

| Attribute | Value |
|-----------|-------|
| **ID** | WIZ-005 |
| **Severity** | High |
| **CVSS** | 7.5 |
| **Component** | Kubernetes Secrets |
| **MITRE ATT&CK** | T1552.007 - Unsecured Credentials: Container API |

## Description

Kubernetes secrets are stored as base64-encoded values (not encrypted) and are accessible to any entity with appropriate RBAC permissions. Combined with the overprivileged ServiceAccount (WIZ-004), this allows trivial credential theft.

## Vulnerable Configuration

```yaml
# k8s/secrets.yaml

apiVersion: v1
kind: Secret
metadata:
  name: mongodb-credentials
  namespace: tasky
type: Opaque
stringData:
  MONGODB_URI: "mongodb://tasky:password@mongodb.example.com:27017/tasky"
  SECRET_KEY: "super-secret-jwt-key-12345"
```

Once applied, secrets are base64 encoded:

```yaml
apiVersion: v1
kind: Secret
metadata:
  name: mongodb-credentials
  namespace: tasky
type: Opaque
data:
  # Just base64, NOT encrypted!
  MONGODB_URI: bW9uZ29kYjovL3Rhc2t5OnBhc3N3b3JkQG1vbmdvZGIuZXhhbXBsZS5jb206MjcwMTcvdGFza3k=
  SECRET_KEY: c3VwZXItc2VjcmV0LWp3dC1rZXktMTIzNDU=
```

## Exploitation

### Prerequisites
- kubectl access to cluster
- Or: RBAC permissions to read secrets

### Steps

1. **List secrets in namespace**
   ```bash
   kubectl get secrets -n tasky
   ```
   Output:
   ```
   NAME                  TYPE     DATA   AGE
   mongodb-credentials   Opaque   2      1d
   ```

2. **View secret details**
   ```bash
   kubectl get secret mongodb-credentials -n tasky -o yaml
   ```

3. **Decode secret values**
   ```bash
   # MongoDB URI
   kubectl get secret mongodb-credentials -n tasky \
     -o jsonpath='{.data.MONGODB_URI}' | base64 -d

   # JWT Secret
   kubectl get secret mongodb-credentials -n tasky \
     -o jsonpath='{.data.SECRET_KEY}' | base64 -d
   ```

4. **One-liner extraction**
   ```bash
   kubectl get secret mongodb-credentials -n tasky -o json | \
     jq -r '.data | to_entries[] | "\(.key): \(.value | @base64d)"'
   ```

### Demo

```bash
make demo-secrets
```

Output:
```
[VULNERABILITY] Secrets stored as base64 (not encrypted)

Secrets in tasky namespace:
NAME                  TYPE     DATA   AGE
mongodb-credentials   Opaque   2      1d

Decoded MongoDB URI:
mongodb://tasky:SecureAppPassword@10.0.1.50:27017/tasky

Decoded JWT Secret:
jwt-secret-wiz-exercise-2024
```

## Impact

### Exposed Credentials
- MongoDB connection string with password
- JWT signing key
- Any other secrets in cluster

### Attack Paths

```mermaid
flowchart TB
    A[kubectl Access] --> B[List Secrets]
    B --> C[Get Secret YAML]
    C --> D[Base64 Decode]
    D --> E[Plain Text Credentials]

    E --> F[MongoDB Access]
    E --> G[JWT Forgery]
    E --> H[API Impersonation]
```

### Business Impact
- **Confidentiality**: High - credentials exposed
- **Integrity**: Medium - can forge auth tokens
- **Availability**: Low - direct impact minimal

## Detection

### Kubernetes Audit Logs

Monitor secret access:

```json
{
  "kind": "Event",
  "apiVersion": "audit.k8s.io/v1",
  "verb": "get",
  "user": {
    "username": "admin",
    "groups": ["system:masters"]
  },
  "objectRef": {
    "resource": "secrets",
    "namespace": "tasky",
    "name": "mongodb-credentials"
  }
}
```

### CloudWatch Logs Query

```sql
fields @timestamp, user.username, verb, objectRef.resource, objectRef.name
| filter verb in ['get', 'list', 'watch']
| filter objectRef.resource = 'secrets'
| filter user.username not like /system:/
| sort @timestamp desc
```

### Alert Rule

```yaml
# Prometheus AlertManager
groups:
- name: kubernetes-secrets
  rules:
  - alert: SecretAccessedByUnknownUser
    expr: |
      sum(increase(apiserver_request_total{
        resource="secrets",
        verb=~"get|list",
        user!~"system:.*"
      }[5m])) > 0
    for: 1m
    labels:
      severity: warning
```

## Remediation

### Option 1: AWS Secrets Manager + External Secrets

Use External Secrets Operator to sync from AWS:

```yaml
# Install External Secrets Operator
# helm install external-secrets external-secrets/external-secrets

apiVersion: external-secrets.io/v1beta1
kind: SecretStore
metadata:
  name: aws-secrets
  namespace: tasky
spec:
  provider:
    aws:
      service: SecretsManager
      region: us-east-1
      auth:
        jwt:
          serviceAccountRef:
            name: external-secrets-sa

---
apiVersion: external-secrets.io/v1beta1
kind: ExternalSecret
metadata:
  name: mongodb-credentials
  namespace: tasky
spec:
  refreshInterval: 1h
  secretStoreRef:
    name: aws-secrets
    kind: SecretStore
  target:
    name: mongodb-credentials
  data:
  - secretKey: MONGODB_URI
    remoteRef:
      key: tasky/mongodb
      property: uri
  - secretKey: SECRET_KEY
    remoteRef:
      key: tasky/jwt
      property: secret
```

### Option 2: Sealed Secrets

Encrypt secrets before committing to git:

```bash
# Install Sealed Secrets controller
kubectl apply -f https://github.com/bitnami-labs/sealed-secrets/releases/download/v0.24.0/controller.yaml

# Seal the secret
kubeseal --format yaml < secret.yaml > sealed-secret.yaml
```

```yaml
apiVersion: bitnami.com/v1alpha1
kind: SealedSecret
metadata:
  name: mongodb-credentials
  namespace: tasky
spec:
  encryptedData:
    MONGODB_URI: AgBy8hCi...encrypted...
    SECRET_KEY: AgCtr4mP...encrypted...
```

### Option 3: HashiCorp Vault

Inject secrets at runtime:

```yaml
apiVersion: v1
kind: Pod
metadata:
  name: tasky
  annotations:
    vault.hashicorp.com/agent-inject: "true"
    vault.hashicorp.com/role: "tasky"
    vault.hashicorp.com/agent-inject-secret-mongodb: "secret/data/tasky/mongodb"
spec:
  serviceAccountName: tasky-sa
  containers:
  - name: tasky
    image: tasky:latest
    # Secret injected to /vault/secrets/mongodb
```

### Option 4: Encrypt etcd

Enable etcd encryption at rest:

```yaml
# EKS: Enable secrets encryption
resource "aws_eks_cluster" "main" {
  encryption_config {
    provider {
      key_arn = aws_kms_key.eks.arn
    }
    resources = ["secrets"]
  }
}
```

### RBAC Restrictions

Limit who can read secrets:

```yaml
apiVersion: rbac.authorization.k8s.io/v1
kind: Role
metadata:
  name: secret-reader
  namespace: tasky
rules:
- apiGroups: [""]
  resources: ["secrets"]
  resourceNames: ["mongodb-credentials"]  # Specific secret only
  verbs: ["get"]  # No list
```

## Best Practices

1. **Never commit secrets to git** - Use sealed secrets or external management
2. **Rotate regularly** - Automate credential rotation
3. **Audit access** - Monitor who reads secrets
4. **Encrypt at rest** - Enable etcd encryption
5. **Use IRSA** - AWS IAM instead of K8s secrets where possible
6. **Minimal RBAC** - Only grant secret access where needed

## References

- [Kubernetes Secrets](https://kubernetes.io/docs/concepts/configuration/secret/)
- [External Secrets Operator](https://external-secrets.io/)
- [Sealed Secrets](https://github.com/bitnami-labs/sealed-secrets)
- [AWS Secrets Manager](https://docs.aws.amazon.com/secretsmanager/)
- [MITRE ATT&CK T1552.007](https://attack.mitre.org/techniques/T1552/007/)
