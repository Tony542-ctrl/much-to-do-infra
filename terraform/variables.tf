# -----------------------------------------------
# General
# -----------------------------------------------
variable "aws_region" {
  description = "AWS region to deploy resources"
  type        = string
  default     = "us-east-1"
}

variable "project_name" {
  description = "Project name used for resource naming"
  type        = string
  default     = "much-to-do"
}

# -----------------------------------------------
# Networking
# -----------------------------------------------
variable "vpc_cidr" {
  description = "CIDR block for the VPC"
  type        = string
  default     = "10.0.0.0/16"
}

variable "public_subnet_cidrs" {
  description = "CIDR blocks for public subnets (one per AZ)"
  type        = list(string)
  default     = ["10.0.101.0/24", "10.0.102.0/24"]
}

variable "private_subnet_cidrs" {
  description = "CIDR blocks for private subnets (one per AZ)"
  type        = list(string)
  default     = ["10.0.1.0/24", "10.0.2.0/24"]
}

# -----------------------------------------------
# Compute
# -----------------------------------------------
variable "backend_port" {
  description = "Port the Go backend listens on"
  type        = number
  default     = 8080
}

variable "ec2_instance_type" {
  description = "EC2 instance type for backend servers"
  type        = string
  default     = "t3.micro"
}

variable "key_pair_name" {
  description = "Name of the AWS EC2 Key Pair for SSH access"
  type        = string
}

# -----------------------------------------------
# Application Secrets (sensitive)
# -----------------------------------------------
variable "mongo_uri" {
  description = "MongoDB Atlas connection string"
  type        = string
  sensitive   = true
}

variable "db_name" {
  description = "MongoDB database name"
  type        = string
  default     = "much_todo_db"
}

variable "jwt_secret_key" {
  description = "JWT signing secret key"
  type        = string
  sensitive   = true
}

variable "jwt_expiration_hours" {
  description = "JWT token expiration in hours"
  type        = number
  default     = 72
}

# -----------------------------------------------
# Cache
# -----------------------------------------------
variable "redis_node_type" {
  description = "ElastiCache Redis node type"
  type        = string
  default     = "cache.t3.micro"
}
