# iam.tf - the IAM roles ECS needs.
#
# Two roles, different jobs:
#   - execution role: used by the ECS AGENT to pull the image and ship
#     logs. (Infrastructure plumbing.)
#   - task role: used by YOUR APP CODE if it calls AWS APIs (S3, etc.).
#     Our app needs nothing, so its role has no policies attached.

# Trust policy: both roles are assumed by the ECS tasks service.
data "aws_iam_policy_document" "ecs_assume" {
  statement {
    actions = ["sts:AssumeRole"]
    principals {
      type        = "Service"
      identifiers = ["ecs-tasks.amazonaws.com"]
    }
  }
}

# ---- Execution role ----
resource "aws_iam_role" "task_execution" {
  name               = "${var.app_name}-task-execution"
  assume_role_policy = data.aws_iam_policy_document.ecs_assume.json
}

# AWS-managed policy granting exactly the ECR-pull + logs permissions
# an execution role needs. Using the managed policy = least effort,
# correct scope.
resource "aws_iam_role_policy_attachment" "task_execution" {
  role       = aws_iam_role.task_execution.name
  policy_arn = "arn:aws:iam::aws:policy/service-role/AmazonECSTaskExecutionRolePolicy"
}

# ---- Task role (app runtime identity) ----
resource "aws_iam_role" "task" {
  name               = "${var.app_name}-task"
  assume_role_policy = data.aws_iam_policy_document.ecs_assume.json
  # No policies attached: our app makes no AWS API calls. Add them here
  # later if the app needs to read S3, publish to SQS, etc.
}
