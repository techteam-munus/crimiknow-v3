# CrimiKnow AWS Deployment - Quick Start

## Prerequisites

1. **AWS Account** with admin access
2. **GitHub Repository** with your CrimiKnow code
3. **Your existing credentials:**
   - Azure AI Search endpoint + API key (keeping these)
   - Azure Blob SAS URLs (keeping these)
   - PayPal/PayMongo API keys

### LLM: Amazon Bedrock (No API Key Needed!)

This deployment uses **Amazon Bedrock** with **Claude 3.5 Sonnet** for the AI/LLM.
- No API key required - Terraform automatically creates IAM credentials
- Pay-as-you-go through your AWS account
- Same region as your app = lower latency
- Claude 3.5 Sonnet is comparable to Gemini Pro in quality

---

## Option A: One-Click Deploy (Recommended)

### Step 1: Open AWS CloudShell

1. Log into [AWS Console](https://console.aws.amazon.com)
2. Click the terminal icon (top right) → CloudShell opens
3. CloudShell already has AWS CLI + Terraform installed

### Step 2: Download and Run

```bash
# Clone your repo (or upload the infrastructure folder)
git clone https://github.com/YOUR_USERNAME/crimiknow.git
cd crimiknow/infrastructure/terraform

# Run the automated setup
chmod +x ../scripts/quick-deploy.sh
../scripts/quick-deploy.sh
```

The script will prompt you for:
- Project name (e.g., "crimiknow")
- Environment (prod/staging)
- Database password
- GitHub repo URL + access token
- Your existing API keys

That's it! The script handles everything else.

---

## Option B: Manual Step-by-Step

### Step 1: Install Tools (skip if using CloudShell)

```bash
# macOS
brew install awscli terraform

# Windows
choco install awscli terraform

# Linux
sudo apt install awscli && sudo snap install terraform
```

### Step 2: Configure AWS Credentials

```bash
aws configure
# Enter your:
# - AWS Access Key ID
# - AWS Secret Access Key  
# - Region: ap-southeast-1 (Singapore - closest to PH)
# - Output format: json
```

### Step 3: Create S3 Bucket for Terraform State

```bash
aws s3 mb s3://crimiknow-terraform-state-$(aws sts get-caller-identity --query Account --output text)
```

### Step 4: Initialize Terraform

```bash
cd infrastructure/terraform

# Edit the backend bucket name in backend.tf (use the bucket you just created)

terraform init
```

### Step 5: Create Your Variables File

```bash
cp environments/prod.tfvars my-prod.tfvars
```

Edit `my-prod.tfvars` with your values:
```hcl
project_name = "crimiknow"
environment  = "prod"
aws_region   = "ap-southeast-1"

# Database
db_password = "YourSecurePassword123!"

# GitHub (for Amplify CI/CD)
github_repository = "https://github.com/YOUR_USER/crimiknow"
github_access_token = "ghp_xxxxxxxxxxxx"

# Domain (optional)
domain_name = "crimiknow.com"

# Your existing API keys (will be stored in AWS Secrets Manager)
azure_search_endpoint = "https://your-search.search.windows.net"
azure_search_api_key = "your-azure-key"
azure_blob_c1_url = "https://crimiknowacademe.blob.core.windows.net/..."
azure_blob_c2_url = "https://crimiknowacademe2.blob.core.windows.net/..."
azure_blob_cb_url = "https://crimiknowbarexam.blob.core.windows.net/..."

# Bedrock (no API key needed - auto-configured via IAM)
bedrock_model_id = "anthropic.claude-3-5-sonnet-20241022-v2:0"

paypal_client_id = "your-paypal-client-id"
paypal_client_secret = "your-paypal-secret"
```

### Step 6: Preview Changes

```bash
terraform plan -var-file=my-prod.tfvars
```

Review the output - it shows what AWS resources will be created.

### Step 7: Deploy

```bash
terraform apply -var-file=my-prod.tfvars
```

Type `yes` when prompted. Takes ~15-20 minutes.

### Step 8: Note the Outputs

After deployment, Terraform prints:
```
Outputs:

amplify_app_url = "https://main.d1234567890.amplifyapp.com"
database_endpoint = "crimiknow-db.xxxxx.ap-southeast-1.rds.amazonaws.com"
cognito_user_pool_id = "ap-southeast-1_XXXXXXX"
```

Save these - you'll need them for the database migration.

### Step 9: Migrate Database

```bash
chmod +x ../scripts/migrate-db.sh
../scripts/migrate-db.sh
```

The script will:
1. Export data from Supabase
2. Import into RDS PostgreSQL
3. Verify the migration

---

## After Deployment

### Your App URL
Visit the Amplify URL from the outputs, or set up your custom domain in AWS Amplify Console.

### Monitoring
- **CloudWatch Dashboard**: Auto-created at `https://console.aws.amazon.com/cloudwatch`
- **RDS Performance**: Check in RDS Console
- **Amplify Builds**: Check in Amplify Console

### Costs
Check real-time costs at: `https://console.aws.amazon.com/cost-management`

---

## Troubleshooting

### "Access Denied" errors
```bash
# Check your AWS credentials
aws sts get-caller-identity
```

### Terraform state issues
```bash
terraform init -reconfigure
```

### Database connection issues
- Check Security Group allows your IP
- Verify password in Secrets Manager

### Need help?
Open an issue on GitHub or check AWS CloudWatch logs.

---

## Tear Down (if needed)

To delete all AWS resources:
```bash
terraform destroy -var-file=my-prod.tfvars
```

⚠️ This deletes everything including the database!
