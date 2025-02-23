# redis.tf
# redis subnet group
resource "aws_elasticache_subnet_group" "event_redis_subnet_group" {
  name       = "terraform-event-redis-subnet-group"
  subnet_ids = [aws_subnet.private_a_2.id, aws_subnet.private_c_2.id]

  tags = {
    Name = "terraform-event-redis-subnet-group"
  }

  # 🔥 **이미 존재하는 경우 변경을 무시 (ignore_changes)**
  lifecycle {
    ignore_changes = [name]
  }
}

# Terraform Redis 설정 (멀티 AZ)
resource "aws_elasticache_replication_group" "redis_cluster" {
  replication_group_id       = "terraform-event-redis-cluster"
  description                = "Multi-AZ Redis Cluster"
  node_type                  = "cache.t3.micro"
  num_cache_clusters         = 2
  automatic_failover_enabled = true
  multi_az_enabled           = true
  subnet_group_name          = aws_elasticache_subnet_group.event_redis_subnet_group.name

  security_group_ids         = [aws_security_group.sg_redis.id]

  tags = {
    Name = "terraform-event-redis-cluster"
  }
}

# redis security group
resource "aws_security_group" "sg_redis" {
  vpc_id = aws_vpc.junglegym_event_vpc.id

  # ECS에서 Redis로 접근 허용 (6379 포트)
  ingress {
    from_port       = 6379
    to_port         = 6379
    protocol        = "tcp"
    cidr_blocks     = ["10.1.0.0/16"]
  }

  # 아웃바운드 트래픽 허용 (필요에 따라 조정 가능)
  egress {
    from_port   = 0
    to_port     = 0
    protocol    = "-1"
    cidr_blocks = ["10.1.0.0/16"]
  }


  tags = {
    Name = "terraform-event-redis-security-group"
  }
}



