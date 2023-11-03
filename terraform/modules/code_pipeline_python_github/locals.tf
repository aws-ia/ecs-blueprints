locals {
  pipeline_name       = "${var.repository_name}-github-pipeline"
  codecommit_repo_arn = "arn:aws:codecommit:${var.aws_region}:${var.account_id}:${var.repository_name}"
  pipeline_arn        = "arn:aws:codepipeline:${var.aws_region}:${var.account_id}:${local.pipeline_name}"
}
