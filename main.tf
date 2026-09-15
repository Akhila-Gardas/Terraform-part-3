terraform {
  required_providers {
    aws = { source = "hashicorp/aws", version = "~> 5.0" }
  }
}

provider "aws" {
  region = "ap-south-1"
}

data "aws_availability_zones" "az" {}

resource "aws_vpc" "main" {
  cidr_block = "10.0.0.0/16"
  tags = {
    Name = "part3-vpc"
  }
}

resource "aws_internet_gateway" "igw" {
  vpc_id = aws_vpc.main.id
}

resource "aws_subnet" "pub1" {
  vpc_id = aws_vpc.main.id
  cidr_block = "10.0.1.0/24"
  availability_zone = data.aws_availability_zones.az.names[0]
  map_public_ip_on_launch = true
}

resource "aws_subnet" "pub2" {
  vpc_id = aws_vpc.main.id
  cidr_block = "10.0.2.0/24"
  availability_zone = data.aws_availability_zones.az.names[1]
  map_public_ip_on_launch = true
}

resource "aws_route_table" "rt" {
  vpc_id = aws_vpc.main.id
  route {
    cidr_block = "0.0.0.0/0"
    gateway_id = aws_internet_gateway.igw.id
  }
}

resource "aws_route_table_association" "a1" {
  subnet_id = aws_subnet.pub1.id
  route_table_id = aws_route_table.rt.id
}

resource "aws_route_table_association" "a2" {
  subnet_id = aws_subnet.pub2.id
  route_table_id = aws_route_table.rt.id
}

resource "aws_ecr_repository" "flask_repo" {
  name = "part3-flask-repo"
  force_delete = true
}

resource "aws_ecr_repository" "express_repo" {
  name = "part3-express-repo"
  force_delete = true
}

resource "aws_security_group" "alb_sg" {
  vpc_id = aws_vpc.main.id

  ingress {
    from_port = 80
    to_port = 80
    protocol = "tcp"
    cidr_blocks = ["0.0.0.0/0"]
  }

  ingress {
    from_port = 5000
    to_port = 5000
    protocol = "tcp"
    cidr_blocks = ["0.0.0.0/0"]
  }

  ingress {
    from_port = 3000
    to_port = 3000
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

resource "aws_security_group" "ecs_sg" {
  vpc_id = aws_vpc.main.id

  ingress {
    from_port = 5000
    to_port = 5000
    protocol = "tcp"
    security_groups = [aws_security_group.alb_sg.id]
  }

  ingress {
    from_port = 3000
    to_port = 3000
    protocol = "tcp"
    security_groups = [aws_security_group.alb_sg.id]
  }

  egress {
    from_port = 0
    to_port = 0
    protocol = "-1"
    cidr_blocks = ["0.0.0.0/0"]
  }
}

resource "aws_iam_role" "ecs_exec_role" {
  name = "ecsTaskExecutionRole-part3"

  assume_role_policy = jsonencode({
    Version = "2012-10-17"
    Statement = [
      {
        Action = "sts:AssumeRole"
        Effect = "Allow"
        Principal = {
          Service = "ecs-tasks.amazonaws.com"
        }
      }
    ]
  })
}

resource "aws_iam_role_policy_attachment" "ecs_exec_attach" {
  role = aws_iam_role.ecs_exec_role.name
  policy_arn = "arn:aws:iam::aws:policy/service-role/AmazonECSTaskExecutionRolePolicy"
}

resource "aws_lb" "app_alb" {
  name = "part3-alb"
  internal = false
  load_balancer_type = "application"
  security_groups = [aws_security_group.alb_sg.id]
  subnets = [aws_subnet.pub1.id, aws_subnet.pub2.id]
}

resource "aws_lb_target_group" "flask_tg" {
  name = "flask-tg"
  port = 5000
  protocol = "HTTP"
  vpc_id = aws_vpc.main.id
  target_type = "ip"

  health_check {
    path = "/"
  }
}

resource "aws_lb_target_group" "express_tg" {
  name = "express-tg"
  port = 3000
  protocol = "HTTP"
  vpc_id = aws_vpc.main.id
  target_type = "ip"

  health_check {
    path = "/"
  }
}

resource "aws_lb_listener" "flask_listener" {
  load_balancer_arn = aws_lb.app_alb.arn
  port = 5000
  protocol = "HTTP"

  default_action {
    type = "forward"
    target_group_arn = aws_lb_target_group.flask_tg.arn
  }
}

resource "aws_lb_listener" "express_listener" {
  load_balancer_arn = aws_lb.app_alb.arn
  port = 3000
  protocol = "HTTP"

  default_action {
    type = "forward"
    target_group_arn = aws_lb_target_group.express_tg.arn
  }
}

resource "aws_ecs_cluster" "main" {
  name = "part3-cluster"
}

resource "aws_ecs_task_definition" "flask_task" {
  family = "flask-task"
  network_mode = "awsvpc"
  requires_compatibilities = ["FARGATE"]
  cpu = "256"
  memory = "512"
  execution_role_arn = aws_iam_role.ecs_exec_role.arn

  container_definitions = jsonencode([
    {
      name = "flask"
      image = "${aws_ecr_repository.flask_repo.repository_url}:latest"
      portMappings = [
        {
          containerPort = 5000
        }
      ]
      essential = true
    }
  ])
}

resource "aws_ecs_task_definition" "express_task" {
  family = "express-task"
  network_mode = "awsvpc"
  requires_compatibilities = ["FARGATE"]
  cpu = "256"
  memory = "512"
  execution_role_arn = aws_iam_role.ecs_exec_role.arn

  container_definitions = jsonencode([
    {
      name = "express"
      image = "${aws_ecr_repository.express_repo.repository_url}:latest"
      portMappings = [
        {
          containerPort = 3000
        }
      ]
      essential = true
    }
  ])
}

resource "aws_ecs_service" "flask_service" {
  name = "flask-service"
  cluster = aws_ecs_cluster.main.id
  task_definition = aws_ecs_task_definition.flask_task.arn
  desired_count = 1
  launch_type = "FARGATE"

  network_configuration {
    subnets = [aws_subnet.pub1.id, aws_subnet.pub2.id]
    security_groups = [aws_security_group.ecs_sg.id]
    assign_public_ip = true
  }

  load_balancer {
    target_group_arn = aws_lb_target_group.flask_tg.arn
    container_name = "flask"
    container_port = 5000
  }

  depends_on = [aws_lb_listener.flask_listener]
}

resource "aws_ecs_service" "express_service" {
  name = "express-service"
  cluster = aws_ecs_cluster.main.id
  task_definition = aws_ecs_task_definition.express_task.arn
  desired_count = 1
  launch_type = "FARGATE"

  network_configuration {
    subnets = [aws_subnet.pub1.id, aws_subnet.pub2.id]
    security_groups = [aws_security_group.ecs_sg.id]
    assign_public_ip = true
  }

  load_balancer {
    target_group_arn = aws_lb_target_group.express_tg.arn
    container_name = "express"
    container_port = 3000
  }

  depends_on = [aws_lb_listener.express_listener]
}

output "alb_dns" {
  value = aws_lb.app_alb.dns_name
}

output "flask_url" {
  value = "http://${aws_lb.app_alb.dns_name}:5000"
}

output "express_url" {
  value = "http://${aws_lb.app_alb.dns_name}:3000"
}

output "ecr_flask" {
  value = aws_ecr_repository.flask_repo.repository_url
}

output "ecr_express" {
  value = aws_ecr_repository.express_repo.repository_url
}