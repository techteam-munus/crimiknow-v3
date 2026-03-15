# -----------------------------------------------------------------------------
# Amazon Bedrock Module
# Provides LLM access (Claude 3.5 Sonnet) with proper IAM permissions
# -----------------------------------------------------------------------------

# -----------------------------------------------------------------------------
# IAM Role for Bedrock Access
# -----------------------------------------------------------------------------
resource "aws_iam_role" "bedrock" {
  name = "${var.project_name}-${var.environment}-bedrock-role"

  assume_role_policy = jsonencode({
    Version = "2012-10-17"
    Statement = [
      {
        Action = "sts:AssumeRole"
        Effect = "Allow"
        Principal = {
          Service = "amplify.amazonaws.com"
        }
      }
    ]
  })

  tags = {
    Name        = "${var.project_name}-${var.environment}-bedrock-role"
    Environment = var.environment
  }
}

# -----------------------------------------------------------------------------
# IAM Policy for Bedrock Model Invocation
# -----------------------------------------------------------------------------
resource "aws_iam_policy" "bedrock" {
  name        = "${var.project_name}-${var.environment}-bedrock-policy"
  description = "Policy for invoking Amazon Bedrock models"

  policy = jsonencode({
    Version = "2012-10-17"
    Statement = [
      {
        Sid    = "BedrockInvoke"
        Effect = "Allow"
        Action = [
          "bedrock:InvokeModel",
          "bedrock:InvokeModelWithResponseStream"
        ]
        Resource = [
          # Claude 3.5 Sonnet
          "arn:aws:bedrock:${var.aws_region}::foundation-model/anthropic.claude-3-5-sonnet-20241022-v2:0",
          "arn:aws:bedrock:${var.aws_region}::foundation-model/anthropic.claude-3-5-sonnet-20240620-v1:0",
          # Claude 3.5 Haiku (faster, cheaper fallback)
          "arn:aws:bedrock:${var.aws_region}::foundation-model/anthropic.claude-3-5-haiku-20241022-v1:0",
          # Claude 3 Haiku (even cheaper for simple tasks)
          "arn:aws:bedrock:${var.aws_region}::foundation-model/anthropic.claude-3-haiku-20240307-v1:0",
          # Llama 3.1 (alternative)
          "arn:aws:bedrock:${var.aws_region}::foundation-model/meta.llama3-1-70b-instruct-v1:0",
          "arn:aws:bedrock:${var.aws_region}::foundation-model/meta.llama3-1-8b-instruct-v1:0"
        ]
      },
      {
        Sid    = "BedrockList"
        Effect = "Allow"
        Action = [
          "bedrock:ListFoundationModels",
          "bedrock:GetFoundationModel"
        ]
        Resource = "*"
      }
    ]
  })

  tags = {
    Name        = "${var.project_name}-${var.environment}-bedrock-policy"
    Environment = var.environment
  }
}

resource "aws_iam_role_policy_attachment" "bedrock" {
  role       = aws_iam_role.bedrock.name
  policy_arn = aws_iam_policy.bedrock.arn
}

# -----------------------------------------------------------------------------
# IAM User for Bedrock (for Amplify environment variables)
# Using IAM user with access keys since Amplify doesn't natively assume roles
# -----------------------------------------------------------------------------
resource "aws_iam_user" "bedrock" {
  name = "${var.project_name}-${var.environment}-bedrock-user"
  path = "/service-accounts/"

  tags = {
    Name        = "${var.project_name}-${var.environment}-bedrock-user"
    Environment = var.environment
  }
}

resource "aws_iam_user_policy_attachment" "bedrock" {
  user       = aws_iam_user.bedrock.name
  policy_arn = aws_iam_policy.bedrock.arn
}

resource "aws_iam_access_key" "bedrock" {
  user = aws_iam_user.bedrock.name
}

# -----------------------------------------------------------------------------
# Store Bedrock credentials in Secrets Manager
# -----------------------------------------------------------------------------
resource "aws_secretsmanager_secret" "bedrock" {
  name        = "${var.project_name}/${var.environment}/bedrock"
  description = "Amazon Bedrock credentials for LLM access"

  recovery_window_in_days = 7

  tags = {
    Name        = "${var.project_name}-${var.environment}-bedrock-secret"
    Environment = var.environment
  }
}

resource "aws_secretsmanager_secret_version" "bedrock" {
  secret_id = aws_secretsmanager_secret.bedrock.id
  secret_string = jsonencode({
    access_key_id     = aws_iam_access_key.bedrock.id
    secret_access_key = aws_iam_access_key.bedrock.secret
    region            = var.aws_region
    model_id          = var.bedrock_model_id
  })
}

# -----------------------------------------------------------------------------
# CloudWatch Alarms for Bedrock Usage Monitoring
# -----------------------------------------------------------------------------
resource "aws_cloudwatch_metric_alarm" "bedrock_throttling" {
  alarm_name          = "${var.project_name}-${var.environment}-bedrock-throttling"
  comparison_operator = "GreaterThanThreshold"
  evaluation_periods  = 2
  metric_name         = "ThrottledCount"
  namespace           = "AWS/Bedrock"
  period              = 300
  statistic           = "Sum"
  threshold           = 10
  alarm_description   = "Bedrock API throttling detected"

  dimensions = {
    ModelId = var.bedrock_model_id
  }

  tags = {
    Name        = "${var.project_name}-${var.environment}-bedrock-throttling-alarm"
    Environment = var.environment
  }
}
