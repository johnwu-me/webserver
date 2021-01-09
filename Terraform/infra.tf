variable "vpc_id" {
	default = "vpc-0d108fcd1a0a396c3"
}

provider "aws" {
  region = "us-west-2"
}

#internet gateway
resource "aws_internet_gateway" "gw" {
  vpc_id = var.vpc_id

  tags = {
    Name = "lab-ig"
  }
}

#elastic ip for nat gateway
resource "aws_eip" "ng" {
  vpc      = true
}

#nat gateway
resource "aws_nat_gateway" "natgw" {
    allocation_id = aws_eip.ng.id
    subnet_id = aws_subnet.public_subnet_a.id
}

#public route table
resource "aws_route_table" "public_routing_table" {
  vpc_id = var.vpc_id
  route {
    cidr_block = "0.0.0.0/0"
    gateway_id = aws_internet_gateway.gw.id
  }

  tags = {
    Name = "public_route_table"
  }
}


#private route table
resource "aws_route_table" "private_route_table" {
  vpc_id = var.vpc_id
  route {
    cidr_block = "0.0.0.0/0"
    gateway_id = aws_nat_gateway.natgw.id
  }

  tags = {
    Name = "private_route_table"
  }
}

#public subneta
resource "aws_subnet" "public_subnet_a" {
    vpc_id = var.vpc_id
    cidr_block = "192.168.1.0/24"
    availability_zone = "us-west-2a"

    tags = {
        Name = "public_a"
    }
}

#public subnetb
resource "aws_subnet" "public_subnet_b" {
    vpc_id = var.vpc_id
    cidr_block = "192.168.3.0/24"
    availability_zone = "us-west-2b"

    tags = {
        Name = "public_b"
    }
}

#private subneta
resource "aws_subnet" "private_subnet_a" {
    vpc_id = var.vpc_id
    cidr_block = "192.168.2.0/24"
    availability_zone = "us-west-2a"

    tags = {
        Name = "private_a"
    }
}

#private subnetb
resource "aws_subnet" "private_subnet_b" {
    vpc_id = var.vpc_id
    cidr_block = "192.168.4.0/24"
    availability_zone = "us-west-2b"

    tags = {
        Name = "private_b"
    }
}


#associate public subneta with public route table
resource "aws_route_table_association" "public_subnet_a_rt_assoc" {
    subnet_id = aws_subnet.public_subnet_a.id
    route_table_id = aws_route_table.public_routing_table.id
}

#associate public subnetb with public route table
resource "aws_route_table_association" "public_subnet_b_rt_assoc" {
    subnet_id = aws_subnet.public_subnet_b.id
    route_table_id = aws_route_table.public_routing_table.id
}

#associate private subneta with private route table
resource "aws_route_table_association" "private_subnet_a_rt_assoc" {
    subnet_id = aws_subnet.private_subnet_a.id
    route_table_id = aws_route_table.private_route_table.id
}


#associate private subnetb with private route table
resource "aws_route_table_association" "private_subnet_b_rt_assoc" {
    subnet_id = aws_subnet.private_subnet_b.id
    route_table_id = aws_route_table.private_route_table.id
}


#security group to allow access
resource "aws_security_group" "myip" {
  name = "allowmyip"
  description = "only my ip"
  vpc_id = var.vpc_id

  ingress {
      from_port = 22
      to_port = 22
      protocol = "tcp"
      cidr_blocks = ["71.93.107.48/32"]
  }
  
  egress {
      from_port = 0
      to_port = 0
      protocol = "-1"
      cidr_blocks = ["0.0.0.0/0"]
  }
}

#security group for the 2 instances
resource "aws_security_group" "for2in" {
  name = "sgforwebservers"
  vpc_id = var.vpc_id

  ingress {
      from_port = 80
      to_port = 80
      protocol = "tcp"
      cidr_blocks = ["0.0.0.0/0"]
  }
  
  ingress {
      from_port = 443
      to_port = 443
      protocol = "tcp"
      cidr_blocks = ["0.0.0.0/0"]
  }
  
  ingress {
      from_port = 22
      to_port = 22
      protocol = "tcp"
      cidr_blocks = ["192.168.0.0/16"]
  }
  
  egress {
      from_port = 0
      to_port = 0
      protocol = "-1"
      cidr_blocks = ["0.0.0.0/0"]
  }
}

#security group for the elb
resource "aws_security_group" "forelb" {
  name = "sgforelb"
  vpc_id = var.vpc_id

  ingress {
      from_port = 80
      to_port = 80
      protocol = "tcp"
      cidr_blocks = ["0.0.0.0/0"]
  }
  
  egress {
      from_port = 0
      to_port = 0
      protocol = "-1"
      cidr_blocks = ["0.0.0.0/0"]
  }
}
	
#bastion instance
resource "aws_instance" "bastion" {
    ami = "ami-0a36eb8fadc976275"
    instance_type = "t2.micro"
    subnet_id = aws_subnet.public_subnet_a.id
	associate_public_ip_address = true
	vpc_security_group_ids = [aws_security_group.myip.id]
	key_name = "lab"
	
	tags = {
		Name = "bastion"
	}
}


#web1 instance
resource "aws_instance" "web1" {
    ami = "ami-0a36eb8fadc976275"
    instance_type = "t2.micro"
    subnet_id = aws_subnet.private_subnet_a.id
	private_ip = "192.168.2.10"
	vpc_security_group_ids = [aws_security_group.for2in.id]
	key_name = "lab"
	
	tags = {
		Name = "webserver-1"
	}
}

#web2 instance
resource "aws_instance" "web2" {
    ami = "ami-0a36eb8fadc976275"
    instance_type = "t2.micro"
    subnet_id = aws_subnet.private_subnet_b.id
	private_ip = "192.168.4.10"
	vpc_security_group_ids = [aws_security_group.for2in.id]
	key_name = "lab"
	
	tags = {
		Name = "webserver-2"
	}
}

#Create a new elastic load balancer
resource "aws_lb" "weblb" {
  name = "weblb"
  load_balancer_type = "application"
  subnets = [aws_subnet.public_subnet_a.id, aws_subnet.public_subnet_b.id]
  security_groups = [aws_security_group.forelb.id]
  
  
  tags = {
    Name = "weblb"
  }
}

resource "aws_lb_listener" "front_end" {
  load_balancer_arn = aws_lb.weblb.id
  port              = "80"
  protocol          = "HTTP"

  default_action {
    type             = "forward"
    target_group_arn = aws_lb_target_group.front_end.id
  }
}

# Create target groups with one health check per group
resource "aws_lb_target_group" "front_end" {
  name = "webservers"
  port = 80
  protocol = "HTTP"
  vpc_id = var.vpc_id


  health_check {
    path = "/var/www/html"
    port = 80
    healthy_threshold = 5
    unhealthy_threshold = 2
    timeout = 2
    interval = 5
    matcher = "200"
  }
}

resource "aws_lb_target_group_attachment" "web1" {
  target_group_arn = aws_lb_target_group.front_end.id
  target_id        = aws_instance.web1.id
  port             = 80
}

resource "aws_lb_target_group_attachment" "web2" {
  target_group_arn = aws_lb_target_group.front_end.id
  target_id        = aws_instance.web2.id
  port             = 80
}
