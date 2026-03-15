# AWS Deployment Guide - Using Amazon Bedrock

This guide shows the exact code changes needed to deploy CrimiKnow to AWS using Amazon Bedrock instead of Vercel AI Gateway.

---

## Overview

| Environment | AI Provider | Model String Format |
|-------------|-------------|---------------------|
| v0 / Vercel | Vercel AI Gateway | `google/gemini-3-flash`, `anthropic/claude-3-opus` |
| AWS | Amazon Bedrock | `anthropic.claude-3-5-sonnet-20241022-v2:0` |

---

## Code Changes Required

### File: `/app/api/chat/route.ts`

#### CHANGE 1: Add Bedrock Import (Line 1-3)

**CURRENT CODE (Vercel AI Gateway):**
```typescript
import { createClient } from '@/lib/supabase/server'
import { createClient as createSupabaseClient } from '@supabase/supabase-js'
```

**CHANGE TO (Amazon Bedrock):**
```typescript
import { createClient } from '@/lib/supabase/server'
import { createClient as createSupabaseClient } from '@supabase/supabase-js'
import { bedrock } from '@ai-sdk/amazon-bedrock'
```

---

#### CHANGE 2: Model Initialization (Around Line 681-691)

**CURRENT CODE (Vercel AI Gateway):**
```typescript
let activeModel = process.env.AI_MODEL || 'google/gemini-3-flash'
try {
  const { data: modelSetting } = await supabaseAdmin
    .from('app_settings')
    .select('value')
    .eq('key', 'ai_model')
    .maybeSingle()
  if (modelSetting?.value) activeModel = modelSetting.value
} catch { /* use default */ }
```

**CHANGE TO (Amazon Bedrock):**
```typescript
// Default Bedrock model - Claude 3.5 Sonnet v2 recommended for legal analysis
let modelId = process.env.AI_MODEL || 'anthropic.claude-3-5-sonnet-20241022-v2:0'
try {
  const { data: modelSetting } = await supabaseAdmin
    .from('app_settings')
    .select('value')
    .eq('key', 'ai_model')
    .maybeSingle()
  if (modelSetting?.value) modelId = modelSetting.value
} catch { /* use default */ }

// Create Bedrock model instance
const activeModel = bedrock(modelId)
```

---

#### CHANGE 3: StreamText Call (Around Line 790-796)

**CURRENT CODE (Vercel AI Gateway):**
```typescript
const result = streamText({
  model: activeModel,  // String like 'google/gemini-3-flash'
  system: sysPrompt,
  messages: messagesWithCitations,
  maxOutputTokens: 16000,
  temperature: 0.3,
})
```

**CHANGE TO (Amazon Bedrock):**
```typescript
const result = streamText({
  model: activeModel,  // Now a Bedrock model instance
  system: sysPrompt,
  messages: messagesWithCitations,
  maxTokens: 16000,  // Note: Bedrock uses 'maxTokens' not 'maxOutputTokens'
  temperature: 0.3,
})
```

---

## Environment Variables for AWS

Add these to your Terraform or AWS Amplify environment variables:

```hcl
# Required for Bedrock
AWS_ACCESS_KEY_ID     = "your-access-key"
AWS_SECRET_ACCESS_KEY = "your-secret-key"
AWS_REGION            = "us-east-1"  # or your preferred region

# Optional - override default model
AI_MODEL              = "anthropic.claude-3-5-sonnet-20241022-v2:0"

# Existing variables (keep these)
NEXT_PUBLIC_SUPABASE_URL    = "..."
NEXT_PUBLIC_SUPABASE_ANON_KEY = "..."
SUPABASE_SERVICE_ROLE_KEY   = "..."
AZURE_SEARCH_ENDPOINT       = "..."
AZURE_SEARCH_API_KEY        = "..."
```

---

## NPM Dependencies

Add to `package.json`:

```json
{
  "dependencies": {
    "@ai-sdk/amazon-bedrock": "^1.0.0"
  }
}
```

---

## Available Bedrock Models

| Model ID | Description | Recommended For |
|----------|-------------|-----------------|
| `anthropic.claude-3-5-sonnet-20241022-v2:0` | Claude 3.5 Sonnet v2 | Best balance of quality/speed |
| `anthropic.claude-3-opus-20240229-v1:0` | Claude 3 Opus | Highest quality, complex reasoning |
| `anthropic.claude-3-sonnet-20240229-v1:0` | Claude 3 Sonnet | Good quality, faster |
| `anthropic.claude-3-haiku-20240307-v1:0` | Claude 3 Haiku | Fastest, lower cost |

---

## Admin Page Model Selection

Update your admin page dropdown to use Bedrock model IDs instead of Vercel AI Gateway model strings:

| Admin Display Name | Model ID Value |
|--------------------|----------------|
| Claude 3.5 Sonnet v2 | `anthropic.claude-3-5-sonnet-20241022-v2:0` |
| Claude 3 Opus | `anthropic.claude-3-opus-20240229-v1:0` |
| Claude 3 Sonnet | `anthropic.claude-3-sonnet-20240229-v1:0` |
| Claude 3 Haiku | `anthropic.claude-3-haiku-20240307-v1:0` |

---

## Quick Deployment Checklist

1. [ ] Add `@ai-sdk/amazon-bedrock` to package.json
2. [ ] Update imports in `/app/api/chat/route.ts`
3. [ ] Update model initialization code
4. [ ] Update streamText call (`maxTokens` instead of `maxOutputTokens`)
5. [ ] Set AWS credentials in environment variables
6. [ ] Update admin page model dropdown options
7. [ ] Deploy via Terraform/Amplify

---

## Terraform Example

```hcl
resource "aws_amplify_app" "crimiknow" {
  name       = "crimiknow"
  repository = "https://github.com/your-org/crimiknow"

  environment_variables = {
    AWS_REGION                    = "us-east-1"
    AI_MODEL                      = "anthropic.claude-3-5-sonnet-20241022-v2:0"
    NEXT_PUBLIC_SUPABASE_URL      = var.supabase_url
    NEXT_PUBLIC_SUPABASE_ANON_KEY = var.supabase_anon_key
    SUPABASE_SERVICE_ROLE_KEY     = var.supabase_service_key
    AZURE_SEARCH_ENDPOINT         = var.azure_search_endpoint
    AZURE_SEARCH_API_KEY          = var.azure_search_api_key
  }
}

# IAM role for Bedrock access
resource "aws_iam_role_policy" "bedrock_access" {
  name = "bedrock-access"
  role = aws_iam_role.amplify_role.id

  policy = jsonencode({
    Version = "2012-10-17"
    Statement = [
      {
        Effect = "Allow"
        Action = [
          "bedrock:InvokeModel",
          "bedrock:InvokeModelWithResponseStream"
        ]
        Resource = "arn:aws:bedrock:*::foundation-model/*"
      }
    ]
  })
}
```
