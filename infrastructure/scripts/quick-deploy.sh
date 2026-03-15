#!/bin/bash
set -e

#############################################
# CrimiKnow AWS Quick Deploy Script
# Run this in AWS CloudShell or locally with AWS CLI configured
#############################################

echo "=========================================="
echo "  CrimiKnow AWS Deployment"
echo "=========================================="
echo ""

# Colors for output
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
NC='\033[0m' # No Color

# Check prerequisites
check_prerequisites() {
    echo "Checking prerequisites..."
    
    if ! command -v aws &> /dev/null; then
        echo -e "${RED}Error: AWS CLI not installed${NC}"
        echo "Install: https://aws.amazon.com/cli/"
        exit 1
    fi
    
    if ! command -v terraform &> /dev/null; then
        echo -e "${YELLOW}Terraform not found. Installing...${NC}"
        if [[ "$OSTYPE" == "linux-gnu"* ]]; then
            sudo yum install -y yum-utils || sudo apt-get update
            sudo yum-config-manager --add-repo https://rpm.releases.hashicorp.com/AmazonLinux/hashicorp.repo || true
            sudo yum -y install terraform || sudo snap install terraform --classic
        elif [[ "$OSTYPE" == "darwin"* ]]; then
            brew install terraform
        else
            echo -e "${RED}Please install Terraform manually: https://terraform.io/downloads${NC}"
            exit 1
        fi
    fi
    
    # Check AWS credentials
    if ! aws sts get-caller-identity &> /dev/null; then
        echo -e "${RED}Error: AWS credentials not configured${NC}"
        echo "Run: aws configure"
        exit 1
    fi
    
    echo -e "${GREEN}Prerequisites OK${NC}"
}

