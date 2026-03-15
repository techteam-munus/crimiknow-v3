# =============================================================================
# Terraform State Backend Configuration
# =============================================================================
# 
# Before running terraform init, create the S3 bucket and DynamoDB table:
#
# aws s3api create-bucket \
#   --bucket crimiknow-terraform-state \
#   --region ap-southeast-1 \
#   --create-bucket-configuration LocationConstraint=ap-southeast-1
#
# aws s3api put-bucket-versioning \
#   --bucket crimiknow-terraform-state \
#   --versioning-configuration Status=Enabled
#
# aws s3api put-bucket-encryption \
#   --bucket crimiknow-terraform-state \
#   --server-side-encryption-configuration '{
#     "Rules": [{"ApplyServerSideEncryptionByDefault": {"SSEAlgorithm": "AES256"}}]
#   }'
#
# aws dynamodb create-table \
#   --table-name crimiknow-terraform-locks \
#   --attribute-definitions AttributeName=LockID,AttributeType=S \
#   --key-schema AttributeName=LockID,KeyType=HASH \
#   --billing-mode PAY_PER_REQUEST \
#   --region ap-southeast-1
# =============================================================================

# Option 1: Use the quick-deploy.sh script (recommended)
# The script will auto-configure this backend

# Option 2: Manual setup - uncomment and configure:
# terraform {
#   backend "s3" {
#     bucket         = "YOUR-BUCKET-NAME"
#     key            = "crimiknow/terraform.tfstate"
#     region         = "ap-southeast-1"
#     encrypt        = true
#   }
# }

# Option 3: Local state (for testing only)
terraform {
  backend "local" {
    path = "terraform.tfstate"
  }
}
