resource "aws_dms_replication_instance" "dms_event_to_prod" {
  replication_instance_id      = "dms-event-to-prod"
  replication_instance_class   = "dms.t3.micro"
  allocated_storage            = 50
  engine_version               = "3.5.3"
  publicly_accessible          = false
  multi_az                     = false
  network_type                 = "IPV4"
  availability_zone            = "ap-northeast-2a"
  replication_subnet_group_id  = "dms-event-to-prod-sbg"
  vpc_security_group_ids       = ["sg-04e1a67df44028014"]
  auto_minor_version_upgrade   = true
  kms_key_arn                  = "arn:aws:kms:ap-northeast-2:605134473022:key/4c833ac4-7ad7-489f-ba6a-204e9a872ab1"
  preferred_maintenance_window = "mon:19:32-mon:20:02"

  tags = {
    description = "dms-event-to-prod"
  }

  depends_on = [aws_security_group.dms_event_to_prod_sg]
}

