variable "aws_region" {
  type        = string
  description = "AWS region"
  default     = "eu-south-1"
}

variable "project_name" {
  type        = string
  description = "Project name prefix"
  default     = "distributed-log-analytics"
}

variable "vpc_cidr" {
  type        = string
  description = "VPC CIDR"
  default     = "10.0.0.0/16"
}

variable "public_subnet_cidrs" {
  type        = list(string)
  description = "Two public subnet CIDRs"
  default     = ["10.0.1.0/24", "10.0.2.0/24"]
}

variable "private_subnet_cidrs" {
  type        = list(string)
  description = "Two private subnet CIDRs"
  default     = ["10.0.11.0/24", "10.0.12.0/24"]
}

variable "api_image" {
  type        = string
  description = "Override full image URI for API service (leave empty to use ECR)"
  default     = ""
}

variable "producer_image" {
  type        = string
  description = "Override full image URI for producer service (leave empty to use ECR)"
  default     = ""
}

variable "processor_image" {
  type        = string
  description = "Override full image URI for processor service (leave empty to use ECR)"
  default     = ""
}

variable "image_tag" {
  type        = string
  description = "Docker image tag to deploy when using ECR"
  default     = "latest"
}

variable "api_container_port" {
  type        = number
  description = "API container port"
  default     = 8000
}

variable "api_healthcheck_path" {
  type        = string
  description = "ALB health check path"
  default     = "/health"
}

variable "api_deregistration_delay" {
  type        = number
  description = "ALB target group deregistration delay (seconds)"
  default     = 30
}

variable "api_cpu" {
  type        = number
  description = "CPU units for API task"
  default     = 256
}

variable "api_memory" {
  type        = number
  description = "Memory (MB) for API task"
  default     = 512
}

variable "worker_cpu" {
  type        = number
  description = "CPU units for worker tasks"
  default     = 256
}

variable "worker_memory" {
  type        = number
  description = "Memory (MB) for worker tasks"
  default     = 512
}

variable "api_desired_count" {
  type        = number
  description = "Desired count for API service"
  default     = 2
}

variable "worker_desired_count" {
  type        = number
  description = "Desired count for producer/processor services"
  default     = 2
}

variable "api_min_capacity" {
  type        = number
  description = "Minimum tasks for API service autoscaling"
  default     = 2
}

variable "api_max_capacity" {
  type        = number
  description = "Maximum tasks for API service autoscaling"
  default     = 6
}

variable "worker_min_capacity" {
  type        = number
  description = "Minimum tasks for producer/processor autoscaling"
  default     = 2
}

variable "worker_max_capacity" {
  type        = number
  description = "Maximum tasks for producer/processor autoscaling"
  default     = 4
}

variable "cpu_target_utilization" {
  type        = number
  description = "Target CPU utilization percentage for autoscaling"
  default     = 60
}

variable "scale_in_cooldown" {
  type        = number
  description = "Seconds to wait before scaling in"
  default     = 60
}

variable "scale_out_cooldown" {
  type        = number
  description = "Seconds to wait before scaling out"
  default     = 60
}

variable "db_name" {
  type        = string
  description = "PostgreSQL database name"
  default     = "appdb"
}

variable "db_username" {
  type        = string
  description = "PostgreSQL master username"
  sensitive   = true
}

variable "db_password" {
  type        = string
  description = "PostgreSQL master password"
  sensitive   = true
}

variable "db_instance_class" {
  type        = string
  description = "RDS instance class"
  default     = "db.t3.micro"
}

variable "db_allocated_storage" {
  type        = number
  description = "RDS allocated storage (GB)"
  default     = 20
}

variable "db_port" {
  type        = number
  description = "PostgreSQL port"
  default     = 5432
}

variable "redis_node_type" {
  type        = string
  description = "ElastiCache node type"
  default     = "cache.t3.micro"
}

variable "redis_num_cache_clusters" {
  type        = number
  description = "Number of cache clusters (for replication group)"
  default     = 2
}

variable "redis_port" {
  type        = number
  description = "Redis port"
  default     = 6379
}
