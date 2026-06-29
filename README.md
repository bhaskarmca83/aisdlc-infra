# aisdlc-infra

Terraform modules and Helm charts for the AI SDLC Orchestration Platform on AWS. Manages all infrastructure across dev, staging, and production environments. CI/CD via GitHub Actions with environment-gated approvals.

---

## Platform Context

```
┌──────────────────────────────────────────────────────────────────┐
│                        AI SDLC Platform                          │
│                                                                  │
│  ┌─────────────────┐   ┌─────────────────┐  ┌────────────────┐  │
│  │  aisdlc-        │   │  aisdlc-        │  │  aisdlc-       │  │
│  │  frontend       │   │  orchestrator   │  │  backend       │  │
│  │  React SPA      │   │  LangGraph      │  │  Spring Boot   │  │
│  └────────┬────────┘   └────────┬────────┘  └───────┬────────┘  │
│           │                     │                   │           │
│  ┌────────▼─────────────────────▼───────────────────▼────────┐  │
│  │                  aisdlc-infra  ★ THIS REPO                │  │
│  │                                                           │  │
│  │  S3 + CloudFront    ECS Fargate    EKS           ECS      │  │
│  │  (React static)     (FastAPI CP)   (LangGraph)   (Spring) │  │
│  │                                                           │  │
│  │  ElastiCache Redis       RDS Aurora PostgreSQL + pgvector │  │
│  │  Secrets Manager         Route 53 / ACM / VPC            │  │
│  └───────────────────────────────────────────────────────────┘  │
└──────────────────────────────────────────────────────────────────┘
```

---

## AWS Architecture

```
Internet
   │
   ▼
CloudFront ──── S3 (aisdlc-frontend static build)
   │
   ▼
ALB (HTTPS :443)
   ├── /api/*  ──── ECS Fargate (aisdlc-orchestrator FastAPI)
   │                    │
   │              ElastiCache Redis (event streams, state checkpoints)
   │              RDS Aurora PostgreSQL 16 + pgvector (RAG, patterns)
   │
   └── workers ─── EKS (LangGraph agent workers, long-running tasks)

Secrets Manager  ──── all credentials (Atlassian, GitHub, LLM keys)
IAM roles        ──── IRSA for EKS pods, task roles for ECS
Route 53         ──── internal DNS for service-to-service calls
VPC              ──── private subnets for ECS, EKS, RDS, Redis
                      public subnets for ALB and NAT gateway only
```

---

## Terraform Modules

```
terraform/
├── main.tf              Root module — wires all modules together
├── variables.tf         Input variable declarations
├── outputs.tf           Exported values (ALB DNS, CloudFront URL, etc.)
├── backend.hcl          S3 remote state config (gitignored values)
├── envs/
│   ├── dev.tfvars       Development overrides
│   ├── staging.tfvars   Staging overrides
│   └── prod.tfvars      Production overrides
└── modules/
    ├── eks/             EKS cluster, node groups, IRSA roles
    ├── rds/             Aurora Serverless v2 PostgreSQL + pgvector extension
    ├── redis/           ElastiCache Serverless Redis 7
    └── frontend/        S3 bucket, CloudFront distribution, OAC policy
```

| Module | Resources |
|---|---|
| `eks` | EKS cluster, managed node group, OIDC provider, pod IAM roles |
| `rds` | Aurora Serverless v2 cluster, parameter group (`pgvector` extension enabled), subnet group, security group |
| `redis` | ElastiCache Serverless cluster, subnet group, security group, TLS enforced |
| `frontend` | S3 bucket (versioned, private), CloudFront distribution, Origin Access Control, custom error page for SPA routing |

---

## Helm Chart

```
helm/aisdlc-orchestrator/
├── Chart.yaml               name: aisdlc-orchestrator, version: 1.0.0
├── values.yaml              Default values (image, replicas, resources)
├── values-dev.yaml          Dev overrides
├── values-staging.yaml      Staging overrides
├── values-prod.yaml         Production overrides (HA, higher limits)
└── templates/               Kubernetes manifests (Deployment, Service,
                             HPA, ConfigMap, ServiceAccount, Ingress)
```

The Helm chart deploys the FastAPI orchestrator as an ECS/Kubernetes workload. Secrets are injected from AWS Secrets Manager via the Secrets Store CSI driver — no secrets in values files.

---

## Environments

| Environment | Account | Auto-deploy | Approval |
|---|---|---|---|
| `dev` | dev AWS account | On merge to `main` (infra paths) | None |
| `staging` | staging AWS account | On merge to `main` (infra paths) | 1 approver (GitHub environment protection) |
| `prod` | prod AWS account | On merge to `main` (infra paths) | 2 approvers (GitHub environment protection) |

