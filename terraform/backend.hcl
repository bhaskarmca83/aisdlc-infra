bucket         = "aisdlc-terraform-state"
key            = "aisdlc/terraform.tfstate"
region         = "us-east-1"
encrypt        = true
dynamodb_table = "aisdlc-terraform-lock"