# Gather user inputs
gather_inputs() {
    echo ""
    echo "=========================================="
    echo "  Configuration"
    echo "=========================================="
    echo ""
    
    # Project name
    read -p "Project name [crimiknow]: " PROJECT_NAME
    PROJECT_NAME=${PROJECT_NAME:-crimiknow}
    
    # Environment
    read -p "Environment (prod/staging) [prod]: " ENVIRONMENT
    ENVIRONMENT=${ENVIRONMENT:-prod}
    
    # Region
    echo ""
    echo "Available regions (choose closest to your users):"
    echo "  1) ap-southeast-1 (Singapore) - Recommended for PH"
    echo "  2) ap-northeast-1 (Tokyo)"
    echo "  3) us-east-1 (N. Virginia)"
    read -p "Select region [1]: " REGION_CHOICE
    case ${REGION_CHOICE:-1} in
        1) AWS_REGION="ap-southeast-1" ;;
        2) AWS_REGION="ap-northeast-1" ;;
        3) AWS_REGION="us-east-1" ;;
        *) AWS_REGION="ap-southeast-1" ;;
    esac
    
    # Database password
    echo ""
    while true; do
        read -s -p "Database password (min 8 chars, letters+numbers): " DB_PASSWORD
        echo ""
        if [[ ${#DB_PASSWORD} -ge 8 ]] && [[ "$DB_PASSWORD" =~ [A-Za-z] ]] && [[ "$DB_PASSWORD" =~ [0-9] ]]; then
            break
        fi
        echo -e "${RED}Password must be 8+ chars with letters and numbers${NC}"
    done
    
    # GitHub
    echo ""
    echo "GitHub Repository (for Amplify CI/CD):"
    read -p "GitHub repo URL (e.g., https://github.com/user/crimiknow): " GITHUB_REPO
    read -s -p "GitHub Personal Access Token (with repo scope): " GITHUB_TOKEN
    echo ""
    
    # Domain (optional)
    echo ""
    read -p "Custom domain (leave empty to skip): " DOMAIN_NAME
    
    # Existing API keys
    echo ""
    echo "=========================================="
    echo "  Your Existing API Keys"
    echo "=========================================="
    echo "(These will be securely stored in AWS Secrets Manager)"
    echo ""
    
    read -p "Azure AI Search Endpoint: " AZURE_SEARCH_ENDPOINT
    read -s -p "Azure AI Search API Key: " AZURE_SEARCH_API_KEY
    echo ""
    
    echo ""
    echo "Azure Blob Storage SAS URLs:"
    read -p "  Container C1 (crimiknowacademe): " AZURE_BLOB_C1
    read -p "  Container C2 (crimiknowacademe2): " AZURE_BLOB_C2
    read -p "  Container CB (barexam): " AZURE_BLOB_CB
    
    echo ""
    echo "Amazon Bedrock (LLM) - No API key needed!"
    echo "  Terraform will auto-create IAM credentials for Claude 3.5 Sonnet"
    echo "  Model: anthropic.claude-3-5-sonnet-20241022-v2:0"
    
    echo ""
    echo "Payment Providers:"
    read -p "PayPal Client ID: " PAYPAL_CLIENT_ID
    read -s -p "PayPal Client Secret: " PAYPAL_SECRET
    echo ""
    read -p "PayMongo API Key (or skip): " PAYMONGO_KEY
    
    # Confirmation
    echo ""
    echo "=========================================="
    echo "  Review Configuration"
    echo "=========================================="
    echo ""
    echo "Project: $PROJECT_NAME"
    echo "Environment: $ENVIRONMENT"
    echo "Region: $AWS_REGION"
    echo "GitHub Repo: $GITHUB_REPO"
    echo "Domain: ${DOMAIN_NAME:-None}"
    echo ""
    read -p "Proceed with deployment? (yes/no): " CONFIRM
    if [[ "$CONFIRM" != "yes" ]]; then
        echo "Deployment cancelled."
        exit 0
    fi
}

# Create Terraform state bucket
create_state_bucket() {
    echo ""
    echo "Creating Terraform state bucket..."
    
    ACCOUNT_ID=$(aws sts get-caller-identity --query Account --output text)
    STATE_BUCKET="${PROJECT_NAME}-terraform-state-${ACCOUNT_ID}"
    
    if aws s3 ls "s3://${STATE_BUCKET}" 2>&1 | grep -q 'NoSuchBucket'; then
        aws s3 mb "s3://${STATE_BUCKET}" --region "$AWS_REGION"
        aws s3api put-bucket-versioning --bucket "$STATE_BUCKET" --versioning-configuration Status=Enabled
        aws s3api put-bucket-encryption --bucket "$STATE_BUCKET" --server-side-encryption-configuration '{"Rules":[{"ApplyServerSideEncryptionByDefault":{"SSEAlgorithm":"AES256"}}]}'
        echo -e "${GREEN}State bucket created: ${STATE_BUCKET}${NC}"
    else
        echo "State bucket already exists: ${STATE_BUCKET}"
    fi
}

# Generate tfvars file
generate_tfvars() {
    echo ""
    echo "Generating Terraform variables..."
    
    SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
    TERRAFORM_DIR="$(dirname "$SCRIPT_DIR")/terraform"
    
    cat > "${TERRAFORM_DIR}/auto-generated.tfvars" << EOF
# Auto-generated by quick-deploy.sh
# $(date)

project_name = "${PROJECT_NAME}"
environment  = "${ENVIRONMENT}"
aws_region   = "${AWS_REGION}"

# Database
db_password = "${DB_PASSWORD}"

# GitHub
github_repository   = "${GITHUB_REPO}"
github_access_token = "${GITHUB_TOKEN}"

# Domain
domain_name = "${DOMAIN_NAME}"

# Azure (keeping existing)
azure_search_endpoint = "${AZURE_SEARCH_ENDPOINT}"
azure_search_api_key  = "${AZURE_SEARCH_API_KEY}"
azure_blob_c1_url     = "${AZURE_BLOB_C1}"
azure_blob_c2_url     = "${AZURE_BLOB_C2}"
azure_blob_cb_url     = "${AZURE_BLOB_CB}"

# Amazon Bedrock (LLM) - IAM credentials auto-created by Terraform
bedrock_model_id = "anthropic.claude-3-5-sonnet-20241022-v2:0"

# Payments
paypal_client_id     = "${PAYPAL_CLIENT_ID}"
paypal_client_secret = "${PAYPAL_SECRET}"
paymongo_api_key     = "${PAYMONGO_KEY}"
EOF

    # Update backend.tf with correct bucket
    sed -i.bak "s/BUCKET_NAME_PLACEHOLDER/${STATE_BUCKET}/g" "${TERRAFORM_DIR}/backend.tf" 2>/dev/null || \
    sed -i '' "s/BUCKET_NAME_PLACEHOLDER/${STATE_BUCKET}/g" "${TERRAFORM_DIR}/backend.tf"
    
    echo -e "${GREEN}Variables file created${NC}"
}

# Run Terraform
run_terraform() {
    echo ""
    echo "=========================================="
    echo "  Deploying to AWS"
    echo "=========================================="
    echo ""
    
    SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
    TERRAFORM_DIR="$(dirname "$SCRIPT_DIR")/terraform"
    cd "$TERRAFORM_DIR"
    
    echo "Initializing Terraform..."
    terraform init
    
    echo ""
    echo "Planning deployment..."
    terraform plan -var-file=auto-generated.tfvars -out=tfplan
    
    echo ""
    echo -e "${YELLOW}Review the plan above.${NC}"
    read -p "Apply this plan? (yes/no): " APPLY_CONFIRM
    
    if [[ "$APPLY_CONFIRM" == "yes" ]]; then
        echo ""
        echo "Deploying... (this takes 15-20 minutes)"
        terraform apply tfplan
        
        echo ""
        echo -e "${GREEN}=========================================="
        echo "  Deployment Complete!"
        echo "==========================================${NC}"
        echo ""
        terraform output
        
        # Save outputs
        terraform output -json > deployment-outputs.json
        echo ""
        echo "Outputs saved to: ${TERRAFORM_DIR}/deployment-outputs.json"
    else
        echo "Deployment cancelled."
        exit 0
    fi
}

# Post-deployment instructions
post_deployment() {
    echo ""
    echo "=========================================="
    echo "  Next Steps"
    echo "=========================================="
    echo ""
    echo "1. Database Migration:"
    echo "   cd infrastructure/scripts"
    echo "   ./migrate-db.sh"
    echo ""
    echo "2. Verify your app:"
    echo "   Open the Amplify URL from the outputs above"
    echo ""
    echo "3. Set up custom domain (optional):"
    echo "   - Go to AWS Amplify Console"
    echo "   - Click 'Domain management'"
    echo "   - Add your domain"
    echo ""
    echo "4. Monitor costs:"
    echo "   https://console.aws.amazon.com/cost-management"
    echo ""
    echo -e "${GREEN}Deployment successful!${NC}"
}

# Main
main() {
    check_prerequisites
    gather_inputs
    create_state_bucket
    generate_tfvars
    run_terraform
    post_deployment
}

main "$@"
