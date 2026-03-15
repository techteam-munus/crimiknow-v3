variable "project_name" {
  description = "Project name for resource naming"
  type        = string
}

variable "environment" {
  description = "Environment (dev, staging, prod)"
  type        = string
}

variable "aws_region" {
  description = "AWS region for Bedrock"
  type        = string
}

variable "bedrock_model_id" {
  description = "Bedrock model ID to use (e.g., anthropic.claude-3-5-sonnet-20241022-v2:0)"
  type        = string
  default     = "anthropic.claude-3-5-sonnet-20241022-v2:0"
}
