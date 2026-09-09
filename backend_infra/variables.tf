variable "environment" { type = string }
variable "ec2_key_name" { type = string }
variable "ec2_instance_type" { type = string }

variable "region" {
  default = "us-east-2"
  type    = string
}

variable "domain_name" {
  default = "rooteddata.org"
  type    = string
}

variable "github_user_name" {
  default = "artinthetrees"
  type    = string
}

variable "subdomain_name" {
  default = "backend.rooteddata.org"
  type    = string
}


