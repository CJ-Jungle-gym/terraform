
terraform {
  required_providers {
    aws = {
      source  = "hashicorp/aws"
      version = "~> 5.0"
    }
  }
}

provider "aws" {
  region = "ap-northeast-2"
}


# VPC
resource "aws_vpc" "junglegym_event_vpc" {
  cidr_block = "10.1.0.0/16"

  enable_dns_support   = true
  enable_dns_hostnames = true

  tags = {
    Name = "junglegym-event-vpc"
    Environment = "event"
  }
}

# ap-northeast-2a
# public subnet (ap-northeast-2a)
resource "aws_subnet" "public_a" {
  vpc_id                  = aws_vpc.junglegym_event_vpc.id
  cidr_block              = "10.1.200.0/24"
  availability_zone       = "ap-northeast-2a"
  map_public_ip_on_launch = true

  tags = {
    Name = "Event-vpc-public-subnet-a"
  }
}

# private subnets (ap-northeast-2a에 2개 할당)
resource "aws_subnet" "private_a_1" {
  vpc_id            = aws_vpc.junglegym_event_vpc.id
  cidr_block        = "10.1.1.0/24"
  availability_zone = "ap-northeast-2a"

  tags = {
    Name = "Event-vpc-private-subnet-a-1"
  }
}

resource "aws_subnet" "private_a_2" {
  vpc_id            = aws_vpc.junglegym_event_vpc.id
  cidr_block        = "10.1.2.0/24"
  availability_zone = "ap-northeast-2a"

  tags = {
    Name = "Event-vpc-private-subnet-a-2"
  }
}

# ap-northeast-2c
# public_subnet ( ap-northeast-2c )
resource "aws_subnet" "public_c" {
  vpc_id                  = aws_vpc.junglegym_event_vpc.id  
  cidr_block              = "10.1.201.0/24"
  availability_zone       = "ap-northeast-2c"
  map_public_ip_on_launch = true

  tags = {
    Name = "Event-vpc-public-subnet-c"  
  }
}

# private subnets (ap-northeast-2c에 2개 할당)
resource "aws_subnet" "private_c_1" {
  vpc_id            = aws_vpc.junglegym_event_vpc.id  
  cidr_block        = "10.1.3.0/24"
  availability_zone = "ap-northeast-2c"

  tags = {
    Name = "Event-vpc-private-subnet-c-1"  
  }
}

resource "aws_subnet" "private_c_2" {
  vpc_id            = aws_vpc.junglegym_event_vpc.id  
  cidr_block        = "10.1.4.0/24"
  availability_zone = "ap-northeast-2c"

  tags = {
    Name = "Event-vpc-private-subnet-c-2"  
  }
}

# NAT Gateway

data "aws_eip" "nat_eip_a" {
  filter {
    name   = "public-ip"
    values = ["3.38.29.119"]
  }
}

data "aws_eip" "nat_eip_c" {
  filter {
    name   = "public-ip"
    values = ["13.124.103.238"]
  }
}


# NAT Gateway A (퍼블릭 서브넷 A에 위치)
resource "aws_nat_gateway" "event_nat_a" {
  
  # 3.38.29.119 
  allocation_id = data.aws_eip.nat_eip_a.id
  subnet_id     = aws_subnet.public_a.id
  
  tags = {
    Name = "Event-NAT-Gateway-A"
  }
}

# NAT Gateway C (퍼블릭 서브넷 C에 위치)
resource "aws_nat_gateway" "event_nat_c" {
 
  # 13.124.103.238
  allocation_id = data.aws_eip.nat_eip_c.id
  subnet_id     = aws_subnet.public_c.id

  tags = {
    Name = "Event-NAT-Gateway-C"
  }
}



# Internet gateway
resource "aws_internet_gateway" "event_igw" {
  vpc_id = aws_vpc.junglegym_event_vpc.id

  tags = {
    Name = "Event-Internet-Gateway"
  }
}

# Routing Table and Public subnet  ( 라우팅 테이블과 퍼블릭 서브넷 연결)

resource "aws_route_table" "public_rt" {
  vpc_id = aws_vpc.junglegym_event_vpc.id

  route {
    cidr_block = "0.0.0.0/0"
    gateway_id = aws_internet_gateway.event_igw.id
  }

  tags = {
    Name = "Event-Public-Route-Table"
  }
}

resource "aws_route_table_association" "public_rt_a" {
  subnet_id      = aws_subnet.public_a.id
  route_table_id = aws_route_table.public_rt.id
}

resource "aws_route_table_association" "public_rt_c" {
  subnet_id      = aws_subnet.public_c.id
  route_table_id = aws_route_table.public_rt.id
}

# Routing table and Private subnet

# Private Route Table for Subnet A
resource "aws_route_table" "private_rt_a" {
  vpc_id = aws_vpc.junglegym_event_vpc.id

  route {
    cidr_block     = "0.0.0.0/0"
    nat_gateway_id = aws_nat_gateway.event_nat_a.id
  }

  tags = {
    Name = "Event-Private-Route-Table-A"
  }
}

# Private Route Table for Subnet C
resource "aws_route_table" "private_rt_c" {
  vpc_id = aws_vpc.junglegym_event_vpc.id

  route {
    cidr_block     = "0.0.0.0/0"
    nat_gateway_id = aws_nat_gateway.event_nat_c.id
  }

  tags = {
    Name = "Event-Private-Route-Table-C"
  }
}

