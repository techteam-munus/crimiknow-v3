output "role_arn" {
  description = "ARN of the Bedrock IAM role"
  value       = aws_iam_role.bedrock.arn
}

output "policy_arn" {
  description = "ARN of the Bedrock IAM policy"
  value       = aws_iam_policy.bedrock.arn
}

output "user_arn" {
  description = "ARN of the Bedrock IAM user"
  value       = aws_iam_user.bedrock.arn
}

output "access_key_id" {
  description = "Access key ID for Bedrock"
  value       = aws_iam_access_key.bedrock.id
  sensitive   = true
}

output "secret_access_key" {
  description = "Secret access key for Bedrock"
  value       = aws_iam_access_key.bedrock.secret
  sensitive   = true
}

output "secret_arn" {
  description = "ARN of the Bedrock secret in Secrets Manager"
  value       = aws_secretsmanager_secret.bedrock.arn
}

output "model_id" {
  description = "Bedrock model ID being used"
  value       = var.bedrock_model_id
}
