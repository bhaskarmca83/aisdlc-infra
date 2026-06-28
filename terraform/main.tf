terraform {
  required_version = ">= 1.6.0"
  required_providers {
    aws = {
      source  = "hashicorp/aws"
      version = "~> 5.0"
    }
  }
  backend "s3" {}
}

provider "aws" {
  region = var.aws_region
  default_tags {
    tags = {
      Project     = "aisdlc"
      Environment = var.environment
      ManagedBy   = "terraform"
    }
  }
}

data "aws_availability_zones" "available" {}

# ─── VPC ──────────────────────────────────────────────────────────────────────

module "vpc" {
  source  = "terraform-aws-modules/vpc/aws"
  version = "~> 5.0"

  name            = "aisdlc-${var.environment}"
  cidr            = var.vpc_cidr
  azs             = slice(data.aws_availability_zones.available.names, 0, 2)
  private_subnets = ["10.0.1.0/24", "10.0.2.0/24"]
  public_subnets  = ["10.0.101.0/24", "10.0.102.0/24"]

  enable_nat_gateway   = true
  single_nat_gateway   = var.environment != "prod"
  enable_dns_hostnames = true

  private_subnet_tags = { "kubernetes.io/role/internal-elb" = 1 }
  public_subnet_tags  = { "kubernetes.io/role/elb"          = 1 }
}

# ─── EKS ──────────────────────────────────────────────────────────────────────

module "eks" {
  source = "./modules/eks"

  cluster_name      = "aisdlc-${var.environment}"
  vpc_id            = module.vpc.vpc_id
  subnet_ids        = module.vpc.private_subnet_ids
  instance_type     = var.eks_instance_type
  desired_size      = var.eks_desired_size
  min_size          = var.eks_min_size
  max_size          = var.eks_max_size
  environment       = var.environment
}

# ─── RDS (Aurora PostgreSQL Serverless v2) ────────────────────────────────────

module "rds" {
  source = "./modules/rds"

  cluster_identifier = "aisdlc-${var.environment}"
  vpc_id             = module.vpc.vpc_id
  subnet_ids         = module.vpc.private_subnet_ids
  min_capacity       = var.rds_min_capacity
  max_capacity       = var.rds_max_capacity
  environment        = var.environment
}

# ─── Redis (ElastiCache Serverless) ───────────────────────────────────────────

module "redis" {
  source = "./modules/redis"

  name       = "aisdlc-${var.environment}"
  vpc_id     = module.vpc.vpc_id
  subnet_ids = module.vpc.private_subnet_ids
  environment = var.environment
}

# ─── Frontend (S3 + CloudFront) ───────────────────────────────────────────────

module "frontend" {
  source = "./modules/frontend"

  bucket_name  = "aisdlc-frontend-${var.environment}"
  domain_name  = var.domain_name
  environment  = var.environment
}
