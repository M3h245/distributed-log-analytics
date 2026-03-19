resource "aws_ecs_cluster" "main" {
  name = "${var.project_name}-cluster"
}

resource "aws_service_discovery_private_dns_namespace" "main" {
  name = "${var.project_name}.local"
  vpc  = aws_vpc.main.id
}

resource "aws_service_discovery_service" "producer" {
  name = "${var.project_name}-producer"

  dns_config {
    namespace_id = aws_service_discovery_private_dns_namespace.main.id
    dns_records {
      ttl  = 10
      type = "A"
    }
    routing_policy = "MULTIVALUE"
  }
}

locals {
  api_image_final       = var.api_image != "" ? var.api_image : "${aws_ecr_repository.api.repository_url}:${var.image_tag}"
  producer_image_final  = var.producer_image != "" ? var.producer_image : "${aws_ecr_repository.producer.repository_url}:${var.image_tag}"
  processor_image_final = var.processor_image != "" ? var.processor_image : "${aws_ecr_repository.processor.repository_url}:${var.image_tag}"
}

resource "aws_iam_role" "ecs_task_execution" {
  name = "${var.project_name}-ecs-task-exec"

  assume_role_policy = jsonencode({
    Version = "2012-10-17"
    Statement = [
      {
        Effect = "Allow"
        Principal = {
          Service = "ecs-tasks.amazonaws.com"
        }
        Action = "sts:AssumeRole"
      }
    ]
  })
}

resource "aws_iam_role_policy_attachment" "ecs_task_execution" {
  role       = aws_iam_role.ecs_task_execution.name
  policy_arn = "arn:aws:iam::aws:policy/service-role/AmazonECSTaskExecutionRolePolicy"
}

resource "aws_cloudwatch_log_group" "api" {
  name              = "/ecs/${var.project_name}/api"
  retention_in_days = 7
}

resource "aws_cloudwatch_log_group" "producer" {
  name              = "/ecs/${var.project_name}/producer"
  retention_in_days = 7
}

resource "aws_cloudwatch_log_group" "processor" {
  name              = "/ecs/${var.project_name}/processor"
  retention_in_days = 7
}

resource "aws_ecs_task_definition" "api" {
  family                   = "${var.project_name}-api"
  requires_compatibilities = ["FARGATE"]
  network_mode             = "awsvpc"
  cpu                      = var.api_cpu
  memory                   = var.api_memory
  execution_role_arn        = aws_iam_role.ecs_task_execution.arn

  container_definitions = jsonencode([
    {
      name      = "api"
      image     = local.api_image_final
      essential = true
      portMappings = [
        {
          containerPort = var.api_container_port
          protocol      = "tcp"
        }
      ]
      environment = [
        { name = "DB_HOST", value = aws_db_instance.postgres.address },
        { name = "DB_PORT", value = tostring(var.db_port) },
        { name = "POSTGRES_DB", value = var.db_name },
        { name = "POSTGRES_USER", value = var.db_username },
        { name = "POSTGRES_PASSWORD", value = var.db_password },
        { name = "PRODUCER_URL", value = "http://${aws_service_discovery_service.producer.name}.${aws_service_discovery_private_dns_namespace.main.name}:8000" }
      ]
      logConfiguration = {
        logDriver = "awslogs"
        options = {
          awslogs-group         = aws_cloudwatch_log_group.api.name
          awslogs-region        = var.aws_region
          awslogs-stream-prefix = "ecs"
        }
      }
    }
  ])
}

resource "aws_ecs_task_definition" "producer" {
  family                   = "${var.project_name}-producer"
  requires_compatibilities = ["FARGATE"]
  network_mode             = "awsvpc"
  cpu                      = var.worker_cpu
  memory                   = var.worker_memory
  execution_role_arn        = aws_iam_role.ecs_task_execution.arn

  container_definitions = jsonencode([
    {
      name      = "producer"
      image     = local.producer_image_final
      essential = true
      environment = [
        { name = "REDIS_HOST", value = aws_elasticache_replication_group.redis.primary_endpoint_address },
        { name = "REDIS_PORT", value = tostring(var.redis_port) },
        { name = "REDIS_STREAM", value = "log_stream" }
      ]
      logConfiguration = {
        logDriver = "awslogs"
        options = {
          awslogs-group         = aws_cloudwatch_log_group.producer.name
          awslogs-region        = var.aws_region
          awslogs-stream-prefix = "ecs"
        }
      }
    }
  ])
}

resource "aws_ecs_task_definition" "processor" {
  family                   = "${var.project_name}-processor"
  requires_compatibilities = ["FARGATE"]
  network_mode             = "awsvpc"
  cpu                      = var.worker_cpu
  memory                   = var.worker_memory
  execution_role_arn        = aws_iam_role.ecs_task_execution.arn

  container_definitions = jsonencode([
    {
      name      = "processor"
      image     = local.processor_image_final
      essential = true
      environment = [
        { name = "REDIS_HOST", value = aws_elasticache_replication_group.redis.primary_endpoint_address },
        { name = "REDIS_PORT", value = tostring(var.redis_port) },
        { name = "REDIS_STREAM", value = "log_stream" },
        { name = "REDIS_GROUP", value = "log_group" },
        { name = "DB_HOST", value = aws_db_instance.postgres.address },
        { name = "DB_PORT", value = tostring(var.db_port) },
        { name = "POSTGRES_DB", value = var.db_name },
        { name = "POSTGRES_USER", value = var.db_username },
        { name = "POSTGRES_PASSWORD", value = var.db_password }
      ]
      logConfiguration = {
        logDriver = "awslogs"
        options = {
          awslogs-group         = aws_cloudwatch_log_group.processor.name
          awslogs-region        = var.aws_region
          awslogs-stream-prefix = "ecs"
        }
      }
    }
  ])
}

