# -----------------------------------------------
# CloudWatch Log Group for backend application
# -----------------------------------------------
resource "aws_cloudwatch_log_group" "backend" {
  name              = "/${var.project_name}/backend"
  retention_in_days = 14

  tags = {
    Name = "${var.project_name}-backend-logs"
  }
}
