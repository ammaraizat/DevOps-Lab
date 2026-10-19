# versions.tf - pin Terraform and provider versions.
#
# Pinning versions makes your infrastructure reproducible: the same
# config produces the same result months later, instead of silently
# changing when a new provider version is released.

terraform {
  required_version = ">= 1.5.0"

  required_providers {
    aws = {
      source  = "hashicorp/aws"
      version = "~> 5.0"
    }
  }

  # For a real team, store state remotely (e.g. an S3 bucket + DynamoDB
  # lock) so everyone shares one source of truth. Left commented so this
  # lab works out of the box with local state.
  #
  # backend "s3" {
  #   bucket         = "my-terraform-state-bucket"
  #   key            = "devops-lab/terraform.tfstate"
  #   region         = "us-east-1"
  #   dynamodb_table = "terraform-locks"
  #   encrypt        = true
  # }
}

provider "aws" {
  region = var.aws_region

  # Tags applied to every resource this provider creates. Great for
  # cost tracking and for finding everything to delete later.
  default_tags {
    tags = {
      Project   = var.app_name
      ManagedBy = "Terraform"
      Env       = "lab"
    }
  }
}
