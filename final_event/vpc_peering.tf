# 요청자 VPC (Event VPC) - terraform-junglegym-event-vpc\
data "aws_vpc" "requester" {
  id = "vpc-061260f6e81150f73"
}

# 수락자 VPC (Prod VPC) - Prod-Vpc
data "aws_vpc" "accepter" {
  id = "vpc-04ea2e3f360a8bc9f"
}

# VPC Peering 생성
resource "aws_vpc_peering_connection" "event_prod_peering" {
  peer_vpc_id = data.aws_vpc.accepter.id
  vpc_id      = data.aws_vpc.requester.id
  auto_accept = true
  tags = {
    Name = "event-prod-peering"
  }
}

# 요청자 VPC 라우트 설정
# Event-Private-DB-Route-Table
resource "aws_route" "requester_to_accepter" {
  route_table_id = "rtb-09dfa17b940475ecc"
  #prod vpc cidr
  destination_cidr_block    = "10.2.0.0/24"
  vpc_peering_connection_id = aws_vpc_peering_connection.event_prod_peering.id

  depends_on = [aws_vpc_peering_connection.event_prod_peering]
}

# 수락자 VPC 라우트 설정
# Prod-Private-DB-Route-Table
resource "aws_route" "accepter_to_requester" {
  route_table_id = "rtb-00a26154d5b15432e"
  #event vpc cidr
  destination_cidr_block    = "10.1.0.0/16"
  vpc_peering_connection_id = aws_vpc_peering_connection.event_prod_peering.id

  depends_on = [aws_vpc_peering_connection.event_prod_peering]
}

# DNS 해상도 활성화 (요청자 VPC)
resource "aws_vpc_peering_connection_options" "requester_dns" {
  vpc_peering_connection_id = aws_vpc_peering_connection.event_prod_peering.id
  requester {
    allow_remote_vpc_dns_resolution = false
  }

  depends_on = [
    aws_vpc_peering_connection.event_prod_peering,
    aws_route.requester_to_accepter,
    aws_route.accepter_to_requester
  ]
}

# DNS 해상도 활성화 (수락자 VPC)
resource "aws_vpc_peering_connection_options" "accepter_dns" {
  vpc_peering_connection_id = aws_vpc_peering_connection.event_prod_peering.id
  accepter {
    allow_remote_vpc_dns_resolution = false
  }

  depends_on = [
    aws_vpc_peering_connection.event_prod_peering,
    aws_route.requester_to_accepter,
    aws_route.accepter_to_requester
  ]
}

