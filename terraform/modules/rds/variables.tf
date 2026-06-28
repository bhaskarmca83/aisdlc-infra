variable "cluster_identifier" { type = string }
variable "vpc_id"             { type = string }
variable "subnet_ids"         { type = list(string) }
variable "min_capacity"       { type = number; default = 0.5 }
variable "max_capacity"       { type = number; default = 4 }
variable "environment"        { type = string }
variable "db_name"            { type = string; default = "sdlc_db" }
variable "master_username"    { type = string; default = "sdlc" }
