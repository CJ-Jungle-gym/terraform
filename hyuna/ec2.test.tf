provider "aws" {
  region = "ap-northeast-2"
}

resource "aws_instance" "test_ec2" {
  ami           = "ami-0c55b159cbfafe1f0"  
  instance_type = "t2.micro"

  tags = {
    Name = "Terraform-Test-EC2"
  }
}

