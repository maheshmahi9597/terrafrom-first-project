resource "aws_vpc" "myvpc" {
  cidr_block = var.cidr #created vpc
}

resource "aws_subnet" "sub1" {
  vpc_id                  = aws_vpc.myvpc.id
  cidr_block              = "10.0.0.0/24" #created private subnet1 in availability zone1a
  availability_zone       = "us-east-1a"
  map_public_ip_on_launch = true
}
resource "aws_subnet" "sub2" {
  vpc_id                  = aws_vpc.myvpc.id
  cidr_block              = "10.0.1.0/24" #created private subnet1 in availability zone1b
  availability_zone       = "us-east-1b"
  map_public_ip_on_launch = true
}

resource "aws_internet_gateway" "igw" {
  vpc_id = aws_vpc.myvpc.id #created internet gateway (An internet gateway is a horizontally scaled, redundant, and highly available VPC component that enables communication between your VPC and the internet.)
  #created internet gateway but not given access
}

#to give access 
#A route table contains a set of rules, called routes, that are used to determine where network traffic from your subnet or gateway is directed.
#route is how the traffic has to flow in the subnet(path)

resource "aws_route_table" "rt" {
  vpc_id = aws_vpc.myvpc.id

  route {
    cidr_block = "0.0.0.0/0"
    gateway_id = aws_internet_gateway.igw.id #public subnet that is already have after the route table which has the destination as internet gateway and attacing to public subnet
  }
}
#attcing the route tables to subnet that is private or public anything
resource "aws_route_table_association" "rta1" {
  subnet_id      = aws_subnet.sub1.id #attacing subnet1
  route_table_id = aws_route_table.rt.id
}

resource "aws_route_table_association" "rta2" {
  subnet_id      = aws_subnet.sub2.id #attacing subnet2
  route_table_id = aws_route_table.rt.id
}
#creating security group
resource "aws_security_group" "websg" {
  name_prefix = "websg"
  vpc_id      = aws_vpc.myvpc.id

  ingress {
    description = "TLS from VPC"
    from_port   = 80
    to_port     = 80
    protocol    = "tcp"
    cidr_blocks = ["0.0.0.0/0"]
  }
  ingress {
    description = "ssh"
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
    Name = "web-sg"
  }


}
resource "aws_s3_bucket" "example" {
  bucket = "maheshterrafrom-project"

}
resource "aws_instance" "webserver1" {
  ami                    = "ami-0866a3c8686eaeeba"
  instance_type          = "t2.micro"
  vpc_security_group_ids = [aws_security_group.websg.id]
  subnet_id              = aws_subnet.sub1.id
  user_data              = base64encode(file("userdata.sh"))
}

resource "aws_instance" "webserver2" {
  ami                    = "ami-0866a3c8686eaeeba"
  instance_type          = "t2.micro"
  vpc_security_group_ids = [aws_security_group.websg.id]
  subnet_id              = aws_subnet.sub2.id
  user_data              = base64encode(file("userdata1.sh"))
}
#create application load balancer
#here once we refresh two pages will come welcome abhiskek  and cloud champ in one page(load will be balanced)

resource "aws_lb" "myalb" {
  name               = "myalb"
  internal           = false #is means public
  load_balancer_type = "application"

  security_groups = [aws_security_group.websg.id]
  subnets         = [aws_subnet.sub1.id, aws_subnet.sub2.id]

  tags = {
    name = "web"
  }


}
#creating target group
resource "aws_lb_target_group" "tg" {
  name     = "mytg"
  port     = 80
  protocol = "HTTP"
  vpc_id   = aws_vpc.myvpc.id

  health_check {
    path = "/"
    port = "traffic-port"

  }
}
#what should be inside the target group

resource "aws_lb_target_group_attachment" "attach1" {
  target_group_arn = aws_lb_target_group.tg.arn
  target_id        = aws_instance.webserver1.id #attach one instance
  port             = 80
}
resource "aws_lb_target_group_attachment" "attach2" {
  target_group_arn = aws_lb_target_group.tg.arn
  target_id        = aws_instance.webserver2.id #attach one instance
  port             = 80
}
#to make communication
resource "aws_lb_listener" "listener" {
  load_balancer_arn = aws_lb.myalb.arn
  port              = 80
  protocol          = "HTTP"

  #show what type of action forward or redirect or show particular action
  default_action {
    target_group_arn = aws_lb_target_group.tg.arn
    type             = "forward"
  }
}
output "loadbalancerdns" {
  value = aws_lb.myalb.dns_name
}