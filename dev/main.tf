# VPC
resource "aws_vpc" "junglegym_dev_vpc" {
  cidr_block = "10.0.0.0/16"

  enable_dns_support   = true
  enable_dns_hostnames = true

  tags = {
    Name = "junglegym-dev-vpc"
    Environment = "dev"
  }
}

# ap-northeast-2a
# public subnet (ap-northeast-2a)
resource "aws_subnet" "public_a" {
  vpc_id                  = aws_vpc.junglegym_dev_vpc.id
  cidr_block              = "10.0.101.0/24"
  availability_zone       = "ap-northeast-2a"
  map_public_ip_on_launch = true

  tags = {
    Name = "public-subnet-a"
  }
}

# private subnets (ap-northeast-2a에 2개 할당)
resource "aws_subnet" "private_a_1" {
  vpc_id            = aws_vpc.junglegym_dev_vpc.id
  cidr_block        = "10.0.1.0/24"
  availability_zone = "ap-northeast-2a"

  tags = {
    Name = "private-subnet-a-1"
  }
}

resource "aws_subnet" "private_a_2" {
  vpc_id            = aws_vpc.junglegym_dev_vpc.id
  cidr_block        = "10.0.2.0/24"
  availability_zone = "ap-northeast-2a"

  tags = {
    Name = "private-subnet-a-2"
  }
}

# ap-northeast-2c
# public_subnet ( ap-northeast-2c )
resource "aws_subnet" "public_c" {
  vpc_id                  = aws_vpc.junglegym_dev_vpc.id
  cidr_block              = "10.0.102.0/24"
  availability_zone       = "ap-northeast-2c"
  map_public_ip_on_launch = true

  tags = {
    Name = "public-subnet-c"
  }
}

# private subnets (ap-northeast-2c에 2개 할당)

resource "aws_subnet" "private_c_1" {
  vpc_id            = aws_vpc.junglegym_dev_vpc.id
  cidr_block        = "10.0.3.0/24"
  availability_zone = "ap-northeast-2c"

  tags = {
    Name = "private-subnet-c-1"
  }
}

resource "aws_subnet" "private_c_2" {
  vpc_id            = aws_vpc.junglegym_dev_vpc.id
  cidr_block        = "10.0.4.0/24"
  availability_zone = "ap-northeast-2c"

  tags = {
    Name = "private-subnet-c-2"
  }
}

# NAT gateway

# EIP 가져오기 (이미 콘솔에서 생성된 EIP를 사용)
data "aws_eip" "eip_a" {
  public_ip = "13.209.28.243" 
}

data "aws_eip" "eip_c" {
  public_ip = "52.78.183.181" 
}

# NAT Gateway A (퍼블릭 서브넷 A에 위치)
resource "aws_nat_gateway" "event_nat_a" {
  allocation_id = data.aws_eip.eip_a.id 
  subnet_id     = aws_subnet.public_a.id

  tags = {
    Name = "dev-nat-gateway-a"
  }
}

# NAT Gateway C (퍼블릭 서브넷 C에 위치)
resource "aws_nat_gateway" "event_nat_c" {
  allocation_id = data.aws_eip.eip_c.id 
  subnet_id     = aws_subnet.public_c.id

  tags = {
    Name = "dev-nat-gateway-c"
  }
}


# ALB
# ALB (Application Load Balancer) 생성
resource "aws_lb" "event_alb" {
  name               = "event-alb"
  internal           = false
  load_balancer_type = "application"
  security_groups    = [aws_security_group.ec2_sg.id]
  subnets            = [aws_subnet.public_a.id, aws_subnet.public_c.id]

  enable_deletion_protection = false
  enable_http2               = true
  enable_cross_zone_load_balancing = true

  tags = {
    Name        = "terraform-dev-event-alb"
    Environment = "dev"
  }
}

# ALB Target Group 설정
resource "aws_lb_target_group" "event_tg" {
  name     = "event-target-group"
  port     = 80
  protocol = "HTTP"
  vpc_id   = aws_vpc.junglegym_dev_vpc.id

  health_check {
    path                = "/health"
    interval            = 30
    timeout             = 5
    healthy_threshold   = 3
    unhealthy_threshold = 3
  }

  tags = {
    Name = "event-target-group"
  }
}

# ALB 리스너 (HTTP 80 포트)
resource "aws_lb_listener" "event_listener" {
  load_balancer_arn = aws_lb.event_alb.arn
  port              = "80"
  protocol          = "HTTP"

  default_action {
    type             = "fixed-response"
    fixed_response {
      status_code = 200
      content_type = "text/plain"
      message_body = "OK"
    }
  }
}





# EKS























# Database (직접 리소스로 정의)
resource "aws_db_instance" "junglegym_rds" {
  identifier         = "terraform-dev-junglegym-rds"
  engine             = "mysql"
  engine_version     = "8.0"
  instance_class     = "db.t3.micro"
  allocated_storage  = 20
  db_name            = "terraform-dev-rds"
  username           = "root"
  password           = "your_password_here"
  port               = "3306"
  publicly_accessible = false

  iam_database_authentication_enabled = true

  vpc_security_group_ids = [aws_security_group.rds_sg.id]

  tags = {
    Owner       = "user"
    Environment = "dev"
  }

  lifecycle {
    prevent_destroy = true  # 데이터베이스 삭제를 방지하려면 추가
  }
}

# RDS IAM Apply
resource "aws_iam_role" "rds_iam_role" {
  name = "junglegym-rds-access-role"

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

  tags = {
    Name = "RDS IAM Role"
  }
}

data "aws_caller_identity" "current" {}

