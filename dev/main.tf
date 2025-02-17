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

# Database
module "db" {
  source = "terraform-aws-modules/rds/aws"

  identifier = "junglegym-rds"

  engine            = "mysql"
  engine_version    = "8.0"
  instance_class    = "db.t3.micro"
  allocated_storage = 20

  db_name  = "junglegymrds"
  username = "root"
  port     = "3306"

  iam_database_authentication_enabled = true

  vpc_security_group_ids = [aws_security_group.rds_sg.id]

  family                = "mysql8.0"
  major_engine_version  = "8.0"

  # DB subnet group
  create_db_subnet_group = true
  subnet_ids = [
    aws_subnet.private_a_1.id,
    aws_subnet.private_a_2.id,
    aws_subnet.private_c_1.id,
    aws_subnet.private_c_2.id
  ]

  tags = {
    Owner       = "user"
    Environment = "dev"
  }
}

# Security Groups
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
    Name = "ec2-sg"
  }
}

resource "aws_security_group" "rds_sg" {
  name        = "rds-sg"
  description = "RDS Security Group"
  vpc_id      = aws_vpc.junglegym_dev_vpc.id

  ingress {
    from_port       = 3306
    to_port         = 3306
    protocol        = "tcp"
    security_groups = [aws_security_group.ec2_sg.id]
  }

  egress {
    from_port   = 0
    to_port     = 0
    protocol    = "-1"
    cidr_blocks = ["0.0.0.0/0"]
  }

  tags = {
    Name = "rds-sg"
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
        Resource = "arn:aws:rds-db:ap-northeast-2:${data.aws_caller_identity.current.account_id}:dbuser:${module.db.db_instance_identifier}/iam_user"
      }
    ]
  })
}


#DynamoDB

module "dynamodb_table" {
  source   = "terraform-aws-modules/dynamodb-table/aws"

  name     = "junglegym-dynamodb-maintable"
  hash_key = "id"


  attributes = [
    {
      name = "id"
      type = "N"
    }
  ]

  tags = {
    Terraform   = "true"
    Environment = "staging"
  }
}

