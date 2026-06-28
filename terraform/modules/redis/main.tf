resource "aws_security_group" "redis" {
  name   = "${var.name}-redis-sg"
  vpc_id = var.vpc_id

  ingress {
    from_port   = 6379
    to_port     = 6379
    protocol    = "tcp"
    cidr_blocks = ["10.0.0.0/16"]
  }
  egress {
    from_port   = 0
    to_port     = 0
    protocol    = "-1"
    cidr_blocks = ["0.0.0.0/0"]
  }
}

resource "aws_elasticache_subnet_group" "this" {
  name       = "${var.name}-redis-subnet-group"
  subnet_ids = var.subnet_ids
}

resource "aws_elasticache_serverless_cache" "this" {
  engine             = "redis"
  name               = var.name
  subnet_ids         = var.subnet_ids
  security_group_ids = [aws_security_group.redis.id]

  cache_usage_limits {
    data_storage {
      maximum = var.environment == "prod" ? 100 : 10
      unit    = "GB"
    }
    ecpu_per_second {
      maximum = var.environment == "prod" ? 5000 : 1000
    }
  }

  tags = { Environment = var.environment }
}
