
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
    Name = "terraform-junglegym-event-vpc"
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

# VPC Endpoint(VPC gateway) for S3 (ECR이 S3를 사용하므로 추가 필요)
resource "aws_vpc_endpoint" "s3" {
  vpc_id       = aws_vpc.junglegym_event_vpc.id
  service_name = "com.amazonaws.ap-northeast-2.s3"
  vpc_endpoint_type = "Gateway"

  tags = {
    Name = "terraform-Event-S3-Endpoint"
  }

   # `depends_on`을 통해 라우팅 테이블이 먼저 생성되도록 보장
  depends_on = [
    aws_route_table.private_rt_a,
    aws_route_table.private_rt_c
  ]
}


# VPC Endpoint(VPC Gateway) for ECR API
resource "aws_vpc_endpoint" "ecr_api" {
  vpc_id            = aws_vpc.junglegym_event_vpc.id
  service_name      = "com.amazonaws.ap-northeast-2.ecr.api"
  vpc_endpoint_type = "Interface"
  subnet_ids        = [aws_subnet.private_a_1.id, aws_subnet.private_c_1.id]
  security_group_ids = [aws_security_group.sg_vpc_endpoint.id]

  tags = {
    Name = "terraform-Event-ECR-API-Endpoint"
   #해당 부분이 가용영역 내에 ecs와 redis가 vpc gateway 를 통해 인터넷 없이도  >연결됨
  }
}

# VPC Endpoint(VPC gateway) for ECR Docker (이미지 다운로드를 위한 연결)
resource "aws_vpc_endpoint" "ecr_dkr" {
  vpc_id            = aws_vpc.junglegym_event_vpc.id
  service_name      = "com.amazonaws.ap-northeast-2.ecr.dkr"
  vpc_endpoint_type = "Interface"
  subnet_ids        = [aws_subnet.private_a_1.id, aws_subnet.private_c_1.id]
  security_group_ids = [aws_security_group.sg_vpc_endpoint.id]

  tags = {
    Name = "terraform-Event-ECR-docker-Endpoint"
  }
}



# VPC Endpoint for security group
resource "aws_security_group" "sg_vpc_endpoint" {
  vpc_id = aws_vpc.junglegym_event_vpc.id

  ingress {
    from_port       = 443
    to_port         = 443
    protocol        = "tcp"
    security_groups = [aws_security_group.sg_ecs.id] # ECS에서 접근 허용
  }

  egress {
    from_port   = 0
    to_port     = 0
    protocol    = "-1"
    cidr_blocks = ["0.0.0.0/0"]
  }

  tags = {
    Name = "terraform-Event-VPC-Endpoint-SG"
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
    Name = "terraform-event-vpc-alb-sg"
  }
}


# ALB - Application Load Balancer
resource "aws_lb" "event_alb" {
  name               = "terraform-event-alb"
  internal           = false  
  load_balancer_type = "application"
  security_groups    = [aws_security_group.sg_alb.id]  
  subnets           = [aws_subnet.public_a.id, aws_subnet.public_c.id]  

  tags = {
    Name = "terraform-event-ALB"
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
    Name = "terraform-event-alb-target-group"
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
  roles      = [data.aws_iam_role.ecs_task_execution_role.name]
  policy_arn = "arn:aws:iam::aws:policy/AmazonEC2ContainerRegistryReadOnly"
}

# 추가적으로 S3 접근 권한 부여
resource "aws_iam_policy" "ecs_task_s3_policy" {
  name        = "ecs-task-s3-policy"
  description = "Allow ECS Task to access S3 for ECR"

  policy = jsonencode({
    Version = "2012-10-17"
    Statement = [
      {
        Effect = "Allow"
        Action = [
          "s3:GetObject",
          "s3:ListBucket"
        ]
        Resource = "*"
      }
    ]
  })
}

# ECS Task Role에 S3 접근 정책 연결
resource "aws_iam_policy_attachment" "ecs_task_execution_role_s3_policy" {
  name       = "ecs-task-execution-role-s3-policy"
  roles      = [data.aws_iam_role.ecs_task_execution_role.name]
  policy_arn = aws_iam_policy.ecs_task_s3_policy.arn
}











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
        { name = "DB_PORT", value = "3306" },
        { name = "DB_USER", value = "root" }, 
        { name = "DB_PASSWORD", value = "Wjdrmfwla123!" } 
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
}

