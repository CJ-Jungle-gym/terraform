# ✅ 이벤트 VPC 데이터 참조 (main.tf에서 생성됨)
data "aws_vpc" "event_vpc" {
  id = "vpc-061260f6e81150f73" # 이벤트 VPC ID (콘솔에서 확인한 값)
}



# ✅ 운영 VPC 데이터 참조 (기존 운영 VPC)
data "aws_vpc" "prod_vpc" {
  id = "vpc-04ea2e3f360a8bc9f" # 운영 VPC ID (콘솔에서 확인한 값)
}



# ✅ VPC Peering 생성 (이벤트 VPC → 운영 VPC)
resource "aws_vpc_peering_connection" "event_prod_peering" {
  vpc_id        = data.aws_vpc.event_vpc.id  # 요청자: 이벤트 VPC
  peer_vpc_id   = data.aws_vpc.prod_vpc.id  # 수락자: 운영 VPC
  
  #요청자도 자동승인 
  auto_accept   = true

  tags = {
    Name = "event-prod-peering"
  }

  depends_on = [data.aws_vpc.event_vpc, data.aws_vpc.prod_vpc]
}

# ✅ 운영 VPC에서 VPC Peering 요청 승인
resource "aws_vpc_peering_connection_accepter" "event_prod_accept" {
  vpc_peering_connection_id = aws_vpc_peering_connection.event_prod_peering.id
  auto_accept               = true

  tags = {
    Name = "event-prod-peering-accept"
  }
}

# ✅ 이벤트 VPC 라우팅 테이블 설정 (Private DB Route Table)
resource "aws_route" "event_to_prod" {
  
  # 이벤트계 private db route table id 
  route_table_id         = "rtb-09dfa17b940475ecc" 
  
  # 운영계 vpc cidr 
  destination_cidr_block = data.aws_vpc.prod_vpc.cidr_block  
  vpc_peering_connection_id = aws_vpc_peering_connection.event_prod_peering.id
}

# ✅ 운영 VPC 라우팅 테이블 설정 (Private DB Route Table)
resource "aws_route" "prod_to_event" {
  
  # 운영계 private db route table id
  route_table_id         = "rtb-00a26154d5b15432e" 
  
  # 이벤트 vpc cidr 
  destination_cidr_block = data.aws_vpc.event_vpc.cidr_block 
  vpc_peering_connection_id = aws_vpc_peering_connection.event_prod_peering.id
}

# ✅ 퍼블릭 서브넷 라우팅 테이블 설정 (운영 VPC → 이벤트 VPC)
resource "aws_route" "prod_public_to_event" {
  
  # 운영계 public route table id
  route_table_id         = "rtb-0b33b65312d67201c" 
  
  # 이벤트 vpc cidr 
  destination_cidr_block = data.aws_vpc.event_vpc.cidr_block  
  vpc_peering_connection_id = aws_vpc_peering_connection.event_prod_peering.id
}

# ✅ 필요 시 이벤트 VPC 퍼블릭 서브넷에서도 운영 VPC로 라우트 추가
#resource "aws_route" "event_public_to_prod" {
#  route_table_id         = "rtb-02105fa7162c6b986"  # 이벤트 퍼블릭 라우팅 테이블 ID (필요 시 콘솔에서 확인)
#  destination_cidr_block = data.aws_vpc.prod_vpc.cidr_block  # 운영 VPC CIDR
#  vpc_peering_connection_id = aws_vpc_peering_connection.event_prod_peering.id
#}

# ✅ VPC 피어링을 통한 DNS 확인 활성화
resource "aws_vpc_peering_connection_options" "event_prod_peering_dns" {
  vpc_peering_connection_id = aws_vpc_peering_connection.event_prod_peering.id

  requester {
    allow_remote_vpc_dns_resolution = true
  }

  accepter {
    allow_remote_vpc_dns_resolution = true
  }
}

