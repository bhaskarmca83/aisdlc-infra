output "eks_cluster_endpoint" {
  description = "EKS cluster API endpoint"
  value       = module.eks.cluster_endpoint
}

output "eks_cluster_name" {
  description = "EKS cluster name"
  value       = module.eks.cluster_name
}

output "rds_cluster_endpoint" {
  description = "Aurora PostgreSQL writer endpoint"
  value       = module.rds.cluster_endpoint
  sensitive   = true
}

output "redis_endpoint" {
  description = "ElastiCache Serverless endpoint"
  value       = module.redis.endpoint
  sensitive   = true
}

output "cloudfront_url" {
  description = "CloudFront distribution URL for the frontend"
  value       = module.frontend.cloudfront_url
}

output "frontend_bucket" {
  description = "S3 bucket name for frontend assets"
  value       = module.frontend.bucket_name
}
