# event dms endpoint
resource "aws_dms_endpoint" "source_endpoint" {
  endpoint_id   = "event-postgres-db"
  endpoint_type = "source"
  engine_name   = "postgres"
  username      = "root"
  password      = "wjdrmfwla123"
  server_name   = "event-postgres-db.cnwi6euwsod1.ap-northeast-2.rds.amazonaws.com"
  port          = 5432
  database_name = "eventdb"
  ssl_mode      = "require"

  kms_key_arn = "arn:aws:kms:ap-northeast-2:605134473022:key/4c833ac4-7ad7-489f-ba6a-204e9a872ab1"

  tags = {
    Name = "DMS Source Endpoint"
  }

  depends_on = [aws_dms_replication_instance.dms_event_to_prod]
}

# prod dms endpoint 
resource "aws_dms_endpoint" "target_endpoint" {
  endpoint_id   = "prod-postgres-db"
  endpoint_type = "target"
  engine_name   = "postgres"
  username      = "dbadmin"
  password      = "SecurePassword123"
  server_name   = "prod-db.cnwi6euwsod1.ap-northeast-2.rds.amazonaws.com"
  port          = 5432
  database_name = "proddb"
  ssl_mode      = "require"

  kms_key_arn = "arn:aws:kms:ap-northeast-2:605134473022:key/4c833ac4-7ad7-489f-ba6a-204e9a872ab1"


  tags = {
    Name = "DMS Target Endpoint"
  }

  depends_on = [aws_dms_replication_instance.dms_event_to_prod]
}

