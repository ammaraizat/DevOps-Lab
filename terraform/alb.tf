# alb.tf - the public front door (Application Load Balancer) + firewalls.
#
# Security groups are virtual firewalls. The design here is the important
# part to learn:
#   - ALB security group: allow HTTP from anyone (the public internet).
#   - Task security group: allow traffic ONLY from the ALB, nothing else.
# This means the containers are never directly reachable from outside.

# ---- Security group for the ALB ----
resource "aws_security_group" "alb" {
  name        = "${var.app_name}-alb-sg"
  description = "Allow inbound HTTP from the internet to the ALB"
  vpc_id      = aws_vpc.main.id

  ingress {
    description = "HTTP from anywhere"
    from_port   = 80
    to_port     = 80
    protocol    = "tcp"
    cidr_blocks = ["0.0.0.0/0"]
  }

  egress {
    description = "Allow all outbound"
    from_port   = 0
    to_port     = 0
    protocol    = "-1"
    cidr_blocks = ["0.0.0.0/0"]
  }

  tags = { Name = "${var.app_name}-alb-sg" }
}

# ---- Security group for the ECS tasks ----
resource "aws_security_group" "tasks" {
  name        = "${var.app_name}-tasks-sg"
  description = "Allow inbound only from the ALB on the container port"
  vpc_id      = aws_vpc.main.id

  ingress {
    description     = "Container port, only from the ALB"
    from_port       = var.container_port
    to_port         = var.container_port
    protocol        = "tcp"
    security_groups = [aws_security_group.alb.id] # source = the ALB SG
  }

  egress {
    description = "Allow all outbound (to pull images, reach AWS APIs)"
    from_port   = 0
    to_port     = 0
    protocol    = "-1"
    cidr_blocks = ["0.0.0.0/0"]
  }

  tags = { Name = "${var.app_name}-tasks-sg" }
}

# ---- The load balancer itself ----
resource "aws_lb" "main" {
  name               = "${var.app_name}-alb"
  internal           = false # internet-facing
  load_balancer_type = "application"
  security_groups    = [aws_security_group.alb.id]
  subnets            = aws_subnet.public[*].id # lives in the public subnets
}

# ---- Target group: where the ALB sends traffic (our tasks) ----
resource "aws_lb_target_group" "app" {
  name        = "${var.app_name}-tg"
  port        = var.container_port
  protocol    = "HTTP"
  vpc_id      = aws_vpc.main.id
  target_type = "ip" # Fargate tasks register by IP, not instance

  # The health check: the ALB polls /health. Only tasks that return a
  # 200 here receive traffic. This is what makes deploys safe.
  health_check {
    path                = var.health_check_path
    port                = "traffic-port"
    healthy_threshold   = 2
    unhealthy_threshold = 3
    timeout             = 5
    interval            = 30
    matcher             = "200"
  }
}

# ---- Listener: the ALB listens on port 80 and forwards to the group ----
resource "aws_lb_listener" "http" {
  load_balancer_arn = aws_lb.main.arn
  port              = 80
  protocol          = "HTTP"

  default_action {
    type             = "forward"
    target_group_arn = aws_lb_target_group.app.arn
  }

  # NOTE: this lab uses plain HTTP on port 80 for simplicity. In
  # production you'd add an HTTPS (443) listener with an ACM certificate
  # and redirect 80 -> 443.
}
