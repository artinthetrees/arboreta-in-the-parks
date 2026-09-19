terraform {
  # Specify the required Terraform CLI version
  required_version = "~> 1.15.0"
  required_providers {
    aws = {
      source  = "hashicorp/aws"
      version = "~> 6.0"
    }
  }
}

# Configure the default AWS Provider
provider "aws" {
  region = var.region
}

# An explicit provider alias strictly for CloudFront's ACM certificate
provider "aws" {
  alias  = "us_east_1"
  region = "us-east-1"
}
