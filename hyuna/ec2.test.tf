provider "aws" {
  region = "ap-northeast-2"
}

# ✅ 기존 VPC 참조
data "aws_vpc" "existing_vpc" {
  id = "vpc-061260f6e81150f73"
}

# ✅ 해당 VPC의 기본 서브넷 가져오기
data "aws_subnet" "default_subnet" {
  vpc_id = data.aws_vpc.existing_vpc.id
  filter {
    name   = "default-for-az"
    values = ["true"]
  }
}

# ✅ 보안 그룹 생성 (SSH 허용)
resource "aws_security_group" "hyuna-lambda-sg" {
  vpc_id = data.aws_vpc.existing_vpc.id

  ingress {
    from_port   = 22
    to_port     = 22
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
    Name = "hyuna-lambda-sg"
  }
}

# ✅ EC2 인스턴스 생성 (이름: hyuna_lambda_test)
resource "aws_instance" "hyuna_lambda_test" {
  ami             = "ami-0c55b159cbfafe1f0"  # Amazon Linux 2 AMI
  instance_type   = "t2.micro"
  subnet_id       = data.aws_subnet.default_subnet.id
  security_groups = [aws_security_group.hyuna-lambda-sg.name]

  tags = {
    Name = "hyuna_lambda_test"
  }
}
