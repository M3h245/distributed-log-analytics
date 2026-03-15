resource "aws_ecr_repository" "api" {
  name = "${var.project_name}-api"
}

resource "aws_ecr_repository" "producer" {
  name = "${var.project_name}-producer"
}

resource "aws_ecr_repository" "processor" {
  name = "${var.project_name}-processor"
}

output "ecr_api_repo_url" {
  value = aws_ecr_repository.api.repository_url
}

output "ecr_producer_repo_url" {
  value = aws_ecr_repository.producer.repository_url
}

output "ecr_processor_repo_url" {
  value = aws_ecr_repository.processor.repository_url
}
