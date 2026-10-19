# outputs.tf - values printed after `terraform apply`.
#
# Outputs surface the things you (and the CI/CD pipeline) need: the URL
# to open, the registry to push to, and the names to configure in GitHub.

output "app_url" {
  description = "Public URL of the app (open this in your browser)."
  value       = "http://${aws_lb.main.dns_name}"
}

output "alb_dns_name" {
  description = "DNS name of the Application Load Balancer."
  value       = aws_lb.main.dns_name
}

output "ecr_repository_url" {
  description = "ECR repo URL to push images to (used by the pipeline)."
  value       = aws_ecr_repository.app.repository_url
}

output "ecs_cluster_name" {
  description = "ECS cluster name (set as the ECS_CLUSTER GitHub var)."
  value       = aws_ecs_cluster.main.name
}

output "ecs_service_name" {
  description = "ECS service name (set as the ECS_SERVICE GitHub var)."
  value       = aws_ecs_service.app.name
}

output "github_actions_variables" {
  description = "Copy these into GitHub repo Variables for the pipeline."
  value = {
    AWS_REGION         = var.aws_region
    ECR_REPOSITORY     = var.app_name
    ECS_CLUSTER        = aws_ecs_cluster.main.name
    ECS_SERVICE        = aws_ecs_service.app.name
    ECS_CONTAINER_NAME = "web"
  }
}
