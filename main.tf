# create rg, list created resources
resource "aws_resourcegroups_group" "example" {
  name        = "tf-rg-example"
  description = "Resource group for example resources"

  resource_query {
    query = <<JSON
    {
      "ResourceTypeFilters": [
        "AWS::AllSupported"
      ],
      "TagFilters": [
        {
          "Key": "Owner",
          "Values": ["John Ajera"]
        }
      ]
    }
    JSON
  }

  tags = {
    Name  = "tf-rg-example"
    Owner = "John Ajera"
  }
}

# create vpc
resource "aws_vpc" "example" {
  cidr_block           = "10.0.0.0/16"
  enable_dns_support   = true
  enable_dns_hostnames = true

  tags = {
    Name  = "tf-vpc-example"
    Owner = "John Ajera"
  }
}

# create subnet
resource "aws_subnet" "example_a" {
  vpc_id                  = aws_vpc.example.id
  cidr_block              = "10.0.1.0/24"
  map_public_ip_on_launch = false
  availability_zone       = "ap-southeast-1a"

  tags = {
    Name  = "tf-subnet-example_a"
    Owner = "John Ajera"
  }
}

resource "aws_subnet" "example_b" {
  vpc_id                  = aws_vpc.example.id
  cidr_block              = "10.0.2.0/24"
  map_public_ip_on_launch = false
  availability_zone       = "ap-southeast-1b"

  tags = {
    Name  = "tf-subnet-example_b"
    Owner = "John Ajera"
  }
}


# create application load balancer
resource "aws_lb" "example" {
  name                             = "tf-alb-example"
  internal                         = false
  load_balancer_type               = "application"
  enable_deletion_protection       = false
  subnets                          = [aws_subnet.example_a.id, aws_subnet.example_b.id]
  security_groups                  = [aws_security_group.example_http_alb.id]
  enable_cross_zone_load_balancing = true

  tags = {
    Name  = "tf-alb-example"
    Owner = "John Ajera"
  }
}

# create alb target group
resource "aws_lb_target_group" "example" {
  name        = "tf-alb-target-group-example"
  port        = 80
  protocol    = "HTTP"
  target_type = "instance"
  # stickiness {
  #   type    = "lb_cookie"
  #   cookie_duration = 600
  # }
  vpc_id = aws_vpc.example.id
  tags = {
    Name  = "tf-alb-target-group-example"
    Owner = "John Ajera"
  }
}

resource "aws_lb_listener" "example" {
  load_balancer_arn = aws_lb.example.arn
  port              = 80
  protocol          = "HTTP"
  default_action {
    target_group_arn = aws_lb_target_group.example.arn
    type             = "forward"
  }
}

# attach auto scaling group to alb target group
resource "aws_autoscaling_attachment" "example" {
  autoscaling_group_name = aws_autoscaling_group.example.id
  lb_target_group_arn    = aws_lb_target_group.example.arn
}

# create ig
resource "aws_internet_gateway" "example" {
  vpc_id = aws_vpc.example.id

  tags = {
    Name  = "tf-ig-example"
    Owner = "John Ajera"
  }
}

# create rt
resource "aws_route_table" "example" {
  vpc_id = aws_vpc.example.id

  route {
    cidr_block = "0.0.0.0/0"
    gateway_id = aws_internet_gateway.example.id
  }

  route {
    ipv6_cidr_block = "::/0"
    gateway_id      = aws_internet_gateway.example.id
  }

  tags = {
    Name  = "tf-rt-example"
    Owner = "John Ajera"
  }
}

# set rt association
resource "aws_route_table_association" "example_a" {
  subnet_id      = aws_subnet.example_a.id
  route_table_id = aws_route_table.example.id
}

resource "aws_route_table_association" "example_b" {
  subnet_id      = aws_subnet.example_b.id
  route_table_id = aws_route_table.example.id
}

# create sg
resource "aws_security_group" "example_ssh" {
  name        = "tf-sg-example-ssh"
  description = "Security group for example resources to allow ssh"
  vpc_id      = aws_vpc.example.id

  ingress {
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
    Name  = "tf-sg-example_ssh"
    Owner = "John Ajera"
  }
}

resource "aws_security_group" "example_http_alb" {
  name        = "tf-sg-example-http_alb"
  description = "Security group for example resources to allow alb access to http"
  vpc_id      = aws_vpc.example.id

  ingress {
    from_port   = 80
    to_port     = 80
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
    Name  = "tf-sg-example_http_alb"
    Owner = "John Ajera"
  }
}

resource "aws_security_group" "example_http_ec2" {
  name        = "tf-sg-example-http_ec2"
  description = "Security group for example resources to allow access to http hosted in ec2"
  vpc_id      = aws_vpc.example.id

  ingress {
    from_port       = 80
    to_port         = 80
    protocol        = "tcp"
    security_groups = [aws_security_group.example_http_alb.id]
  }

  egress {
    from_port   = 0
    to_port     = 0
    protocol    = "-1"
    cidr_blocks = ["0.0.0.0/0"]
  }

  tags = {
    Name  = "tf-sg-example_http_ec2"
    Owner = "John Ajera"
  }
}

# get image ami
data "aws_ami" "example" {
  most_recent = true

  filter {
    name   = "name"
    values = ["ubuntu/images/hvm-ssd/ubuntu-focal-20.04-amd64-server-*"]
  }

  filter {
    name   = "virtualization-type"
    values = ["hvm"]
  }

  owners = ["099720109477"] # Canonical
}

# get ssh key pair
resource "aws_key_pair" "example" {
  key_name   = "tf-kp-example"
  public_key = file("~/.ssh/id_ed25519_aws.pub")
}

resource "aws_launch_configuration" "example" {
  name = "example-launch-configuration"

  image_id      = data.aws_ami.example.image_id
  instance_type = "t2.small"
  key_name      = aws_key_pair.example.key_name
  security_groups = [
    aws_security_group.example_ssh.id,
    aws_security_group.example_http_ec2.id
  ]
  associate_public_ip_address = true
  lifecycle {
    create_before_destroy = true
  }
  user_data = filebase64("${path.module}/external/web.conf") #nginx webserver setup config
}

resource "aws_autoscaling_group" "example" {
  desired_capacity          = 2
  max_size                  = 5
  min_size                  = 1
  health_check_type         = "ELB"
  health_check_grace_period = 300

  vpc_zone_identifier = [
    aws_subnet.example_a.id,
    aws_subnet.example_b.id,
  ]

  launch_configuration = aws_launch_configuration.example.id

  tag {
    key                 = "Name"
    value               = "tf-asg-example"
    propagate_at_launch = true
  }

  tag {
    key                 = "Owner"
    value               = "John Ajera"
    propagate_at_launch = true
  }
}

output "alb" {
  value = aws_lb.example.dns_name
}
