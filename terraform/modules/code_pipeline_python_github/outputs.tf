output "pipeline_arn" {
  description = "The pipeline ARN"
  value       = aws_codepipeline.pipeline.arn
}
