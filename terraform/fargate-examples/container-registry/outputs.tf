output "ecr_repository_url" {
  description = "The URL of the repository"
  value       = aws_ecr_repository.this.repository_url
}
