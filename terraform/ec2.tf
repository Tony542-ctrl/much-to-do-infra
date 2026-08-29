# -----------------------------------------------
# Data: Latest Amazon Linux 2023 AMI
# -----------------------------------------------
data "aws_ami" "amazon_linux" {
  most_recent = true
  owners      = ["amazon"]

  filter {
    name   = "name"
    values = ["al2023-ami-2023.*-x86_64"]
  }

  filter {
    name   = "virtualization-type"
    values = ["hvm"]
  }

  filter {
    name   = "architecture"
    values = ["x86_64"]
  }
}

# -----------------------------------------------
# Bastion Host (public subnet, for SSH jump)
# -----------------------------------------------
resource "aws_instance" "bastion" {
  ami                    = data.aws_ami.amazon_linux.id
  instance_type          = "t3.micro"
  subnet_id              = aws_subnet.public[0].id
  key_name               = var.key_pair_name
  vpc_security_group_ids = [aws_security_group.bastion.id]

  tags = {
    Name = "${var.project_name}-bastion"
  }
}

# -----------------------------------------------
# Backend EC2 Instances (2x in private subnets)
# -----------------------------------------------
resource "aws_instance" "backend" {
  count = 2

  ami                    = data.aws_ami.amazon_linux.id
  instance_type          = var.ec2_instance_type
  subnet_id              = aws_subnet.private[count.index].id
  key_name               = var.key_pair_name
  vpc_security_group_ids = [aws_security_group.backend.id]
  iam_instance_profile   = aws_iam_instance_profile.backend_ec2.name

  user_data = templatefile("${path.module}/../scripts/user-data.sh", {
    project_name         = var.project_name
    backend_port         = var.backend_port
    mongo_uri            = var.mongo_uri
    db_name              = var.db_name
    jwt_secret_key       = var.jwt_secret_key
    jwt_expiration_hours = var.jwt_expiration_hours
    redis_addr           = "${aws_elasticache_cluster.redis.cache_nodes[0].address}:6379"
    allowed_origins      = "https://${aws_cloudfront_distribution.frontend.domain_name}"
    cookie_domains       = aws_cloudfront_distribution.frontend.domain_name
    log_group_name       = aws_cloudwatch_log_group.backend.name
    aws_region           = var.aws_region
  })

  root_block_device {
    volume_size = 20
    volume_type = "gp3"
    encrypted   = true
  }

  tags = {
    Name = "${var.project_name}-backend-${count.index + 1}"
  }

  depends_on = [
    aws_nat_gateway.main,
    aws_elasticache_cluster.redis,
    aws_cloudfront_distribution.frontend
  ]
}