resource "aws_iam_policy" "rds_iam_policy" {
  name        = "junglegym-rds-access-policy"
  description = "Allow IAM role to connect to RDS"

  policy = jsonencode({
    Version = "2012-10-17"
    Statement = [
      {
        Effect = "Allow"
        Action = ["rds-db:connect"]
        Resource = "arn:aws:rds-db:ap-northeast-2:${data.aws_caller_identity.current.account_id}:dbuser:${aws_db_instance.junglegym_rds.identifier}/iam_user"
      }
    ]
  })
}


# ECS

# ECS task role 
resource "aws_iam_role" "ecs_task_execution_role" {
  name = "ecs-task-execution-role"

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

  tags = {
    Name = "terraform-event-ecs-task-execution-role"
  }
}

# ECS Cluster 생성
resource "aws_ecs_cluster" "junglegym_cluster" {
  name = "junglegym-cluster"

  tags = {
    Name = "terraform-dev-ecs-cluster"
  }
}

# ECS Task Definition
resource "aws_ecs_task_definition" "event_task" {
  family                   = "event-task"
  network_mode             = "awsvpc"
  requires_compatibilities = ["FARGATE"]
  cpu                      = "256"
  memory                   = "512"
  execution_role_arn       = aws_iam_role.ecs_task_execution_role.arn

  container_definitions = jsonencode([{
    name      = "event-app"
    image     = "605134473022.dkr.ecr.ap-northeast-2.amazonaws.com/junglegym-test/nginx"
    essential = true
    portMappings = [
      {
        containerPort = 80
        hostPort      = 80
      }
    ]
  }])

  tags = {
    Name = "terraform-dev-ecs-event-task"
  }
}

# ECS Service 생성
resource "aws_ecs_service" "event_service" {
  name            = "event-service"
  cluster         = aws_ecs_cluster.junglegym_cluster.id
  task_definition = aws_ecs_task_definition.event_task.arn
  desired_count   = 2  # ECS 인스턴스 개수
  launch_type     = "FARGATE"

  network_configuration {
    subnets         = [aws_subnet.private_c_1.id]
    security_groups = [aws_security_group.ec2_sg.id]
  }

  load_balancer {
    target_group_arn = aws_lb_target_group.event_tg.arn
    container_name   = "event-app"
    container_port   = 80
  }

  deployment_controller {
    type = "ECS"
  }

  force_new_deployment = false

  tags = {
    Name = "terraform-dev-ecs-event-service"
  }
}

# ECS Service에 연결된 Security Group
resource "aws_security_group" "ec2_sg" {
  name        = "ec2-sg"
  description = "EC2 Security Group"
  vpc_id      = aws_vpc.junglegym_dev_vpc.id

  ingress {
    from_port   = 22
    to_port     = 22
    protocol    = "tcp"
    cidr_blocks = ["203.0.113.0/24"]
  }

  ingress {
    from_port   = 80
    to_port     = 80
    protocol    = "tcp"
    cidr_blocks = ["0.0.0.0/0"]
  }

  ingress {
    from_port   = 443
    to_port     = 443
    protocol    = "tcp"
    cidr_blocks = ["0.0.0.0/0"]
  }

  egress {
    from_port   = 0
    to_port     = 0
    protocol    = "-1"
    cidr_blocks = ["0.0.0.0/0"]
  }

  tags = {
    Name = "terraform-dev-ec2-sg"
  }
}



# Redis Private Subnet C (ap-northeast-2c)
resource "aws_elasticache_subnet_group" "redis_subnet_group" {
  name       = "junglegym-redis-subnet-group"
  subnet_ids = [aws_subnet.private_c_2.id]

  tags = {
    Name        = "terraform-dev-redis-subnet-group"
    Environment = "dev"
  }
}

# DB 보안 그룹 (ECS와만 연결)
resource "aws_security_group" "rds_sg" {
  name        = "rds-sg"
  description = "RDS Security Group"
  vpc_id      = aws_vpc.junglegym_dev_vpc.id

  ingress {
    from_port       = 3306
    to_port         = 3306
    protocol        = "tcp"
    security_groups = [aws_security_group.ec2_sg.id]  # ECS 서비스와만 연결
  }

  egress {
    from_port   = 0
    to_port     = 0
    protocol    = "-1"
    cidr_blocks = ["0.0.0.0/0"]
  }

  tags = {
    Name = "terraform-dev-rds-sg"
  }
}

# Redis 보안 그룹 (접근 제한)
resource "aws_security_group" "redis_sg" {
  name        = "redis-sg"
  description = "Redis Security Group"
  vpc_id      = aws_vpc.junglegym_dev_vpc.id

  ingress {
    from_port   = 6379
    to_port     = 6379
    protocol    = "tcp"
    cidr_blocks = ["10.0.0.0/16"]
  }

  egress {
    from_port   = 0
    to_port     = 0
    protocol    = "-1"
    cidr_blocks = ["0.0.0.0/0"]
  }

  tags = {
    Name = "terraform-dev-redis-sg"
  }
}

resource "aws_elasticache_replication_group" "redis" {
  replication_group_id = "junglegym-redis-cluster"
  engine               = "redis"
  node_type            = "cache.t3.micro"
  num_node_groups      = 1
  replicas_per_node_group = 1
  automatic_failover_enabled = true
  parameter_group_name = "default.redis7"
  subnet_group_name    = aws_elasticache_subnet_group.redis_subnet_group.name
  security_group_ids   = [aws_security_group.redis_sg.id]
  description = "terraform-dev-redis cluster"  

  tags = {
    Name        = "terraform-dev-junglegym-redis"
    Environment = "dev"
  }
}


