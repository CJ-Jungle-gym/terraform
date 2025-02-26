resource "aws_security_group" "dms_event_to_prod_sg" {
  name        = "dms-event-to-prod-replication-sg"
  description = "dms-event-to-prod-replication-sg"
  vpc_id      = "vpc-04ea2e3f360a8bc9f"

  # 인바운드 규칙 (Ingress)
  ingress {
    from_port   = 5432
    to_port     = 5432
    protocol    = "tcp"
    cidr_blocks = ["10.1.2.0/24", "10.1.4.0/24"]
    description = "From Event VPC DB Subnet"
  }

  ingress {
    from_port       = 5432
    to_port         = 5432
    protocol        = "tcp"
    security_groups = ["sg-068e9c06d3af71417"]
    description     = "From PROD VPC DB subnet"
  }

  # 아웃바운드 규칙 (Egress)
  egress {
    from_port       = 5432
    to_port         = 5432
    protocol        = "tcp"
    cidr_blocks     = ["10.1.2.0/24", "10.1.4.0/24"]
    security_groups = ["sg-068e9c06d3af71417"]
  }

  tags = {
    Name = "dms-event-to-prod-replication-sg"
  }

}

