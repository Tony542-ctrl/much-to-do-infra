# -----------------------------------------------
# IAM Role for EC2 Instances
# Allows SSM access + CloudWatch Logs
# -----------------------------------------------
resource "aws_iam_role" "backend_ec2" {
  name = "${var.project_name}-backend-ec2-role"

  assume_role_policy = jsonencode({
    Version = "2012-10-17"
    Statement = [
      {
        Action = "sts:AssumeRole"
        Effect = "Allow"
        Principal = {
          Service = "ec2.amazonaws.com"
        }
      }
    ]
  })

  tags = {
    Name = "${var.project_name}-backend-ec2-role"
  }
}

# SSM Managed Instance Core — allows Session Manager access (no bastion needed for debugging)
resource "aws_iam_role_policy_attachment" "ssm" {
  role       = aws_iam_role.backend_ec2.name
  policy_arn = "arn:aws:iam::aws:policy/AmazonSSMManagedInstanceCore"
}

# CloudWatch Agent — allows pushing logs and metrics
resource "aws_iam_role_policy_attachment" "cloudwatch_agent" {
  role       = aws_iam_role.backend_ec2.name
  policy_arn = "arn:aws:iam::aws:policy/CloudWatchAgentServerPolicy"
}

# Custom policy for CloudWatch Logs (create log streams, put log events)
resource "aws_iam_policy" "cloudwatch_logs" {
  name        = "${var.project_name}-cloudwatch-logs-policy"
  description = "Allow EC2 to create and write CloudWatch log streams"

  policy = jsonencode({
    Version = "2012-10-17"
    Statement = [
      {
        Effect = "Allow"
        Action = [
          "logs:CreateLogGroup",
          "logs:CreateLogStream",
          "logs:PutLogEvents",
          "logs:DescribeLogStreams",
          "logs:DescribeLogGroups"
        ]
        Resource = [
          aws_cloudwatch_log_group.backend.arn,
          "${aws_cloudwatch_log_group.backend.arn}:*"
        ]
      }
    ]
  })
}

resource "aws_iam_role_policy_attachment" "cloudwatch_logs" {
  role       = aws_iam_role.backend_ec2.name
  policy_arn = aws_iam_policy.cloudwatch_logs.arn
}

# Instance Profile
resource "aws_iam_instance_profile" "backend_ec2" {
  name = "${var.project_name}-backend-ec2-profile"
  role = aws_iam_role.backend_ec2.name
}
