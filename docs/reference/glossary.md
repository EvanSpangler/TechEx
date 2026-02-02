# Glossary

This glossary defines key terms used throughout the Wiz Technical Exercise documentation.

## AWS Services

### ALB (Application Load Balancer)
An AWS load balancer that operates at Layer 7 (application layer), routing HTTP/HTTPS traffic to targets based on request content. In this project, the ALB routes traffic to the EKS cluster.

### CloudTrail
AWS service that records API calls and related events in your AWS account. Used for security auditing and operational troubleshooting. Records actions like S3 access, IAM changes, and EC2 operations.

### EBS (Elastic Block Store)
AWS block storage service for EC2 instances. Provides persistent storage volumes. The MongoDB VM uses an EBS volume for database storage.

### EC2 (Elastic Compute Cloud)
AWS virtual server service. This project uses EC2 instances for MongoDB, Wazuh, and the Red Team instance.

### ECR (Elastic Container Registry)
AWS managed container image registry. Stores the Tasky application Docker images for deployment to EKS.

### EKS (Elastic Kubernetes Service)
AWS managed Kubernetes service. Runs the Tasky application in this project without requiring manual cluster management.

### GuardDuty
AWS threat detection service that monitors for malicious activity and unauthorized behavior. Analyzes CloudTrail, VPC Flow Logs, and DNS logs.

### IAM (Identity and Access Management)
AWS service for managing access to AWS resources. Controls who can do what in your AWS account through users, groups, roles, and policies.

### IMDS (Instance Metadata Service)
Service available to EC2 instances that provides information about the instance, including temporary security credentials. Available at `169.254.169.254`.

#### IMDSv1 vs IMDSv2
- **IMDSv1**: Original version using simple HTTP GET requests. Vulnerable to SSRF attacks.
- **IMDSv2**: Session-based version requiring a token. More secure against SSRF.

### NAT Gateway
AWS service that allows instances in private subnets to access the internet while remaining unreachable from the internet.

### S3 (Simple Storage Service)
AWS object storage service. Used in this project for database backups (intentionally public for the demo).

### Security Group
Virtual firewall for EC2 instances controlling inbound and outbound traffic. Acts as instance-level firewall.

### Security Hub
AWS service that aggregates security findings from multiple sources (GuardDuty, Inspector, IAM Access Analyzer) into a unified view.

### SSM (Systems Manager)
AWS service for managing EC2 instances. Includes Session Manager for secure shell access without opening SSH ports.

### VPC (Virtual Private Cloud)
Isolated virtual network in AWS where you launch resources. Provides control over IP addressing, subnets, routing, and security.

### VPC Flow Logs
Capture information about IP traffic going to and from network interfaces in a VPC. Useful for network monitoring and security analysis.

---

## Kubernetes

### Cluster
A set of nodes (machines) running containerized applications managed by Kubernetes. Consists of a control plane and worker nodes.

### ClusterRole / ClusterRoleBinding
Kubernetes RBAC resources. ClusterRole defines permissions cluster-wide; ClusterRoleBinding grants those permissions to subjects.

### ConfigMap
Kubernetes resource for storing non-confidential configuration data as key-value pairs. Can be consumed by pods as environment variables or files.

### Deployment
Kubernetes resource that manages a set of identical pods, handling updates, scaling, and self-healing.

### Namespace
Virtual cluster within a Kubernetes cluster for organizing and isolating resources. The Tasky app runs in the `tasky` namespace.

### Pod
Smallest deployable unit in Kubernetes. One or more containers that share storage and network resources.

### RBAC (Role-Based Access Control)
Kubernetes authorization mechanism. Controls what actions users and service accounts can perform on which resources.

### Secret
Kubernetes resource for storing sensitive data (passwords, tokens, keys). Stored base64-encoded (not encrypted by default).

### Service
Kubernetes resource that exposes pods as a network service. Provides stable IP and DNS name for a set of pods.

### ServiceAccount
Kubernetes identity for processes running in pods. Used to authenticate to the Kubernetes API and other services.

---

## Security Terms

### Attack Chain
Sequence of steps an attacker takes to achieve their objective. Also called "kill chain." This project demonstrates a multi-step attack chain through intentional vulnerabilities.

### CVSS (Common Vulnerability Scoring System)
Standardized framework for rating vulnerability severity on a 0-10 scale.
- **Critical**: 9.0-10.0
- **High**: 7.0-8.9
- **Medium**: 4.0-6.9
- **Low**: 0.1-3.9

### CVE (Common Vulnerabilities and Exposures)
Standardized identifiers for publicly known security vulnerabilities. Format: CVE-YYYY-NNNNN.

### IMDS Exploitation
Attack technique where an attacker accesses the EC2 Instance Metadata Service to steal IAM credentials. Common via SSRF vulnerabilities.

### Lateral Movement
Technique where attackers move through a network after initial access, seeking additional systems and data.

### Least Privilege
Security principle where users/systems receive only the minimum permissions necessary to perform their function.

### MITRE ATT&CK
Knowledge base of adversary tactics and techniques based on real-world observations. Used to categorize attack methods.