Environment sizing:

| Resource | Dev | Staging | Prod |
|---|---|---|---|
| EKS nodes | 1 × m5.large | 2 × m5.large | 3 × m5.xlarge |
| RDS capacity | 0.5–2 ACU | 1–4 ACU | 2–16 ACU |
| Redis | Serverless (min) | Serverless (mid) | Serverless (HA) |

---

## CI/CD Pipelines

Three GitHub Actions workflows, one per environment:

| Workflow | File | Trigger | AWS Auth |
|---|---|---|---|
| Terraform Apply — Dev | `terraform-apply-dev.yml` | Push to `main`, `terraform/**` changed | OIDC → `AWS_ROLE_ARN` secret |
| Terraform Apply — Staging | `terraform-apply-staging.yml` | Same trigger | OIDC → staging role, requires 1 approval |
| Terraform Apply — Prod | `terraform-apply-prod.yml` | Same trigger | OIDC → prod role, requires 2 approvals |

All workflows use:
- `aws-actions/configure-aws-credentials@v4` with OIDC (no long-lived keys stored in GitHub)
- `hashicorp/setup-terraform@v3` pinned to Terraform 1.9.0
- `terraform init -backend-config=backend.hcl` then `terraform apply -var-file=envs/{env}.tfvars`

---

## Local / First-Time Setup

**Prerequisites:** Terraform 1.9+, AWS CLI configured, kubectl, Helm 3

```bash
# 1. Configure remote state backend
# Edit backend.hcl with your S3 bucket name and DynamoDB lock table

# 2. Initialise
cd terraform
terraform init -backend-config=../backend.hcl

# 3. Plan against dev
terraform plan -var-file=envs/dev.tfvars

# 4. Apply
terraform apply -var-file=envs/dev.tfvars
```

After apply, configure kubectl:
```bash
aws eks update-kubeconfig --region us-east-1 --name aisdlc-eks-dev
```

Deploy the Helm chart:
```bash
helm upgrade --install aisdlc-orchestrator helm/aisdlc-orchestrator \
  -f helm/aisdlc-orchestrator/values-dev.yaml \
  --namespace aisdlc --create-namespace
```

---

## Secrets Management

All credentials are stored in AWS Secrets Manager, not in Terraform state or Helm values. The secrets are:

| Secret name | Contents |
|---|---|
| `aisdlc/{env}/atlassian` | `JIRA_EMAIL`, `JIRA_API_TOKEN`, `JIRA_CLOUD_ID`, `CONFLUENCE_*` |
| `aisdlc/{env}/github` | `GITHUB_TOKEN`, `GITHUB_OWNER` |
| `aisdlc/{env}/llm` | `ANTHROPIC_API_KEY` (or Bedrock role ARN) |
| `aisdlc/{env}/db` | `POSTGRES_URL`, `POSTGRES_USER`, `POSTGRES_PASSWORD` |

ECS task roles and EKS pod IRSA roles have `secretsmanager:GetSecretValue` permission scoped to `aisdlc/{env}/*`.

**Never commit credentials to Terraform vars files.** Use `TF_VAR_` environment variables or Secrets Manager references for any sensitive input.

---

## Key Architectural Decisions

**Why ECS Fargate for the FastAPI control plane?** The orchestrator is latency-sensitive (users poll status and stream events). Fargate gives predictable cold-start and easy horizontal scaling without node management. EKS is reserved for LangGraph workers which are long-running and benefit from Kubernetes job scheduling.

**Why Aurora Serverless v2 + pgvector?** The platform's RAG memory store requires vector similarity search. pgvector on Aurora gives this without running a separate vector database. Serverless v2 scales to zero in dev, eliminating idle cost.

**Why ElastiCache Serverless for Redis?** Redis Streams (event fan-out to WebSocket clients) and LangGraph checkpoints require low-latency reads. ElastiCache Serverless removes cluster sizing decisions and scales automatically.

**Why OIDC for CI/CD auth?** Long-lived AWS access keys in GitHub Actions are a persistent credential leak risk. OIDC federation issues short-lived tokens scoped to the specific workflow run — no secrets to rotate.

**Why separate tfvars per environment instead of workspaces?** Workspaces share backend configuration and make it easy to accidentally apply the wrong environment. Separate var files with separate state paths make environment isolation explicit and auditable.

---

## Confluence / Jira Reference

- Platform TSD: `https://bhaskarwork.atlassian.net/wiki/spaces/SD`
- Jira platform epics: `CTS-129` through `CTS-132`
