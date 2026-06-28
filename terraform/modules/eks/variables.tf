variable "cluster_name"  { type = string }
variable "vpc_id"        { type = string }
variable "subnet_ids"    { type = list(string) }
variable "instance_type" { type = string; default = "m5.large" }
variable "desired_size"  { type = number; default = 1 }
variable "min_size"      { type = number; default = 1 }
variable "max_size"      { type = number; default = 5 }
variable "environment"   { type = string }
