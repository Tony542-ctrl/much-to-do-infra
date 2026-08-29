# -----------------------------------------------
# Networking
# -----------------------------------------------
output "vpc_id" {
  description = "ID of the VPC"
  value       = aws_vpc.main.id
}

output "public_subnet_ids" {
  description = "IDs of public subnets"
  value       = aws_subnet.public[*].id
}

output "private_subnet_ids" {
  description = "IDs of private subnets"
  value       = aws_subnet.private[*].id
}

output "nat_gateway_eip" {
  description = "Elastic IP of the NAT Gateway (whitelist in MongoDB Atlas)"
  value       = aws_eip.nat.public_ip
}

# -----------------------------------------------
# Compute
# -----------------------------------------------
output "alb_dns_name" {
  description = "DNS name of the Application Load Balancer"
  value       = aws_lb.backend.dns_name
}

output "backend_instance_ids" {
  description = "IDs of the backend EC2 instances"
  value       = aws_instance.backend[*].id
}

output "backend_private_ips" {
  description = "Private IPs of the backend EC2 instances"
  value       = aws_instance.backend[*].private_ip
}

output "bastion_public_ip" {
  description = "Public IP of the bastion host"
  value       = aws_instance.bastion.public_ip
}

# -----------------------------------------------
# Frontend
# -----------------------------------------------
output "s3_bucket_name" {
  description = "Name of the S3 bucket for frontend assets"
  value       = aws_s3_bucket.frontend.id
}

output "cloudfront_domain_name" {
  description = "CloudFront distribution domain name (Live Frontend URL)"
  value       = aws_cloudfront_distribution.frontend.domain_name
}

output "cloudfront_distribution_id" {
  description = "CloudFront distribution ID (for cache invalidation)"
  value       = aws_cloudfront_distribution.frontend.id
}

# -----------------------------------------------
# Data Layer
# -----------------------------------------------
output "redis_endpoint" {
  description = "ElastiCache Redis endpoint"
  value       = aws_elasticache_cluster.redis.cache_nodes[0].address
}

# -----------------------------------------------
# Observability
# -----------------------------------------------
output "cloudwatch_log_group" {
  description = "CloudWatch Log Group name for backend"
  value       = aws_cloudwatch_log_group.backend.name
}
