
locals { name = var.app_name }

data "aws_caller_identity" "current" {}

data "aws_ecr_repository" "repo" { name = var.ecr_repo }
locals { image_uri = "${data.aws_ecr_repository.repo.repository_url}:${var.image_tag}" }

resource "aws_cloudwatch_log_group" "app" {
  name              = "/ecs/${local.name}"
  retention_in_days = 14
}

resource "aws_security_group" "alb" {
  name        = "${local.name}-alb-sg"
  description = "ALB SG"
  vpc_id      = var.vpc_id
  ingress { from_port = 80  to_port = 80  protocol = "tcp" cidr_blocks = ["0.0.0.0/0"] }
  ingress { from_port = 443 to_port = 443 protocol = "tcp" cidr_blocks = ["0.0.0.0/0"] }
  egress  { from_port = 0   to_port = 0   protocol = "-1"  cidr_blocks = ["0.0.0.0/0"] }
}

resource "aws_security_group" "svc" {
  name        = "${local.name}-svc-sg"
  description = "Service SG"
  vpc_id      = var.vpc_id
  ingress {
    description     = "ALB -> tasks (3000)"
    from_port       = 3000
    to_port         = 3000
    protocol        = "tcp"
    security_groups = [aws_security_group.alb.id]
  }
  egress { from_port = 0 to_port = 0 protocol = "-1" cidr_blocks = ["0.0.0.0/0"] }
}

resource "aws_lb" "this" {
  name               = "${local.name}-alb"
  internal           = false
  load_balancer_type = "application"
  security_groups    = [aws_security_group.alb.id]
  subnets            = var.public_subnet_ids
}

resource "aws_lb_target_group" "tg" {
  name        = "${local.name}-tg"
  port        = 3000
  protocol    = "HTTP"
  vpc_id      = var.vpc_id
  target_type = "ip"
  health_check {
    path                = "/"
    matcher             = "200-399"
    interval            = 30
    unhealthy_threshold = 3
    healthy_threshold   = 2
    timeout             = 5
  }
}

resource "aws_lb_listener" "https" {
  load_balancer_arn = aws_lb.this.arn
  port              = 443
  protocol          = "HTTPS"
  ssl_policy        = "ELBSecurityPolicy-TLS13-1-2-2021-06"
  certificate_arn   = var.alb_acm_cert_arn
  default_action { type = "forward" target_group_arn = aws_lb_target_group.tg.arn }
}

resource "aws_lb_listener" "http_redirect" {
  load_balancer_arn = aws_lb.this.arn
  port              = 80
  protocol          = "HTTP"
  default_action {
    type = "redirect"
    redirect { port = "443" protocol = "HTTPS" status_code = "HTTP_301" }
  }
}

data "aws_iam_policy_document" "ecs_tasks_assume" {
  statement {
    actions = ["sts:AssumeRole"]
    principals { type = "Service" identifiers = ["ecs-tasks.amazonaws.com"] }
  }
}

resource "aws_iam_role" "exec" {
  name               = "${local.name}-exec"
  assume_role_policy = data.aws_iam_policy_document.ecs_tasks_assume.json
}

resource "aws_iam_role_policy_attachment" "exec_ecr" {
  role       = aws_iam_role.exec.name
  policy_arn = "arn:aws:iam::aws:policy/service-role/AmazonECSTaskExecutionRolePolicy"
}

resource "aws_iam_role" "task" {
  name               = "${local.name}-task"
  assume_role_policy = data.aws_iam_policy_document.ecs_tasks_assume.json
}

data "aws_iam_policy_document" "bedrock" {
  statement {
    effect = "Allow"
    actions = [
      "bedrock:InvokeModel",
      "bedrock:InvokeModelWithResponseStream"
    ]
    resources = ["*"]
  }
}

resource "aws_iam_policy" "bedrock" {
  name   = "${local.name}-bedrock"
  policy = data.aws_iam_policy_document.bedrock.json
}

resource "aws_iam_role_policy_attachment" "task_bedrock" {
  role       = aws_iam_role.task.name
  policy_arn = aws_iam_policy.bedrock.arn
}

resource "aws_ecs_cluster" "this" { name = "${local.name}-cluster" }

resource "aws_ecs_task_definition" "this" {
  family                   = local.name
  network_mode             = "awsvpc"
  requires_compatibilities = ["FARGATE"]
  cpu                      = var.cpu
  memory                   = var.memory
  execution_role_arn       = aws_iam_role.exec.arn
  task_role_arn            = aws_iam_role.task.arn
  runtime_platform {
    operating_system_family = "LINUX"
    cpu_architecture        = "X86_64"
  }

  container_definitions = jsonencode([{
    name      = local.name
    image     = local.image_uri
    essential = true
    portMappings = [{ containerPort = 3000, protocol = "tcp" }]
    environment = [
      { name = "NODE_ENV",        value = "production" },
      { name = "PORT",            value = "8001" },
      { name = "SERVER_BASE_URL", value = "http://localhost:8001" },
      { name = "AWS_REGION",      value = var.aws_region }
      # Optional UI gate:
      # { name = "DEEPWIKI_AUTH_MODE", value = "true" },
      # { name = "DEEPWIKI_AUTH_CODE", value = "change-me" }
    ]
    logConfiguration = {
      logDriver = "awslogs",
      options = {
        awslogs-group         = aws_cloudwatch_log_group.app.name,
        awslogs-region        = var.aws_region,
        awslogs-stream-prefix = "ecs"
      }
    }
  }])
}

resource "aws_ecs_service" "this" {
  name            = local.name
  cluster         = aws_ecs_cluster.this.id
  task_definition = aws_ecs_task_definition.this.arn
  desired_count   = var.desired_count
  launch_type     = "FARGATE"
  enable_execute_command = true

  network_configuration {
    subnets         = var.private_subnet_ids
    security_groups = [aws_security_group.svc.id]
    assign_public_ip = false
  }

  load_balancer {
    target_group_arn = aws_lb_target_group.tg.arn
    container_name   = local.name
    container_port   = 3000
  }

  depends_on = [aws_lb_listener.https]
}

resource "aws_appautoscaling_target" "svc" {
  max_capacity       = var.max_count
  min_capacity       = var.min_count
  resource_id        = "service/${aws_ecs_cluster.this.name}/${aws_ecs_service.this.name}"
  scalable_dimension = "ecs:service:DesiredCount"
  service_namespace  = "ecs"
}

resource "aws_appautoscaling_policy" "req_per_tgt" {
  name               = "${local.name}-rpt"
  policy_type        = "TargetTrackingScaling"
  resource_id        = aws_appautoscaling_target.svc.resource_id
  scalable_dimension = aws_appautoscaling_target.svc.scalable_dimension
  service_namespace  = aws_appautoscaling_target.svc.service_namespace
  target_tracking_scaling_policy_configuration {
    target_value       = 50
    predefined_metric_specification {
      predefined_metric_type = "ALBRequestCountPerTarget"
      resource_label = "${aws_lb.this.arn_suffix}/${aws_lb_target_group.tg.arn_suffix}"
    }
    scale_in_cooldown  = 60
    scale_out_cooldown = 60
  }
}