# Private Subnet A1과 Private Subnet A2에 적용 (AZ A)
resource "aws_route_table_association" "private_a_1" {
  subnet_id      = aws_subnet.private_a_1.id
  route_table_id = aws_route_table.private_rt_a.id
}

resource "aws_route_table_association" "private_a_2" {
  subnet_id      = aws_subnet.private_a_2.id
  route_table_id = aws_route_table.private_rt_a.id
}

# Private Subnet C1과 Private Subnet C2에 적용 (AZ C)
resource "aws_route_table_association" "private_c_1" {
  subnet_id      = aws_subnet.private_c_1.id
  route_table_id = aws_route_table.private_rt_c.id
}

resource "aws_route_table_association" "private_c_2" {
  subnet_id      = aws_subnet.private_c_2.id
  route_table_id = aws_route_table.private_rt_c.id
}


# Security Group 

resource "aws_security_group" "sg_alb" {
  vpc_id = aws_vpc.junglegym_event_vpc.id

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
    Name = "Event-vpc-alb-sg"
  }
}


# ALB - Application Load Balancer
resource "aws_lb" "event_alb" {
  name               = "event-alb"
  internal           = false  
  load_balancer_type = "application"
  security_groups    = [aws_security_group.sg_alb.id]  
  subnets           = [aws_subnet.public_a.id, aws_subnet.public_c.id]  

  tags = {
    Name = "Event-ALB"
  }
}

# ALB target group
resource "aws_lb_target_group" "event_tg" {
  name        = "event-tg"
  port        = 80
  protocol    = "HTTP"
  vpc_id      = aws_vpc.junglegym_event_vpc.id
  target_type = "ip"  

  health_check {
    path                = "/"
    interval            = 30
    timeout             = 5
    healthy_threshold   = 2
    unhealthy_threshold = 2
  }

  tags = {
    Name = "Event-alb-target-group"
  }
}

#  ALB가 HTTP 요청을 수신하고 Target Group으로 전달하도록 설정
resource "aws_lb_listener" "event_listener" {
  load_balancer_arn = aws_lb.event_alb.arn
  port              = 80
  protocol          = "HTTP"

  default_action {
    type             = "forward"
    target_group_arn = aws_lb_target_group.event_tg.arn
  }
}

# ECS 

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
  roles      = [data.aws_iam_role.ecs_task_execution_role.name]
  policy_arn = "arn:aws:iam::aws:policy/AmazonEC2ContainerRegistryReadOnly"
}


# ECS cluster
resource "aws_ecs_cluster" "event_cluster" {
  name = "event-cluster"

  tags = {
    Name = "Event-ECS-Cluster"
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
      name      = "event-app"
      image     = "605134473022.dkr.ecr.ap-northeast-2.amazonaws.com/junglegym-test/nginx"
      essential = true
      portMappings = [
        {
          containerPort = 80
          hostPort      = 80
        }
      ]
    }
  ])


  lifecycle {
    create_before_destroy = true 
  }


  tags = {
    Name = "Event-Task-Definition"
  }
}

# ECS task definition & service 
resource "aws_ecs_service" "event_service" {
  name            = "event-service"
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
    container_name   = "event-app"
    container_port   = 80
  }

  deployment_controller {
    type = "ECS"
  }

  force_new_deployment = false    

  tags = {
    Name = "Event-ECS-Service"
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
    from_port   = 0
    to_port     = 0
    protocol    = "-1"
    cidr_blocks = ["0.0.0.0/0"]
  }

  tags = {
    Name = "Event-vpc-ecs-sg"
  }
}




# NAT Gateway security group
resource "aws_security_group" "sg_nat" {
  vpc_id = aws_vpc.junglegym_event_vpc.id

  ingress {
    from_port   = 0
    to_port     = 0
    protocol    = "-1"
    cidr_blocks = ["10.1.0.0/16"]  
  }

  egress {
    from_port   = 0
    to_port     = 0
    protocol    = "-1"
    cidr_blocks = ["0.0.0.0/0"]
  }

  tags = {
    Name = "Event-vpc-nat-sg"
  }
}



# Redis
# Redis security group
resource "aws_security_group" "sg_redis" {
  vpc_id = aws_vpc.junglegym_event_vpc.id

  ingress {
    from_port       = 6379
    to_port         = 6379
    protocol        = "tcp"
    security_groups = [aws_security_group.sg_ecs.id]  
  }

  egress {
    from_port   = 0
    to_port     = 0
    protocol    = "-1"
    cidr_blocks = ["0.0.0.0/0"]
  }

  tags = {
    Name = "Event-vpc-redis-sg"
  }
}

# Redis subnet group (DB subnet)
resource "aws_elasticache_subnet_group" "redis_subnet_group" {
  name       = "event-redis-subnet-group"
  subnet_ids = [aws_subnet.private_a_2.id, aws_subnet.private_c_2.id] 

  tags = {
    Name = "Event-Redis-Subnet-Group"
  }
}

# Redis ElastiCache Cluster
resource "aws_elasticache_replication_group" "redis" {
  replication_group_id       = "event-redis-cluster"
  description                = "Redis replication group for event system"  
  engine                     = "redis"
  node_type                  = "cache.t3.micro"
  num_node_groups            = 1  
  replicas_per_node_group    = 1  
  automatic_failover_enabled = true  
  parameter_group_name       = "default.redis7"
  subnet_group_name          = aws_elasticache_subnet_group.redis_subnet_group.name 
  security_group_ids         = [aws_security_group.sg_redis.id]

  tags = {
    Name = "Event-Redis-Replication-Group"
  }
}