### OWASP
Open Web Application Security Project. Provides security resources including the OWASP Top 10 list of web application risks.

### Privilege Escalation
Exploiting a vulnerability to gain elevated access (e.g., from user to root, from limited IAM to admin).

### SSRF (Server-Side Request Forgery)
Vulnerability where an attacker can make a server perform requests to unintended locations, often used to access internal resources like IMDS.

---

## Infrastructure as Code

### HCL (HashiCorp Configuration Language)
Configuration language used by Terraform for defining infrastructure.

### IaC (Infrastructure as Code)
Practice of managing infrastructure through code rather than manual processes. Enables version control, automation, and reproducibility.

### Module
Reusable Terraform configuration package. This project organizes infrastructure into modules (vpc, eks, mongodb-vm, etc.).

### State
Terraform's record of managed infrastructure. Stored in `terraform.tfstate`. Used to map configuration to real resources.

### tfvars
Terraform variable definition files. Used to provide values for input variables without modifying configuration.

---

## Application Terms

### API (Application Programming Interface)
Set of rules for how software components interact. The Tasky app provides a REST API for todo management.

### bcrypt
Password hashing algorithm designed to be slow and resistant to brute-force attacks. Used by Tasky for password storage.

### CRUD
Create, Read, Update, Delete - the four basic operations of persistent storage. The Tasky API provides CRUD operations for todos.

### Gin
High-performance HTTP web framework for Go. Used as the foundation for the Tasky application.

### JWT (JSON Web Token)
Compact, URL-safe token format for securely transmitting claims between parties. Used for authentication in Tasky.

### MongoDB
NoSQL document database. Stores data in JSON-like documents. Used as the database for Tasky.

### REST (Representational State Transfer)
Architectural style for web services using HTTP methods (GET, POST, PUT, DELETE) on resources identified by URLs.

---

## DevOps & CI/CD

### CI/CD (Continuous Integration/Continuous Deployment)
Practices of frequently integrating code changes (CI) and automatically deploying them (CD). Implemented via GitHub Actions in this project.

### Docker
Platform for building and running containers. Used to package the Tasky application.

### GitHub Actions
GitHub's built-in CI/CD platform. Runs workflows defined in YAML files on push, pull request, or other events.

### Pipeline
Automated sequence of stages for building, testing, and deploying software.

### SARIF (Static Analysis Results Interchange Format)
Standard format for static analysis tool output. Used to upload security scan results to GitHub.

---

## Security Tools

### Checkov
Open-source IaC static analysis tool. Scans Terraform, CloudFormation, and Kubernetes for misconfigurations.

### Grype
Open-source vulnerability scanner for container images and filesystems. Made by Anchore.

### tfsec
Static analysis tool specifically for Terraform code. Detects potential security issues in HCL configurations.

### Trivy
Comprehensive security scanner for containers, filesystems, git repositories, and Kubernetes.

### Wazuh
Open-source security monitoring platform. Provides threat detection, integrity monitoring, incident response, and compliance.

---

## Networking

### CIDR (Classless Inter-Domain Routing)
Notation for describing IP address ranges. Example: `10.0.0.0/16` represents 65,536 addresses.

### DNS (Domain Name System)
System that translates domain names to IP addresses.

### Ingress / Egress
- **Ingress**: Incoming network traffic
- **Egress**: Outgoing network traffic

### Private Subnet
Subnet without direct route to internet gateway. Instances can only access internet through NAT Gateway.

### Public Subnet
Subnet with route to internet gateway. Instances can have public IPs and be directly accessible from internet.

### Route Table
Set of rules (routes) determining where network traffic is directed in a VPC.

---

## Acronyms Quick Reference

| Acronym | Full Form |
|---------|-----------|
| ALB | Application Load Balancer |
| API | Application Programming Interface |
| AWS | Amazon Web Services |
| CI/CD | Continuous Integration/Continuous Deployment |
| CIDR | Classless Inter-Domain Routing |
| CLI | Command Line Interface |
| CVE | Common Vulnerabilities and Exposures |
| CVSS | Common Vulnerability Scoring System |
| DNS | Domain Name System |
| EBS | Elastic Block Store |
| EC2 | Elastic Compute Cloud |
| ECR | Elastic Container Registry |
| EKS | Elastic Kubernetes Service |
| HCL | HashiCorp Configuration Language |
| IAM | Identity and Access Management |
| IaC | Infrastructure as Code |
| IMDS | Instance Metadata Service |
| IRSA | IAM Roles for Service Accounts |
| JWT | JSON Web Token |
| K8s | Kubernetes |
| NAT | Network Address Translation |
| RBAC | Role-Based Access Control |
| REST | Representational State Transfer |
| RPO | Recovery Point Objective |
| RTO | Recovery Time Objective |
| S3 | Simple Storage Service |
| SARIF | Static Analysis Results Interchange Format |
| SCP | Service Control Policy |
| SIEM | Security Information and Event Management |
| SSH | Secure Shell |
| SSRF | Server-Side Request Forgery |
| SSM | Systems Manager |
| TLS | Transport Layer Security |
| VPC | Virtual Private Cloud |
