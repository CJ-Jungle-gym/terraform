# 타겟그룹은 콘솔에서 지우면 안되고 , 테라폼에서는 참조만 하도록 설정







########## provider ########

provider "aws" {
  region = "ap-northeast-2"
}

########## Existing VPC #########
data "aws_vpc" "event_vpc" {
  id = "vpc-061260f6e81150f73"
}

########## Existing ECS Cluster Reference #########
data "aws_ecs_cluster" "event_ecs_cluster" {
  cluster_name = "terraform-event-ecs-cluster"
}

######### Existing ECS Services #########
data "aws_ecs_service" "event_ecs_backend_service" {
  cluster_arn  = data.aws_ecs_cluster.event_ecs_cluster.id
  service_name = "jgbackend"
}

data "aws_ecs_service" "event_ecs_frontend_service" {
  cluster_arn  = data.aws_ecs_cluster.event_ecs_cluster.id
  service_name = "jgfrontend"
}


######### application load balancer #########
data "aws_lb" "ecs_alb_backend" {
  name = "ecs-alb-3"
}

data "aws_lb" "ecs_alb_frontend" {
  name = "ecs-alb-4"
}



########## target group  #########
data "aws_lb_target_group" "ecs_frontend_target_group" {
  name = "ecs-jgfrontend2"
}


data "aws_lb_target_group" "ecs_backend_target_group" {
  name = "ecs-jgbackend2"
}

########## Load Balancer Listener ##########

resource "aws_lb_listener" "backend_listener" {
  load_balancer_arn = data.aws_lb.ecs_alb_backend.arn
  port              = 443
  protocol          = "HTTP"
  certificate_arn   = "arn:aws:acm:ap-northeast-2:605134473022:certificate/e09cfc78-5279-445b-9eeb-c1e0f0290408"


  default_action {
    type             = "forward"
    target_group_arn = data.aws_lb_target_group.ecs_backend_target_group.arn
  }

  lifecycle {
    ignore_changes = [
      protocol,
      port,
      certificate_arn,
      default_action
    ]
  }

}

resource "aws_lb_listener" "frontend_listener" {
  load_balancer_arn = data.aws_lb.ecs_alb_frontend.arn
  port              = 443
  protocol          = "HTTP"
  certificate_arn   = "arn:aws:acm:ap-northeast-2:605134473022:certificate/e09cfc78-5279-445b-9eeb-c1e0f0290408"

  default_action {
    type             = "forward"
    target_group_arn = data.aws_lb_target_group.ecs_frontend_target_group.arn
  }

  lifecycle {
    ignore_changes = [
      protocol,
      port,
      certificate_arn,
      default_action
    ]
  }

}

########## Load Balancer Listener Rules ##########

resource "aws_lb_listener_rule" "backend_rule" {
  listener_arn = aws_lb_listener.backend_listener.arn
  priority     = 99999

  condition {
    path_pattern {
      values = ["/api/*"]
    }
  }


  action {
    type             = "forward"
    target_group_arn = data.aws_lb_target_group.ecs_backend_target_group.arn
  }

  lifecycle {
    ignore_changes = [
      priority,
      condition,
      action
    ]
  }

  depends_on = [
    aws_lb_listener.backend_listener
  ]
}

resource "aws_lb_listener_rule" "frontend_rule" {
  listener_arn = aws_lb_listener.frontend_listener.arn
  priority     = 99999

  condition {
    path_pattern {
      values = ["/*"]
    }
  }

  action {
    type             = "forward"
    target_group_arn = data.aws_lb_target_group.ecs_frontend_target_group.arn
  }

  lifecycle {
    ignore_changes = [
      priority,
      condition,
      action
    ]
  }

  depends_on = [
    aws_lb_listener.frontend_listener
  ]
}








########## Existing Networking Components #########
data "aws_subnet" "subnet_a1" {
  # private subnet a
  id = "subnet-0851efb83b6602a1a"
}

data "aws_subnet" "subnet_c1" {
  # private subnet c
  id = "subnet-082da239442c8c12e"
}

########## 기존 보안 그룹 참조 #########
data "aws_security_group" "ecs_sg" {
  id = "sg-0dfcd48421c1f6a72"
}

