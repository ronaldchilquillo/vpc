provider "aws" {
  region     = "us-east-1" ##Enter your region here
  access_key = "AKIA2QSRDKVMZRFTMYON"
  secret_key = "NqDQcsj1IM/AWVuHW5YWLHtXBJEaMgrr8FuL19bp"
}


# 1. Creating a VPC

resource "aws_vpc" "A" {
  cidr_block = "10.0.0.0/16"

  tags = {
    name = "vpcpointer"
  }
}

# 2. Creating an intenet Gateway

resource "aws_internet_gateway" "GW_vpcpointer" {
  vpc_id = aws_vpc.A.id

  tags = {
    Name = "IG_vpcpointer"
  }
}

# 3. Create a Route Table

resource "aws_route_table" "RT_vpcpointer" {

  vpc_id = aws_vpc.A.id

  route {
    cidr_block = "0.0.0.0/0"
    gateway_id = aws_internet_gateway.GW_vpcpointer.id

  }
  route {
    ipv6_cidr_block = "::/0"
    gateway_id      = aws_internet_gateway.GW_vpcpointer.id
  }

  tags = {
    Name = "RT_vpcpointer"
  }
}

# 4. Creating a Subnet

resource "aws_subnet" "Subnet_vpcpointer" {

  vpc_id            = aws_vpc.A.id
  cidr_block        = "10.0.0.0/24"
  availability_zone = "us-east-1a"
  depends_on        = [aws_internet_gateway.GW_vpcpointer]

  tags = {
    Name = "Subnet_vpcpointer"
  }
}

resource "aws_subnet" "Subnet_vpcpointertwo" {

  vpc_id            = aws_vpc.A.id
  cidr_block        = "10.0.1.0/24"
  availability_zone = "us-east-1a"
  depends_on        = [aws_internet_gateway.GW_vpcpointer]

  tags = {
    Name = "Subnet_vpcpointertwo"
  }
}

resource "aws_subnet" "Subnet_vpcpointerthree" {

  vpc_id            = aws_vpc.A.id
  cidr_block        = "10.0.2.0/24"
  availability_zone = "us-east-1a"
  depends_on        = [aws_internet_gateway.GW_vpcpointer]

  tags = {
    Name = "Subnet_vpcpointerthree"
  }
}

# 5. Associate Subnet with Route Table

resource "aws_route_table_association" "RT_to_Subnet" {

  subnet_id      = aws_subnet.Subnet_vpcpointer.id
  route_table_id = aws_route_table.RT_vpcpointer.id
}

# 6. Create a Security Group to Allow posrts : 22, 80, 443
resource "aws_security_group" "SG_vpcpointer" {

  name        = "SG_vpcpointer"
  description = "Allow SSH, HTTP, HTTPS inbound traffic"
  vpc_id      = aws_vpc.A.id

  ingress {
    description = "HTTPS from VPC"
    from_port   = 443
    to_port     = 443
    protocol    = "tcp"
    cidr_blocks = ["0.0.0.0/0"]
  }
  ingress {
    description = "HTTP from VPC"
    from_port   = 80
    to_port     = 80
    protocol    = "tcp"
    cidr_blocks = ["0.0.0.0/0"]
  }

  ingress {
    description = "SSH from VPC"
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
    Name = "SG_vpcpointer"
  }
}

# 7. Assign ENI with Ip

resource "aws_network_interface" "ENI_A" {

  subnet_id       = aws_subnet.Subnet_vpcpointer.id
  private_ips     = ["10.0.0.10"]
  security_groups = [aws_security_group.SG_vpcpointer.id]
}


# 8. Assign Elastic Ip to ENI
resource "aws_eip" "EIP_A" {

  # vpc                       = true
  network_interface         = aws_network_interface.ENI_A.id
  associate_with_private_ip = "10.0.0.10"
  #  depends_on                = [aws_internet_gateway.GW_vpcpointer, aws_instance.Instance_A]

  tags = {
    Name = "EIP_A"
  }
}

# 9. Create IAM Role to access S3
resource "aws_iam_role" "EC2-S3" {
  name = "EC2-S3"

  assume_role_policy = <<EOF
{
  "Version": "2012-10-17",
  "Statement": [
    {
      "Action": "sts:AssumeRole",
      "Principal": {
        "Service": "ec2.amazonaws.com"
      },
      "Effect": "Allow",
      "Sid": ""
    }
  ]
}
EOF

  tags = {
    Name = "EC2-S3"
  }
}

// IAM Profile
resource "aws_iam_instance_profile" "EC2-S3_Profile" {
  name = "EC2-S3_Profile"
  role = aws_iam_role.EC2-S3.name
}

// IAM Policy
resource "aws_iam_role_policy" "EC2-S3_Policy" {
  name = "test_policy"
  role = aws_iam_role.EC2-S3.id

  policy = <<EOF
{
  "Version": "2012-10-17",
  "Statement": [
    {
      "Effect": "Allow",
      "Action": [
        "s3:*"
      ],
      "Resource": "*"
    }
  ]
}
EOF

}


# 10. Create Linux Server and install/enable Apache2
#resource "aws_instance" "Instance_A" {
#  ami                  = "ami-0947d2ba12ee1ff75"
#  instance_type        = "t2.micro"
#  availability_zone    = "us-east-1a"
#  key_name             = "vpcpointer"
#  iam_instance_profile = aws_iam_instance_profile.EC2-S3_Profile.name

#  network_interface {
#    device_index         = 0
#    network_interface_id = aws_network_interface.ENI_A.id
#  }

#  user_data = <<-EOF
#    #!/bin/bash
#    sudo yum update -y
#    sudo yum install -y httpd.x86_64
#    sudo systemctl start httpd.service
#    sudo systemctl enable httpd.service
#    sudo aws s3 sync s3://awsbucketbeta00/website /var/www/html 
#  EOF

#  tags = {
#    Name = "vpcpointer_1.0"
#  }
#}

# 11. Enable VPC Enpoint

resource "aws_vpc_endpoint" "s3" {
  vpc_id       = aws_vpc.A.id
  service_name = "com.amazonaws.us-east-1.s3"

  tags = {
    Name = "test"
  }

}
