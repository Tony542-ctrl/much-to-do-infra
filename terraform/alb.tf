# -----------------------------------------------
# Application Load Balancer
# -----------------------------------------------
resource "aws_lb" "backend" {
  name               = "${var.project_name}-alb"
  internal           = false
  load_balancer_type = "application"
  security_groups    = [aws_security_group.alb.id]
  subnets            = aws_subnet.public[*].id

  enable_deletion_protection = false

  tags = {
    Name = "${var.project_name}-alb"
  }
}

# -----------------------------------------------
# Target Group
# -----------------------------------------------
resource "aws_lb_target_group" "backend" {
  name     = "${var.project_name}-tg"
  port     = var.backend_port
  protocol = "HTTP"
  vpc_id   = aws_vpc.main.id

  health_check {
    enabled             = true
    path                = "/health"
    port                = tostring(var.backend_port)
    protocol            = "HTTP"
    healthy_threshold   = 2
    unhealthy_threshold = 3
    timeout             = 5
    interval            = 30
    matcher             = "200"
  }

  tags = {
    Name = "${var.project_name}-tg"
  }
}

# -----------------------------------------------
# Listener: HTTP (port 80)
# -----------------------------------------------
resource "aws_lb_listener" "http" {
  load_balancer_arn = aws_lb.backend.arn
  port              = 80
  protocol          = "HTTP"

  default_action {
    type             = "forward"
    target_group_arn = aws_lb_target_group.backend.arn
  }
}

# -----------------------------------------------
# Register EC2 instances with target group
# -----------------------------------------------
resource "aws_lb_target_group_attachment" "backend" {
  count = 2

  target_group_arn = aws_lb_target_group.backend.arn
  target_id        = aws_instance.backend[count.index].id
  port             = var.backend_port
}