# ECS task definition & service 
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

  force_new_deployment = false    

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
    security_groups = []
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
    Name = "terraform-event-vpc-nat-sg"
  }
}



# Redis
# Redis security group
resource "aws_security_group" "sg_redis" {
  vpc_id = aws_vpc.junglegym_event_vpc.id
  
  # ECS 에서 Redis로 들어오는 요청 허용
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
    Name = "terraform-event-vpc-redis-sg"
  }
}

# Redis subnet group (DB subnet)
resource "aws_elasticache_subnet_group" "redis_subnet_group" {
  name       = "terraform-event-redis-subnet-group"
  subnet_ids = [aws_subnet.private_a_2.id, aws_subnet.private_c_2.id] 

  tags = {
    Name = "terraform-event-redis-subnet-group"
  }
}

# Redis ElastiCache Cluster
resource "aws_elasticache_replication_group" "redis" {
  replication_group_id       = "terraform-event-redis-cluster"
  description                = "Redis replication group for event system"  
  engine                     = "redis"
  node_type                  = "cache.t3.micro"
  num_node_groups            = 1  
  replicas_per_node_group    = 1  
  automatic_failover_enabled = true  
  parameter_group_name       = "default.redis7"
  subnet_group_name          = aws_elasticache_subnet_group.redis_subnet_group.name 
  security_group_ids         = [aws_security_group.sg_redis.id]

  # 이미 생성된 리소스가 있으면 중복 생성하지 않도록 lifecycle 설정
  lifecycle {
    prevent_destroy = true
  }

  tags = {
    Name = "Event-Redis-Replication-Group"
  }
}





# DB - RDS   2/19에 반영한 것
# 25/2/19해당 부분 시크릿 매니저 db 유저네임과 패스워드 참조하도록 설정해야함


# create db(rds) instance
resource "aws_db_instance" "event_rds" {
  identifier           = "event-db"
  engine              = "mysql"
  engine_version      = "8.0"
  instance_class      = "db.t3.micro"
  allocated_storage   = 20
  storage_type        = "gp2"
  db_subnet_group_name = aws_db_subnet_group.event_db_subnet_group.name
  publicly_accessible = false
  vpc_security_group_ids = [aws_security_group.sg_db.id]
  multi_az           = true 
  
  username = "root" 
  password = "Wjdrmfwla123!"  

  #AWS secrets manager에서 이름과 패스워드 참조해서 사용됨
#  username = jsondecode(aws_secretsmanager_secret_version.rds_secret_version.secret_string)["username"]
#  password = jsondecode(aws_secretsmanager_secret_version.rds_secret_version.secret_string)["password"]  
 
  tags = {
    Name = "terraform-event-RDS"
  }
}



# db(RDS) subnet_group 
resource "aws_db_subnet_group" "event_db_subnet_group" {
  name       = "terraform-event-db-subnet-group"
  subnet_ids = [aws_subnet.private_a_2.id, aws_subnet.private_c_2.id] 

  tags = {
    Name = "terraform-event-db-rds-subnet-group"
  }
}


# RDS 보안 그룹 (MySQL 접속을 허용)
resource "aws_security_group" "sg_db" {
  vpc_id = aws_vpc.junglegym_event_vpc.id

  # ECS에서 RDS로 접근 허용 (MySQL 3306 포트)
  ingress {
    from_port       = 3306
    to_port         = 3306
    protocol        = "tcp"
    security_groups = [aws_security_group.sg_ecs.id] 
  }

  # 아웃바운드 트래픽 허용 (필요에 따라 조정 가능)
  egress {
    from_port   = 0
    to_port     = 0
    protocol    = "-1"
    cidr_blocks = ["0.0.0.0/0"]
  }

  tags = {
    Name = "terraform-event-db-rds-security-group"
  }
}



