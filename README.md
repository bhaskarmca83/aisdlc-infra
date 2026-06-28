# aisdlc-infra

Terraform + Helm infrastructure for the AI SDLC Orchestration Platform.

## Architecture
- EKS (LangGraph workers)
- ECS Fargate (FastAPI control plane)
- ElastiCache Redis (event streams + checkpoints)
- RDS Aurora PostgreSQL 16 + pgvector
- S3 + CloudFront (React dashboard)
- Secrets Manager (all credentials)

## Deploy
```bash
cd terraform
terraform init -backend-config=backend.hcl
terraform plan -var-file=envs/dev.tfvars
terraform apply -var-file=envs/dev.tfvars
```

## Environments
- `envs/dev.tfvars` — Development
- `envs/staging.tfvars` — Staging (manual approval)
- `envs/prod.tfvars` — Production (2 approvers, HA)