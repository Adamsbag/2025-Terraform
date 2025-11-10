provider "aws" {
  region = "us-east-1"
}

# 1. Create vpc
resource "aws_vpc" "main_vpc" {
  cidr_block = "10.0.0.0/16"
  tags = {
    Name = "Production_vpc"
  }
}

# 2. Create Internet Gateway
resource "aws_internet_gateway" "igw" {
  vpc_id = aws_vpc.main_vpc.id
  tags = {
    Name = "Main_IGW"
  }
}

# 3. Create Custom Route Table
resource "aws_route_table" "production_route_table" {
  vpc_id = aws_vpc.main_vpc.id

  route {
    cidr_block = "0.0.0.0/0"
    gateway_id = aws_internet_gateway.igw.id
  }

  tags = {
    Name = "Production_Route_Table"
  }
}

# 4. Create a Subnet
resource "aws_subnet" "main_subnet" {
  vpc_id            = aws_vpc.main_vpc.id
  cidr_block        = "10.0.1.0/24"
  availability_zone = "us-east-1a"
  tags = {
    Name = "Production_Subnet"
  }
}

# 5. Associate subnet with Route Table
resource "aws_route_table_association" "rta" {
  subnet_id      = aws_subnet.main_subnet.id
  route_table_id = aws_route_table.production_route_table.id
}

# 6. Create Security Group to allow port 22,80,443
resource "aws_security_group" "allow_web" {
  name        = "allow_ssh_http_https"
  description = "Allow SSH, HTTP, and HTTPS traffic"
  vpc_id      = aws_vpc.main_vpc.id

  ingress {
    description = "Allow SSH"
    from_port   = 22
    to_port     = 22
    protocol    = "tcp"
    cidr_blocks = ["0.0.0.0/0"]
  }
  ingress {
    description = "Allow HTTP"
    from_port   = 80
    to_port     = 80
    protocol    = "tcp"
    cidr_blocks = ["0.0.0.0/0"]
  }
  ingress {
    description = "Allow HTTPS"
    from_port   = 443
    to_port     = 443
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
    Name = "Allow_SSH_HTTP_HTTPS"
  }
}
# 7. Create a network interface with an ip in the subnet that was created in step 4
resource "aws_network_interface" "web_eni" {
  subnet_id       = aws_subnet.main_subnet.id
  private_ips     = ["10.0.1.50"]
  security_groups = [aws_security_group.allow_web.id]
  tags = {
    Name = "Web_Network_Interface"
  }
}
# 8. Assign an elastic IP to the network interface created in step 7
resource "aws_eip" "web_eip" {
  domain = "vpc"
  network_interface  = aws_network_interface.web_eni.id
  associate_with_private_ip = "10.0.1.50"
  depends_on = [ aws_internet_gateway.igw ]
  tags = {
    Name = "Web_Elastic_IP"
  }
}

# 9. Create Ubuntu server and install/enable apache2
resource "aws_instance" "app_server" {
  ami           = "ami-0157af9aea2eef346" # Ubuntu Server 22.04 LTS (HVM), SSD Volume Type
  instance_type = "t2.micro"
  availability_zone = "us-east-1a"
  key_name = "main-key" # Replace with your key pair name
 
  network_interface {
    network_interface_id = aws_network_interface.web_eni.id
    device_index         = 0
  }
  user_data = <<-EOF
              #!/bin/bash
              apt-get update
              apt-get install -y apache2
              systemctl enable apache2
              systemctl start apache2
              echo "<h1>Welcome to the App Server</h1>" > /var/www/html/index.html
              EOF
  tags = {
    Name = "App_Server"
  }
}

#Adding Comments to test git change detection
# End of main.tf file