# variables.tf - the knobs you can turn without editing the main config.
#
# Variables keep the configuration reusable. Change these in
# terraform.tfvars instead of hard-coding values across the files.

variable "aws_region" {
  description = "AWS region to deploy into."
  type        = string
  default     = "us-east-1"
}

variable "app_name" {
  description = "Base name used for all resources (cluster, repo, etc.)."
  type        = string
  default     = "devops-lab"
}

variable "container_port" {
  description = "Port the app listens on inside the container (gunicorn)."
  type        = number
  default     = 5000
}

variable "desired_count" {
  description = "How many copies (tasks) of the container to run."
  type        = number
  default     = 2
}

variable "cpu" {
  description = "Fargate CPU units for the task (256 = 0.25 vCPU)."
  type        = string
  default     = "256"
}

variable "memory" {
  description = "Fargate memory (MB) for the task."
  type        = string
  default     = "512"
}

variable "image_tag" {
  description = <<-EOT
    Image tag to deploy from ECR. On the very first apply the repo is
    empty, so we default to 'latest'. The CI/CD pipeline pushes real
    images; after that you can pass a specific commit SHA here.
  EOT
  type        = string
  default     = "latest"
}

variable "health_check_path" {
  description = "HTTP path the load balancer polls to check task health."
  type        = string
  default     = "/health"
}

variable "vpc_cidr" {
  description = "CIDR block for the VPC."
  type        = string
  default     = "10.0.0.0/16"
}