########## CloudWatch Log Group #########
data "aws_cloudwatch_log_group" "ecs_log_group" {
  name = "/ecs/event-ecs-backend-task"
}



########## Existing ECR Repositories #########
data "aws_ecr_repository" "eventback" {
  name = "eventback"
}

data "aws_ecr_repository" "olive-back" {
  name = "olive-back"
}

data "aws_ecr_repository" "olive-front" {
  name = "olive-front"
}

data "aws_ecr_repository" "jenkins-images" {
  name = "jenkins-images"
}


data "aws_ecr_image" "latest_eventback" {
  repository_name = data.aws_ecr_repository.eventback.name
  most_recent     = true
}

data "aws_ecr_image" "latest_olive_front" {
  repository_name = data.aws_ecr_repository.olive-front.name
  most_recent     = true
}








########## ECS Task Definition (backend) #########
resource "aws_ecs_task_definition" "event_ecs_backend_task" {
  family                   = "event-ecs-backend-task"
  network_mode             = "awsvpc"
  requires_compatibilities = ["FARGATE"]
  execution_role_arn       = "arn:aws:iam::605134473022:role/ecsTaskExecutionRole"
  task_role_arn            = "arn:aws:iam::605134473022:role/ecsTaskExecutionRole"
  cpu                      = "1024"
  memory                   = "3072"

  container_definitions = jsonencode([{
    name      = "event-ecs-back-container"
    image     = "${data.aws_ecr_repository.eventback.repository_url}:${data.aws_ecr_image.latest_eventback.image_digest}"
    cpu       = 0
    memory    = 3072
    essential = true

    portMappings = [{
      containerPort = 8080
      protocol      = "tcp"
    }]

    logConfiguration = {
      logDriver = "awslogs"
      options = {
        awslogs-group         = data.aws_cloudwatch_log_group.ecs_log_group.name
        awslogs-region        = "ap-northeast-2"
        awslogs-stream-prefix = "ecs"
      }
    }
  }])

  lifecycle {
    ignore_changes = [container_definitions]
  }
}

########## ECS Task Definition (Frontend) #########
resource "aws_ecs_task_definition" "event_ecs_frontend_task" {
  family                   = "event-ecs-frontend-task"
  network_mode             = "awsvpc"
  requires_compatibilities = ["FARGATE"]
  execution_role_arn       = "arn:aws:iam::605134473022:role/ecsTaskExecutionRole"
  task_role_arn            = "arn:aws:iam::605134473022:role/ecsTaskExecutionRole"
  cpu                      = "1024"
  memory                   = "3072"

  container_definitions = jsonencode([{
    name      = "event-ecs-front-container"
    image     = "${data.aws_ecr_repository.olive-front.repository_url}:${data.aws_ecr_image.latest_olive_front.image_digest}"
    cpu       = 0
    memory    = 1024
    essential = true

    portMappings = [{
      containerPort = 80
      protocol      = "tcp"
    }]

    logConfiguration = {
      logDriver = "awslogs"
      options = {
        awslogs-group         = "/ecs/event-ecs-frontend-task"
        awslogs-region        = "ap-northeast-2"
        awslogs-stream-prefix = "ecs"
      }
    }
  }])

  lifecycle {
    ignore_changes = [container_definitions, cpu, memory, runtime_platform]
  }

}

########## ECS Service (Backend) #########
resource "aws_ecs_service" "event_ecs_backend_service" {
  name            = "jgbackend"
  cluster         = data.aws_ecs_cluster.event_ecs_cluster.id
  task_definition = aws_ecs_task_definition.event_ecs_backend_task.arn
  launch_type     = "FARGATE"

  network_configuration {
    subnets          = [data.aws_subnet.subnet_a1.id, data.aws_subnet.subnet_c1.id]
    security_groups  = [data.aws_security_group.ecs_sg.id]
    assign_public_ip = true
  }

  lifecycle {
    ignore_changes = [
      availability_zone_rebalancing,
      enable_ecs_managed_tags,
      network_configuration[0].assign_public_ip,
      deployment_circuit_breaker
    ]
  }

  load_balancer {
    target_group_arn = data.aws_lb_target_group.ecs_backend_target_group.arn
    container_name   = "event-ecs-back-container"
    container_port   = 8080
  }

  depends_on = [
    aws_ecs_task_definition.event_ecs_backend_task,
    aws_lb_listener.backend_listener,
    aws_lb_listener_rule.backend_rule,
    data.aws_lb_target_group.ecs_backend_target_group
  ]

}

