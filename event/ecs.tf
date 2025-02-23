# ECS
# ECS cluster
resource "aws_ecs_cluster" "event_cluster" {
  name = "terraform-event-ecs-cluster"

  tags = {
    Name = "terraform-event-ecs-Cluster"
  }
}

# ECS task Definition

resource "aws_ecs_task_definition" "event_task" {
  family                   = "event-task"
  network_mode             = "awsvpc"
  requires_compatibilities = ["FARGATE"]
  cpu                      = "256"
  memory                   = "512"
  execution_role_arn       = data.aws_iam_role.ecs_task_execution_role.arn


  container_definitions = jsonencode([
    {
      name      = "terraform-event-app"
      image     = "605134473022.dkr.ecr.ap-northeast-2.amazonaws.com/junglegym-test/nginx"
      essential = true
      portMappings = [
        {
          containerPort = 80
          hostPort      = 80
        }
      ]

        environment = [
        { name = "DB_HOST", value = aws_db_instance.event_rds.address },
        { name = "DB_PORT", value = "5432" }
      ],
      secrets = [
        { name = "DB_USER", valueFrom = "${aws_secretsmanager_secret.rds_secret.arn}:username::" },
        { name = "DB_PASSWORD", valueFrom = "${aws_secretsmanager_secret.rds_secret.arn}:password::" }
      ]
  #    secrets = [
  #      { name = "DB_USER", valueFrom = "${aws_secretsmanager_secret.rds_secret.arn}:username::" },
  #      { name = "DB_PASSWORD", valueFrom = "${aws_secretsmanager_secret.rds_secret.arn}:password::" }
  #    ]
    }
  ])


  lifecycle {
    create_before_destroy = true
  }


  tags = {
    Name = "terraform-event-task-definition"
  }

   # ✅ ECS 실행 전 RDS & ASM이 완료되도록 설정
  depends_on = [aws_db_instance.event_rds, aws_secretsmanager_secret_version.rds_secret_version]
}


# IAM

# 기존 IAM Role을 가져오기 (새로 생성하지 않음)
data "aws_iam_role" "ecs_task_execution_role" {
  name = "ecsTaskExecutionRole"
}

# 기본 실행 역할 정책 (ECS 태스크 실행을 위한 권한 부여)
resource "aws_iam_policy_attachment" "ecs_task_execution_role_policy" {
  name       = "ecs-task-execution-role-policy"
  roles      = [data.aws_iam_role.ecs_task_execution_role.name]
  policy_arn = "arn:aws:iam::aws:policy/service-role/AmazonECSTaskExecutionRolePolicy"
}

# 추가적으로 ECR Pull 권한 부여
resource "aws_iam_policy_attachment" "ecs_task_execution_role_ecr_policy" {
  name       = "ecs-task-execution-role-ecr-policy"
  roles      = [
    data.aws_iam_role.ecs_task_execution_role.name,
    "EKScontrolPlaneRole"
  ]
    policy_arn = "arn:aws:iam::aws:policy/AmazonEC2ContainerRegistryReadOnly"

  lifecycle {
    ignore_changes = [roles]
  }

}


#  RDS 또는 애플리케이션에서 Secrets Manager(ASM)에서 암호를 가져올 수 있도록 IAM 정책을 적용

resource "aws_iam_policy" "secrets_policy" {
  name        = "AllowRDSSecretsAccess"
  description = "Allows RDS to access Secrets Manager and decrypt with KMS"

  policy = jsonencode({
    Version = "2012-10-17"
    Statement = [
      {
        Effect = "Allow"
        Action = [
          "secretsmanager:GetSecretValue",
          "secretsmanager:DescribeSecret"
        ]
        Resource = aws_secretsmanager_secret.rds_secret.arn
      },
      {
        Effect = "Allow"
        Action = [
          "kms:Decrypt"
        ]
        Resource = aws_kms_key.event_rds_kms.arn
      }
    ]
  })
}

resource "aws_iam_role" "rds_secrets_role" {
  name = "rds-secrets-role"

  assume_role_policy = jsonencode({
    Version = "2012-10-17"
    Statement = [
      {
        Effect = "Allow"
        Principal = {
          Service = "rds.amazonaws.com"
        }
        Action = "sts:AssumeRole"
      }
    ]
  })

}

resource "aws_iam_role_policy_attachment" "rds_secrets_role_attachment" {
  role       = aws_iam_role.rds_secrets_role.name
  policy_arn = aws_iam_policy.secrets_policy.arn
}









# ECS service
resource "aws_ecs_service" "event_service" {
  name            = "terraform-event-service"
  cluster         = aws_ecs_cluster.event_cluster.id
  task_definition = aws_ecs_task_definition.event_task.arn
  desired_count   = 2  # ECS 인스턴스 개수
  launch_type     = "FARGATE"

  network_configuration {
    subnets         = [aws_subnet.private_a_1.id, aws_subnet.private_c_1.id]
    security_groups = [aws_security_group.sg_ecs.id]
  }

  load_balancer {
    target_group_arn = aws_lb_target_group.event_tg.arn
    container_name   = "terraform-event-app"
    container_port   = 80
  }

  deployment_controller {
    type = "ECS"
  }

  force_new_deployment = true

  tags = {
    Name = "terraform-event-ecs-service"
  }
}



# ECS security group
resource "aws_security_group" "sg_ecs" {
  vpc_id = aws_vpc.junglegym_event_vpc.id

  ingress {
    from_port       = 80
    to_port         = 80
    protocol        = "tcp"
    security_groups = [aws_security_group.sg_alb.id]
  }

  egress {
  # redis로 나가는 트래픽  포트 허용
    from_port       = 6379
    to_port         = 6379
    protocol        = "tcp"
    security_groups = [aws_security_group.sg_redis.id]
  }

  egress {
    # RDS(PostgreSQL)로 나가는 트래픽 5432 포트 허용
    from_port       = 5432
    to_port         = 5432
    protocol        = "tcp"
    cidr_blocks = ["10.1.0.0/16"]
  }


  egress {
    from_port   = 0
    to_port     = 0
    protocol    = "-1"
    cidr_blocks = ["0.0.0.0/0"]
  }

  tags = {
    Name = "terraform-event-vpc-ecs-sg"
  }
}

