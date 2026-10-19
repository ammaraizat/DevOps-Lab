# ecs.tf - the compute layer that actually runs our container.

# The ECS cluster: a logical home for our services and tasks.
resource "aws_ecs_cluster" "main" {
  name = "${var.app_name}-cluster"

  # Turn on Container Insights for extra CloudWatch metrics.
  setting {
    name  = "containerInsights"
    value = "enabled"
  }
}

# The task definition: the blueprint for one running copy of the app.
# This mirrors aws/task-definition.json, but defined as code so Terraform
# manages its full lifecycle.
resource "aws_ecs_task_definition" "app" {
  family                   = var.app_name
  requires_compatibilities = ["FARGATE"]
  network_mode             = "awsvpc"
  cpu                      = var.cpu
  memory                   = var.memory
  execution_role_arn       = aws_iam_role.task_execution.arn
  task_role_arn            = aws_iam_role.task.arn

  # The container definition is JSON; jsonencode keeps it readable and
  # lets us interpolate Terraform values (image URL, log group, port).
  container_definitions = jsonencode([
    {
      name      = "web"
      image     = "${aws_ecr_repository.app.repository_url}:${var.image_tag}"
      essential = true

      portMappings = [
        {
          containerPort = var.container_port
          protocol      = "tcp"
        }
      ]

      logConfiguration = {
        logDriver = "awslogs"
        options = {
          "awslogs-group"         = aws_cloudwatch_log_group.app.name
          "awslogs-region"        = var.aws_region
          "awslogs-stream-prefix" = "web"
        }
      }
    }
  ])
}

# The service: keeps `desired_count` tasks running and wires them to the
# load balancer. It also performs rolling deployments when the task
# definition changes.
resource "aws_ecs_service" "app" {
  name            = "${var.app_name}-service"
  cluster         = aws_ecs_cluster.main.id
  task_definition = aws_ecs_task_definition.app.arn
  desired_count   = var.desired_count
  launch_type     = "FARGATE"

  network_configuration {
    subnets          = aws_subnet.private[*].id        # tasks run private
    security_groups  = [aws_security_group.tasks.id]
    assign_public_ip = false                           # no public IPs
  }

  # Register tasks with the ALB target group so they receive traffic.
  load_balancer {
    target_group_arn = aws_lb_target_group.app.arn
    container_name   = "web"
    container_port   = var.container_port
  }

  # Don't start wiring the service until the ALB listener exists.
  depends_on = [aws_lb_listener.http]

  # The CI/CD pipeline updates the running image out-of-band. Ignoring
  # task_definition changes here prevents Terraform from fighting the
  # pipeline and reverting deploys. Terraform owns the infra; the
  # pipeline owns which image version is live.
  lifecycle {
    ignore_changes = [task_definition]
  }
}
