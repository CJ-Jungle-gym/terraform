
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


# Internet gateway
resource "aws_internet_gateway" "event_igw" {
  vpc_id = aws_vpc.junglegym_event_vpc.id

  tags = {
    Name = "Event-Internet-Gateway"
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



# Private Subnet A1을private route table A에 적용  (AZ A)
resource "aws_route_table_association" "private_a_1" {
  subnet_id      = aws_subnet.private_a_1.id
  route_table_id = aws_route_table.private_rt_a.id
}

# Private Subnet C1을private route table C에 적용  (AZ C)
resource "aws_route_table_association" "private_c_1" {
  subnet_id      = aws_subnet.private_c_1.id
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
  name        = "terraform-event-tg"
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
  
  # 🔥 **이미 존재하는 경우 변경을 무시 (ignore_changes)**
  lifecycle {
    ignore_changes = [name]
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