########## ECS Service (Frontend) #########
resource "aws_ecs_service" "event_ecs_frontend_service" {
  name            = "jgfrontend"
  cluster         = data.aws_ecs_cluster.event_ecs_cluster.id
  task_definition = aws_ecs_task_definition.event_ecs_frontend_task.arn
  launch_type     = "FARGATE"

  network_configuration {
    subnets          = [data.aws_subnet.subnet_a1.id, data.aws_subnet.subnet_c1.id]
    security_groups  = [data.aws_security_group.ecs_sg.id]
    assign_public_ip = true
  }

  desired_count = 1

  load_balancer {
    target_group_arn = data.aws_lb_target_group.ecs_frontend_target_group.arn
    container_name   = "event-ecs-front-container"
    container_port   = 80
  }

  lifecycle {
    ignore_changes = [
      availability_zone_rebalancing,
      enable_ecs_managed_tags,
      health_check_grace_period_seconds,
      network_configuration[0].assign_public_ip,
      deployment_circuit_breaker
    ]
  }


  depends_on = [
    aws_ecs_task_definition.event_ecs_frontend_task,
    aws_lb_listener.frontend_listener,
    aws_lb_listener_rule.frontend_rule,
    data.aws_lb_target_group.ecs_frontend_target_group
  ]
}


########## Auto Scaling 설정 유지 #########
########333
resource "aws_appautoscaling_target" "ecs_backend_target" {
  max_capacity       = 10
  min_capacity       = 1
  resource_id        = "service/${data.aws_ecs_cluster.event_ecs_cluster.cluster_name}/jgbackend"
  scalable_dimension = "ecs:service:DesiredCount"
  service_namespace  = "ecs"

  depends_on = [
    aws_ecs_service.event_ecs_backend_service
  ]

  lifecycle {
    ignore_changes = all
  }
}


resource "aws_appautoscaling_target" "ecs_frontend_target" {
  max_capacity       = 10
  min_capacity       = 1
  resource_id        = "service/${data.aws_ecs_cluster.event_ecs_cluster.cluster_name}/jgfrontend"
  scalable_dimension = "ecs:service:DesiredCount"
  service_namespace  = "ecs"

  depends_on = [
    aws_ecs_service.event_ecs_frontend_service
  ]

  lifecycle {
    ignore_changes = all
  }
}


########## ECS 오토 스케일링 정책 (CPU 기준)  #########
# backend
resource "aws_appautoscaling_policy" "ecs_backend_scaling_policy" {
  name               = "target"
  service_namespace  = "ecs"
  resource_id        = "service/${data.aws_ecs_cluster.event_ecs_cluster.cluster_name}/jgbackend"
  scalable_dimension = "ecs:service:DesiredCount"
  policy_type        = "TargetTrackingScaling"

  target_tracking_scaling_policy_configuration {
    target_value = 50.0
    predefined_metric_specification {
      predefined_metric_type = "ECSServiceAverageCPUUtilization"
    }
    scale_in_cooldown  = 120
    scale_out_cooldown = 120
  }

  depends_on = [
    aws_appautoscaling_target.ecs_backend_target
  ]

  lifecycle {
    ignore_changes = all
  }
}

# frontend
resource "aws_appautoscaling_policy" "ecs_frontend_scaling_policy" {
  name               = "target"
  service_namespace  = "ecs"
  resource_id        = "service/${data.aws_ecs_cluster.event_ecs_cluster.cluster_name}/jgfrontend"
  scalable_dimension = "ecs:service:DesiredCount"
  policy_type        = "TargetTrackingScaling"

  target_tracking_scaling_policy_configuration {
    target_value = 50.0
    predefined_metric_specification {
      predefined_metric_type = "ECSServiceAverageCPUUtilization"
    }
    scale_in_cooldown  = 120
    scale_out_cooldown = 120
  }

  depends_on = [
    aws_appautoscaling_target.ecs_frontend_target
  ]

  lifecycle {
    ignore_changes = all
  }
}
