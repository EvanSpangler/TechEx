# Data Flow

Understanding how data moves through the Wiz Technical Exercise infrastructure.

## Application Data Flow

### Normal Operation

```mermaid
sequenceDiagram
    participant User
    participant ALB as Load Balancer
    participant App as Tasky App
    participant DB as MongoDB
    participant S3 as S3 Backup

    User->>ALB: Create Todo
    ALB->>App: Forward Request
    App->>DB: Insert Document
    DB-->>App: Confirm
    App-->>ALB: Response
    ALB-->>User: Success

    Note over DB,S3: Daily Backup Job
    DB->>S3: Backup Data
```

### Data at Rest

| Location | Data Type | Encryption | Risk |
|----------|-----------|------------|------|
| MongoDB | Application data | Volume encryption | Medium |
| S3 Bucket | Backups | **None** | **Critical** |
| K8s Secrets | Credentials | **Base64 only** | **Critical** |
| SSM Parameters | SSH Keys | KMS | Low |

### Data in Transit

| Path | Protocol | Encryption | Risk |
|------|----------|------------|------|
| User → ALB | HTTPS | TLS 1.2+ | Low |
| ALB → App | HTTP | **None** | Medium |
| App → MongoDB | TCP | **None** | High |
| MongoDB → S3 | HTTPS | TLS | Low |

## Credential Flow

### Application Credentials

```mermaid
flowchart LR
    subgraph Deployment
        TF[Terraform] -->|Create| Secret[K8s Secret]
    end

    subgraph Runtime
        Secret -->|Mount| Pod[App Pod]
        Pod -->|Use| DB[(MongoDB)]
    end

    subgraph Vulnerability
        Attacker -->|kubectl get secret| Secret
        Attacker -->|base64 -d| Creds[Plain Credentials]
    end
```

### SSH Key Flow

```mermaid
flowchart LR
    TF[Terraform] -->|Generate| KeyPair[TLS Private Key]
    KeyPair -->|Store| SSM[SSM Parameter]
    KeyPair -->|Deploy| EC2[EC2 Instance]

    Admin -->|make ssh-keys| Fetch[Fetch from SSM]
    Fetch -->|Save| Local[keys/*.pem]
    Local -->|SSH| EC2
```

## Backup Data Flow

### Backup Process

```mermaid
sequenceDiagram
    participant Cron as Cron Job
    participant Mongo as MongoDB
    participant Script as Backup Script
    participant S3 as S3 Bucket

    Cron->>Script: Trigger (2 AM daily)
    Script->>Mongo: mongodump
    Mongo-->>Script: BSON files
    Script->>Script: tar + gzip
    alt Encryption Key Set
        Script->>Script: GPG Encrypt
    else No Encryption
        Note over Script: VULNERABILITY!
    end
    Script->>S3: aws s3 cp
    S3-->>Script: Upload complete
```

### Backup Vulnerability

```mermaid
flowchart TB
    subgraph "Secure Path"
        Backup1[Backup] -->|GPG| Encrypted[Encrypted]
        Encrypted -->|Upload| S3Secure[S3 Private]
    end

    subgraph "Vulnerable Path (Current)"
        Backup2[Backup] -->|No Encryption| Plain[Plaintext]
        Plain -->|Upload| S3Public[S3 PUBLIC]
        Attacker -->|No Auth| S3Public
        S3Public -->|Download| Attacker
    end
```

## Monitoring Data Flow

### Log Collection

```mermaid
flowchart LR
    subgraph Sources
        EC2[EC2 Syslog]
        K8s[K8s Logs]
        AWS[CloudTrail]
        VPC[Flow Logs]
    end

    subgraph Collection
        Agent[Wazuh Agent]
        Fluentd[Fluent Bit]
        CW[CloudWatch]
    end

    subgraph Analysis
        Wazuh[Wazuh Manager]
        GD[GuardDuty]
    end

    EC2 --> Agent
    Agent --> Wazuh
    K8s --> Fluentd
    Fluentd --> CW
    AWS --> CW
    AWS --> GD
    VPC --> CW
```

