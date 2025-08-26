resource "aws_vpc" "myvpc" {
  
  cidr_block =  var.cidr  /* here we create vpc and allocate ip a range of ips to it*/

}
//here we create one subnet
resource "aws_subnet" "subnet1" {
  vpc_id = aws_vpc.myvpc.id //vpc name
  cidr_block = "10.0.0.0/24"  //range of ip
  availability_zone = "us-east-1a" //where servers are located
  map_public_ip_on_launch = true //to assigne automatically ip address to the EC2 indtance
}
// here we create another subnet
resource "aws_subnet" "subnet2" {
  vpc_id = aws_vpc.myvpc.id  
  cidr_block = "10.0.1.0/24"   
  availability_zone = "us-east-1b"  
  map_public_ip_on_launch = true 
}

// create internet gateway
resource "aws_internet_gateway" "IGW" {
  vpc_id = aws_vpc.myvpc.id
}

//create route table 
resource "aws_route_table" "RT" {
  vpc_id = aws_vpc.myvpc.id

    route {
    cidr_block = "0.0.0.0/0"
    gateway_id = aws_internet_gateway.IGW.id
  }
}


resource "aws_route_table_association" "RTA1" {
  subnet_id = aws_subnet.subnet1.id
  route_table_id = aws_route_table.RT.id
}


resource "aws_route_table_association" "RTA2" {
  subnet_id = aws_subnet.subnet2.id
  route_table_id = aws_route_table.RT.id
}


resource "aws_security_group" "webSg" {
  name        = "SG"
  vpc_id      = aws_vpc.myvpc.id

  ingress {
    description = "HTTP from vpc"
    from_port = 80
    to_port = 80
    protocol = "tcp"
    cidr_blocks = ["0.0.0.0/0"]
  }


  ingress {
  description = "SSH"
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
}

// Here we create S3 bucket
resource "aws_s3_bucket" "example" {
  bucket = "dheerajkadve1awsbucket"
}

// Here we create EC2 instances
resource "aws_instance" "webserver1" {
  ami                    = "ami-0261755bbcb8c4a84"
  instance_type          = "t2.micro"
  vpc_security_group_ids = [aws_security_group.webSg.id]
  subnet_id              = aws_subnet.subnet1.id
  user_data              = base64encode(file("userdata.sh"))
}

// Here we create EC2 instances
resource "aws_instance" "webserver2" {
  ami                    = "ami-0261755bbcb8c4a84"
  instance_type          = "t2.micro"
  vpc_security_group_ids = [aws_security_group.webSg.id]
  subnet_id              = aws_subnet.subnet2.id
  user_data              = base64encode(file("userdata1.sh"))
}

//creating loadbalancer
resource "aws_lb" "Loadbalancer" {
  name = "loadbalancer"
  internal = false
  load_balancer_type = "application"

  security_groups = [aws_security_group.webSg.id]
  subnets = [aws_subnet.subnet1.id,aws_subnet.subnet2.id]
}

resource "aws_lb_target_group" "tg" {
  name = "myTG"
  port = 80
  protocol = "HTTP"
  vpc_id = aws_vpc.myvpc.id

  health_check {
    path = "/"
    port = "traffic-port"
  }
}

resource "aws_lb_target_group_attachment" "attach1"{
  target_group_arn = aws_lb_target_group.tg.arn
  target_id = aws_instance.webserver1.id
  port = 80
}
resource "aws_lb_target_group_attachment" "attach2"{
  target_group_arn = aws_lb_target_group.tg.arn
  target_id = aws_instance.webserver2.id
  port = 80
}

resource "aws_lb_listener" "listner" {
  load_balancer_arn = aws_lb.Loadbalancer.arn
  port = "80"
  protocol = "HTTP"

  default_action {
    type = "forward"
    target_group_arn = aws_lb_target_group.tg.arn
  }
}
output "loadbalancerdns" {
  value = aws_lb.Loadbalancer.dns_name
}
