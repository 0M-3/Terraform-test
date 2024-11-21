variable "aws_access_key" {}
variable "aws_secret_key" {}
variable "region" {}


# Provider

provider "aws" {
    region= var.region
    access_key= var.aws_access_key
    secret_key= var.aws_secret_key
}

# resource "aws_instance" "my-first-server" {
#     ami = "ami-0ea3c35c5c3284d82"
#     instance_type = "t3.micro"
# }

#Create a VPC
resource "aws_vpc" "prod-vpc" {
  cidr_block = "10.0.0.0/16"
}

# Create an internet gateway

resource "aws_internet_gateway" "prod-gateway" {
  vpc_id = aws_vpc.prod-vpc.id
}

resource "aws_route_table" "prod-route-table" {
  vpc_id = aws_vpc.prod-vpc.id

  route {
    cidr_block = "0.0.0.0/0"
    gateway_id = aws_internet_gateway.prod-gateway.id
  }

  route {
    ipv6_cidr_block        = "::/0"
    gateway_id = aws_internet_gateway.prod-gateway.id
  }

  tags = {
    Name = "prod"
  }
}

# Create an AWS Subnet

resource "aws_subnet" "subnet-1" {
  vpc_id                  = aws_vpc.prod-vpc.id
  cidr_block              = "10.0.1.0/24"
  availability_zone       = "us-east-2a"

  tags = {
    Name = "prod-subnet"
  }
}

# Associate Subnet with Route Table

resource "aws_route_table_association" "a" {
  subnet_id      = aws_subnet.subnet-1.id
  route_table_id = aws_route_table.prod-route-table.id
}

# Create a Security Group to allow port 22,80 and 443

resource "aws_security_group" "allow_web" {
  name        = "allow_web_traffic"
  description = "Allow TLS inbound traffic and all outbound traffic"
  vpc_id      = aws_vpc.prod-vpc.id

  ingress {
    description = "HTTPS"
    from_port   = 443
    to_port     = 443
    protocol    = "tcp"
    cidr_blocks = ["0.0.0.0/0"]

  } 
  
  ingress {
      description = "HTTP"
      from_port   = 80
      to_port     = 80
      protocol    = "tcp"
      cidr_blocks = ["0.0.0.0/0"]
  }

  ingress {
    description ="SSH"
    from_port = 22
    to_port = 22
    protocol = "tcp"
    cidr_blocks = ["0.0.0.0/0"]
  }

  egress {
    from_port   = 0
    to_port     = 0
    protocol    = "-1"
    cidr_blocks = ["0.0.0.0/0"]
  }

  tags = {
    Name = "allow_web"
  }
}

# Create a network interface with an IP in the subnet

resource "aws_network_interface" "web-server-nic" {
  subnet_id       = aws_subnet.subnet-1.id
  private_ips     = ["10.0.1.50"]
  security_groups = [aws_security_group.allow_web.id]
}

# Create an Elastic IP and associate it with the network interface
resource "aws_eip" "one" {
  domain                    = "vpc"
  network_interface         = aws_network_interface.web-server-nic.id
  associate_with_private_ip = "10.0.1.50"
  depends_on = [aws_internet_gateway.prod-gateway, aws_instance.web-server-instance]
}

output "server_public_ip" {
  value       = aws_eip.one.public_ip
  depends_on = [aws_eip.one]
}


# Create an Ubuntu Server
resource "aws_instance" "web-server-instance" {
  ami = "ami-0ea3c35c5c3284d82"
  instance_type = "t2.micro"
  availability_zone = "us-east-2a"
  key_name = "EC2-TF-test-key"

  network_interface {
    device_index = 0
    network_interface_id = aws_network_interface.web-server-nic.id
  }
  user_data = <<-EOF
              #!/bin/bash
              sudo apt update -y
              sudo apt install apache2 -y
              sudo systemctl start apache2
              sudo bash -c 'echo hello world on your first web server > /var/www/html/index.html'
              EOF
  tags = {
    Name = "web-server"
  }
}