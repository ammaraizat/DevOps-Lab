# ecr.tf - the private Docker image registry + log storage.

# ECR repository: where the CI/CD pipeline pushes built images and
# where ECS pulls them from.
resource "aws_ecr_repository" "app" {
  name                 = var.app_name
  image_tag_mutability = "MUTABLE"

  # Scan images for known vulnerabilities on push. Good security hygiene.
  image_scanning_configuration {
    scan_on_push = true
  }

  # force_delete lets `terraform destroy` remove the repo even if it
  # still has images, which is convenient for a lab.
  force_delete = true
}

# A lifecycle policy to avoid unbounded image buildup (and storage cost):
# keep only the most recent 10 images.
resource "aws_ecr_lifecycle_policy" "app" {
  repository = aws_ecr_repository.app.name

  policy = jsonencode({
    rules = [{
      rulePriority = 1
      description  = "Keep last 10 images"
      selection = {
        tagStatus   = "any"
        countType   = "imageCountMoreThan"
        countNumber = 10
      }
      action = { type = "expire" }
    }]
  })
}

# CloudWatch log group: where container stdout/stderr lands so you can
# debug. retention_in_days keeps the lab cheap by auto-expiring logs.
resource "aws_cloudwatch_log_group" "app" {
  name              = "/ecs/${var.app_name}"
  retention_in_days = 7
}
