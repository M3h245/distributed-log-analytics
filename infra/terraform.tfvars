aws_region        = "eu-south-1"
project_name      = "distributed-log-analytics"

# Leave empty to use ECR repos created by Terraform
api_image         = ""
producer_image    = ""
processor_image   = ""
image_tag         = "latest"

api_container_port   = 8000
api_healthcheck_path = "/health"
api_desired_count    = 2
worker_desired_count = 2

# Phase 2: RDS + Redis
db_name     = "appdb"
db_username = "appuser"
db_password = "CHANGE_ME_STRONG_PASSWORD"