resource "aws_ecs_service" "api_a" {
  name            = "${var.project_name}-api-a"
  cluster         = aws_ecs_cluster.main.id
  task_definition = aws_ecs_task_definition.api.arn
  desired_count   = 1
  launch_type     = "FARGATE"

  lifecycle {
    ignore_changes = [desired_count]
  }

  network_configuration {
    subnets         = [aws_subnet.public[0].id]
    security_groups = [aws_security_group.ecs.id]
    assign_public_ip = true
  }

  load_balancer {
    target_group_arn = aws_lb_target_group.api.arn
    container_name   = "api"
    container_port   = var.api_container_port
  }

  depends_on = [aws_lb_listener.http]
}

resource "aws_ecs_service" "api_b" {
  name            = "${var.project_name}-api-b"
  cluster         = aws_ecs_cluster.main.id
  task_definition = aws_ecs_task_definition.api.arn
  desired_count   = 1
  launch_type     = "FARGATE"

  lifecycle {
    ignore_changes = [desired_count]
  }

  network_configuration {
    subnets         = [aws_subnet.public[1].id]
    security_groups = [aws_security_group.ecs.id]
    assign_public_ip = true
  }

  load_balancer {
    target_group_arn = aws_lb_target_group.api.arn
    container_name   = "api"
    container_port   = var.api_container_port
  }

  depends_on = [aws_lb_listener.http]
}

resource "aws_ecs_service" "producer_a" {
  name            = "${var.project_name}-producer-a"
  cluster         = aws_ecs_cluster.main.id
  task_definition = aws_ecs_task_definition.producer.arn
  desired_count   = 1
  launch_type     = "FARGATE"

  lifecycle {
    ignore_changes = [desired_count]
  }

  network_configuration {
    subnets         = [aws_subnet.public[0].id]
    security_groups = [aws_security_group.ecs.id]
    assign_public_ip = true
  }

  service_registries {
    registry_arn = aws_service_discovery_service.producer.arn
  }
}

resource "aws_ecs_service" "producer_b" {
  name            = "${var.project_name}-producer-b"
  cluster         = aws_ecs_cluster.main.id
  task_definition = aws_ecs_task_definition.producer.arn
  desired_count   = 1
  launch_type     = "FARGATE"

  lifecycle {
    ignore_changes = [desired_count]
  }

  network_configuration {
    subnets         = [aws_subnet.public[1].id]
    security_groups = [aws_security_group.ecs.id]
    assign_public_ip = true
  }

  service_registries {
    registry_arn = aws_service_discovery_service.producer.arn
  }
}

resource "aws_ecs_service" "processor_a" {
  name            = "${var.project_name}-processor-a"
  cluster         = aws_ecs_cluster.main.id
  task_definition = aws_ecs_task_definition.processor.arn
  desired_count   = 1
  launch_type     = "FARGATE"

  lifecycle {
    ignore_changes = [desired_count]
  }

  network_configuration {
    subnets         = [aws_subnet.public[0].id]
    security_groups = [aws_security_group.ecs.id]
    assign_public_ip = true
  }
}

resource "aws_ecs_service" "processor_b" {
  name            = "${var.project_name}-processor-b"
  cluster         = aws_ecs_cluster.main.id
  task_definition = aws_ecs_task_definition.processor.arn
  desired_count   = 1
  launch_type     = "FARGATE"

  lifecycle {
    ignore_changes = [desired_count]
  }

  network_configuration {
    subnets         = [aws_subnet.public[1].id]
    security_groups = [aws_security_group.ecs.id]
    assign_public_ip = true
  }
}

resource "aws_appautoscaling_target" "api_a" {
  service_namespace  = "ecs"
  resource_id        = "service/${aws_ecs_cluster.main.name}/${aws_ecs_service.api_a.name}"
  scalable_dimension = "ecs:service:DesiredCount"
  min_capacity       = 1
  max_capacity       = 1
}

resource "aws_appautoscaling_target" "api_b" {
  service_namespace  = "ecs"
  resource_id        = "service/${aws_ecs_cluster.main.name}/${aws_ecs_service.api_b.name}"
  scalable_dimension = "ecs:service:DesiredCount"
  min_capacity       = 1
  max_capacity       = 1
}

resource "aws_appautoscaling_target" "producer_a" {
  service_namespace  = "ecs"
  resource_id        = "service/${aws_ecs_cluster.main.name}/${aws_ecs_service.producer_a.name}"
  scalable_dimension = "ecs:service:DesiredCount"
  min_capacity       = 1
  max_capacity       = 1
}

resource "aws_appautoscaling_target" "producer_b" {
  service_namespace  = "ecs"
  resource_id        = "service/${aws_ecs_cluster.main.name}/${aws_ecs_service.producer_b.name}"
  scalable_dimension = "ecs:service:DesiredCount"
  min_capacity       = 1
  max_capacity       = 1
}

resource "aws_appautoscaling_target" "processor_a" {
  service_namespace  = "ecs"
  resource_id        = "service/${aws_ecs_cluster.main.name}/${aws_ecs_service.processor_a.name}"
  scalable_dimension = "ecs:service:DesiredCount"
  min_capacity       = 1
  max_capacity       = 1
}

resource "aws_appautoscaling_target" "processor_b" {
  service_namespace  = "ecs"
  resource_id        = "service/${aws_ecs_cluster.main.name}/${aws_ecs_service.processor_b.name}"
  scalable_dimension = "ecs:service:DesiredCount"
  min_capacity       = 1
  max_capacity       = 1
}
