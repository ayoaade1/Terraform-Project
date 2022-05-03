terraform {
  required_providers {
    aws = {
      version = ">= 2.7.0"
      source  = "hashicorp/aws"
    }
  }
}


provider "aws" {
  region     = "us-east-2"
  access_key = ""
  secret_key = ""

}

/*
resource "aws_vpc" "first-vpc" {
    cidr_block = "10.0.0.0/16"
    tags = {
      Name = "Production"
    }
}


resource "aws_subnet" "subnet_1" {
  vpc_id     = aws_vpc.first-vpc.id
  cidr_block = "10.0.1.0/24"

  tags = {
    Name = "Prod-subnet"
  }
} */
/* resource "aws_instance" "my-first-server" {
    ami = "ami-04505e74c0741db8d"
    instance_type = "t2.micro"
    tags = {
      Name = "Ubuntu"
    }
   
}
  
#resource "<provider>_<resource_type>" "name" {
#  config options......
#  key = "value"
#  key2 = "another value"
#}
*/



# 1. Create a custom VPC

resource "aws_vpc" "tfvpc" {
  cidr_block = "10.0.0.0/16"

  tags = {
    Name = "Prod"
  }
}
# 2. Create Internet gateway

resource "aws_internet_gateway" "tfgw" {
  vpc_id = aws_vpc.tfvpc.id
}
# 3. Create Custom Route Table 

resource "aws_route_table" "tfroutetable" {
  vpc_id = aws_vpc.tfvpc.id

  route {
    cidr_block = "0.0.0.0/0"
    gateway_id = aws_internet_gateway.tfgw.id
  }

  route {
    ipv6_cidr_block = "::/0"
    gateway_id      = aws_internet_gateway.tfgw.id
  }

  tags = {
    Name = "Prod"
  }
}
# 4. Create Subnet 
resource "aws_subnet" "subnet_1" {
  vpc_id            = aws_vpc.tfvpc.id
  cidr_block        = "10.0.1.0/24"
  availability_zone = "us-east-2c"

  tags = {
    Name = "Prod-subnet"
  }
}

# 5. Associate subnet with Route Table 

resource "aws_route_table_association" "assoc" {
  subnet_id      = aws_subnet.subnet_1.id
  route_table_id = aws_route_table.tfroutetable.id
}

# 6. Create Security Group to allow Rouete 22,80,443

resource "aws_security_group" "allow_web" {
  name        = "allow_web_traffic"
  description = "Allow Web inbound traffic"
  vpc_id      = aws_vpc.tfvpc.id

  ingress  {
    description      = "HTTPS"
    from_port        = 443
    to_port          = 443
    protocol         = "tcp"
    cidr_blocks      = ["0.0.0.0/0"]
  }

  ingress {
    description      = "HTTP"
    from_port        = 80
    to_port          = 80
    protocol         = "tcp"
    cidr_blocks      = ["0.0.0.0/0"]
  }

  ingress {
    description      = "SSH"
    from_port        = 22
    to_port          = 22
    protocol         = "tcp"
    cidr_blocks      = ["0.0.0.0/0"]
  }

  egress {
    from_port        = 0
    to_port          = 0
    protocol         = "-1"
    cidr_blocks      = ["0.0.0.0/0"]
  }

  tags = {
    Name = "allow_web"
  }
}
# 7. Create a network interface with ip in th esubnet that was created in step 4 
resource "aws_network_interface" "Web-server-tf" {
  subnet_id       = aws_subnet.subnet_1.id
  private_ips     = ["10.0.1.50"]
  security_groups = [aws_security_group.allow_web.id]


}
# 8. Assign an elastic IP to the network interface created in step 7 

resource "aws_eip" "one" {
  vpc                       = true
  network_interface         = aws_network_interface.Web-server-tf.id
  associate_with_private_ip = "10.0.1.50"
  depends_on                = [aws_internet_gateway.tfgw]
}

output "server_public_ip" {
  value = aws_eip.one.public_ip
}

# 9. create Ubuntu server and install/enable apache2

resource "aws_instance" "web-ami" {
  ami               = var.web-ami
  instance_type     = "t2.micro"
  key_name          = "webserverkey"

  network_interface  {
    device_index         = 0
    network_interface_id = aws_network_interface.Web-server-tf.id
  }

  user_data = <<-EOF
                 #!/bin/bash
                 sudo apt update -y
                 sudo apt install apache2 -y
                 sudo systemctl start apache2
                 sudo bash -c 'echo your very first web server > /var/www/html/index.html'
                 EOF
  tags = {
    Name = "web-server"
  }
}