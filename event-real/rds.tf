# rds.tf
# DB - RDS   2/20에 반영한 것
# 25/2/20 해당 부분 시크릿 매니저 db 유저네임과 패스워드 참조하도록 설정해야함

# RDS Subnet Group
resource "aws_db_subnet_group" "event_db_subnet_group" {
  name       = "terraform-event-rds-postgre-subnet-group"
  subnet_ids = [aws_subnet.private_a_2.id, aws_subnet.private_c_2.id]

  # 🔥 **이미 존재하는 경우 변경을 무시 (ignore_changes)**
  lifecycle {
    ignore_changes = [name]
  }

  tags = {
    Name = "terraform-event-db-rds-subnet-group"
  }
}

# RDS Security Group
resource "aws_security_group" "sg_db" {
  vpc_id = aws_vpc.junglegym_event_vpc.id
  name        = "terraform-20250221025324407300000006"
  description = "Managed by Terraform"
  # 기존 규칙을 삭제하지 않도록 설정
  revoke_rules_on_delete = false




  # ECS에서 RDS로 접근 허용 (PostgreSQL 5432포트)
  ingress {
    from_port       = 5432
    to_port         = 5432
    protocol        = "tcp"
    security_groups = [aws_security_group.sg_ecs.id]
  }



  # 콘솔에서 추가한 DMS 서브넷 접근 규칙
  ingress {
    description = "From PROD DB Subnet for DMS"
    from_port   = 5432
    to_port     = 5432
    protocol    = "tcp"
    cidr_blocks = ["10.2.0.192/27", "10.2.0.224/27"]
  }

  # 콘솔에서 추가한 OpenVPN 접근 규칙
  ingress {
    description = "From PRD OpenVPN"
    from_port   = 5432
    to_port     = 5432
    protocol    = "tcp"
    cidr_blocks = ["10.2.0.54/32"]
  }

  ingress {
    description      = "From OpenVPN"
    from_port        = 5432
    to_port          = 5432
    protocol         = "tcp"
    security_groups  = [aws_security_group.event_bastion_sg.id]
  }

  # VPC 내부 트래픽만 허용 (보안 강화)
  egress {
    from_port   = 0
    to_port     = 0
    protocol    = "-1"
    cidr_blocks = ["10.1.0.0/16"]
  }

  lifecycle {
    ignore_changes = [ingress, egress]
  }
  depends_on = [aws_security_group.event_bastion_sg]

  tags = {
    Name = "terraform-event-db-rds-security-group"
  }
}

# bastion 서버 보안그룹 지정
resource "aws_security_group" "event_bastion_sg" {
  name        = "event-bastion-sg"
  description = "event-bastion-sg"
  vpc_id      = aws_vpc.junglegym_event_vpc.id

  # 🔹 인바운드 규칙 (SSH: 22포트, 0.0.0.0/0 허용)
  ingress {
    description = "Allow SSH from anywhere"
    from_port   = 22
    to_port     = 22
    protocol    = "tcp"
    cidr_blocks = ["0.0.0.0/0"]
  }

  # 🔹 아웃바운드 규칙 (모든 트래픽 허용)
  egress {
    description = "Allow all outbound traffic"
    from_port   = 0
    to_port     = 0
    protocol    = "-1"
    cidr_blocks = ["0.0.0.0/0"]
  }

  tags = {
    Name = "event-bastion-sg"
  }

  lifecycle {
    ignore_changes = [description, ingress, egress]
  }
}





# RDS Multi-AZ Instance
resource "aws_db_instance" "event_rds" {
  identifier          = "event-postgres-db"
  engine              = "postgres"
  engine_version      = "15.7"
  instance_class      = "db.t3.small"
  allocated_storage   = 20
  storage_type        = "gp2"
  db_subnet_group_name = aws_db_subnet_group.event_db_subnet_group.name
  publicly_accessible = false
  vpc_security_group_ids = [aws_security_group.sg_db.id]
  multi_az           = true


  # Secrets Manager에서 DB 사용자 인증
#  username = jsondecode(aws_secretsmanager_secret_version.rds_secret_version.secret_string)["username"]
#  password = jsondecode(aws_secretsmanager_secret_version.rds_secret_version.secret_string)["password"]

  username = "root"
  password = "wjdrmfwla123"

  tags = {
    Name = "terraform-event-RDS"
  }
}




#  event-rds가 생성된 후 ASM 생성 (종속성 적용)
resource "aws_secretsmanager_secret" "rds_secret" {
  name       = "event-rds-postgre"
  description = "event vpc postgre RDS 자격증명 저장"
  kms_key_id = aws_kms_key.event_rds_kms.arn

  #  `event-rds` 생성 후 실행하도록 종속성 적용

  tags = {
     Name = "event-rds-postgre-secret"
  }

  depends_on = [aws_db_instance.event_rds]
}

resource "aws_secretsmanager_secret_version" "rds_secret_version" {
  secret_id     = aws_secretsmanager_secret.rds_secret.id
  secret_string = jsonencode({
    username = "root"
    password = "wjdrmfwla123"
  })

   # ✅ RDS 생성 이후 실행
  depends_on = [aws_db_instance.event_rds]
}


# KMS 설정
resource "aws_kms_key" "event_rds_kms" {
  description             = "Rds Postgresql Key 최종"
  enable_key_rotation     = true
  deletion_window_in_days = 7

  tags = {
    Name = "event-rds-postgresql-kms"
  }
}

resource "aws_kms_alias" "event_rds_kms_alias" {
  name          = "alias/Event-Rds-Postgre-Key"
  target_key_id = aws_kms_key.event_rds_kms.id
}