### Alert Flow

```mermaid
sequenceDiagram
    participant Source as Log Source
    participant Wazuh as Wazuh Manager
    participant Rules as Detection Rules
    participant Dashboard as Wazuh Dashboard
    participant Alert as Alert System

    Source->>Wazuh: Log Event
    Wazuh->>Rules: Evaluate
    alt Rule Match
        Rules->>Dashboard: Create Alert
        Rules->>Alert: Notify
    else No Match
        Rules->>Wazuh: Store Only
    end
```

## Attack Data Flow

### S3 Exfiltration

```mermaid
sequenceDiagram
    participant Attacker
    participant S3 as S3 Public Bucket
    participant GuardDuty

    Attacker->>S3: aws s3 ls (no auth)
    S3-->>Attacker: File listing
    Attacker->>S3: aws s3 cp backup.tar.gz
    S3-->>Attacker: Download complete
    Note over GuardDuty: Detection: UnauthorizedAccess
```

### Credential Theft via K8s

```mermaid
sequenceDiagram
    participant Attacker
    participant EKS as EKS API
    participant Secret as K8s Secret
    participant DB as MongoDB

    Attacker->>EKS: kubectl get secret
    Note over EKS: ServiceAccount has cluster-admin
    EKS-->>Attacker: Base64 encoded secret
    Attacker->>Attacker: base64 -d
    Attacker->>DB: Connect with stolen creds
    DB-->>Attacker: Full database access
```

### IMDS Exploitation

```mermaid
sequenceDiagram
    participant Attacker
    participant MongoDB as MongoDB VM
    participant IMDS as IMDS (169.254.169.254)
    participant AWS as AWS APIs

    Attacker->>MongoDB: SSH Access
    MongoDB->>IMDS: curl /latest/meta-data/iam/
    IMDS-->>MongoDB: Role name
    MongoDB->>IMDS: curl /security-credentials/role
    IMDS-->>MongoDB: Temporary credentials
    MongoDB->>AWS: API calls with stolen creds
    Note over AWS: Full EC2, S3, IAM access!
```

## Data Classification

### Sensitivity Levels

| Data | Classification | Current Protection | Required |
|------|---------------|-------------------|----------|
| User todos | Internal | Encryption at rest | Adequate |
| MongoDB creds | Secret | **Base64** | KMS/Vault |
| SSH keys | Secret | SSM + KMS | Adequate |
| Backups | Confidential | **None** | Encryption |
| AWS creds (IMDS) | Secret | **Exposed** | IMDSv2 |

### Data Residency

All data remains in `us-east-1`:

- MongoDB EBS volumes
- S3 bucket
- EKS persistent volumes
- CloudWatch logs
- SSM parameters

## Compliance Considerations

!!! warning "Not Compliant"
    This infrastructure violates multiple compliance frameworks intentionally:

### PCI DSS Violations

- Unencrypted cardholder data equivalent (credentials)
- Public access to data stores
- Missing access controls

### SOC 2 Violations

- Insufficient access controls
- Missing encryption
- Inadequate monitoring (detection only, no prevention)

### GDPR Violations

- No data protection by design
- Missing access logs for some paths
- No data minimization

## Remediation Data Flow

### Secure Architecture

```mermaid
flowchart TB
    subgraph "Secure Design"
        User -->|HTTPS| WAF[AWS WAF]
        WAF -->|Filter| ALB
        ALB -->|TLS| App
        App -->|TLS| DB[(MongoDB)]
        DB -->|Encrypted| S3[S3 Private]

        App -->|IAM Auth| Secrets[Secrets Manager]
        Secrets -->|Rotate| DB
    end
```

### Key Improvements

1. **Add WAF** - Filter malicious requests
2. **Enable TLS everywhere** - Encrypt in transit
3. **Use Secrets Manager** - Managed credential rotation
4. **Private S3** - Remove public access
5. **IMDSv2** - Require session tokens
6. **VPC Endpoints** - Keep traffic private
