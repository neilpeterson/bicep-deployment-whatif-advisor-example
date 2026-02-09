# Bicep Deployment with What-If Advisor

This sample repository demonstrates how to use the [bicep-whatif-advisor](https://github.com/neilpeterson/bicep-whatif-advisor) tool in a GitHub Actions CI/CD pipeline for Azure Bicep deployments.

## Overview

The `bicep-whatif-advisor` tool enhances Azure deployment workflows by providing AI-powered analysis of `az deployment group what-if` output. It helps teams understand the impact of infrastructure changes before deployment.

### Workflow Structure

```
PR Created/Updated          Push to Main / Manual Trigger
        │                              │
        ▼                              ▼
┌─────────────────┐      ┌─────────────────────────────────────┐
│   pr-review     │      │  whatif-pre-prod  │  whatif-prod    │
│ (both envs)     │      │     (parallel)    │   (parallel)    │
└─────────────────┘      └─────────┬─────────┴────────┬────────┘
                                   │                  │
                                   └────────┬─────────┘
                                            │ (both must pass)
                                            ▼
                                ┌───────────────────────┐
                                │ deploy-pre-production │
                                └───────────┬───────────┘
                                            │
                                            ▼
                                ┌───────────────────────┐
                                │   deploy-production   │
                                └───────────────────────┘
```

## Prerequisites

- Azure subscription
- Azure resource groups for pre-production and production environments
- [Anthropic API key](https://console.anthropic.com/) for AI-powered analysis
- GitHub repository with Actions enabled

## Setup Overview

Setting up this sample involves four main steps:

1. **Azure Authentication** — Create an Azure AD application with federated credentials for passwordless GitHub Actions authentication (OIDC)
2. **GitHub Secrets** — Store Azure credentials and Anthropic API key securely in your repository
3. **GitHub Variables** — Configure environment-specific resource group names
4. **GitHub Environments** — (Optional) Add approval gates for production deployments

## Required Configuration

### GitHub Secrets

| Secret | Description | Source |
|--------|-------------|--------|
| `AZURE_CLIENT_ID` | Azure AD application (client) ID | Azure AD app registration |
| `AZURE_TENANT_ID` | Azure AD tenant ID | Azure portal |
| `AZURE_SUBSCRIPTION_ID` | Azure subscription ID | Azure portal |
| `ANTHROPIC_API_KEY` | API key for AI analysis | [Anthropic Console](https://console.anthropic.com/) |

### GitHub Variables

| Variable | Description | Example |
|----------|-------------|---------|
| `AZURE_RESOURCE_GROUP_PRE_PRODUCTION` | Resource group for pre-production | `rg-myapp-preprod` |
| `AZURE_RESOURCE_GROUP_PRODUCTION` | Resource group for production | `rg-myapp-prod` |

### GitHub Environments (Optional)

| Environment | Purpose |
|-------------|---------|
| `pre-production` | First deployment target |
| `production` | Second deployment target (can require approval) |

## Setup Instructions

### 1. Create Azure Service Principal with OIDC

Configure workload identity federation for secure, secretless authentication:

```bash
# Set variables
AZURE_SUBSCRIPTION_ID="<your-subscription-id>"
APP_NAME="github-actions-bicep-deploy"
GITHUB_ORG="<your-github-org>"
GITHUB_REPO="<your-repo-name>"

# Create Azure AD application
az ad app create --display-name $APP_NAME
APP_ID=$(az ad app list --display-name $APP_NAME --query "[0].appId" -o tsv)

# Create service principal
az ad sp create --id $APP_ID
SP_OBJECT_ID=$(az ad sp list --filter "appId eq '$APP_ID'" --query "[0].id" -o tsv)

# Assign Contributor role to resource groups
az role assignment create \
  --assignee-object-id $SP_OBJECT_ID \
  --assignee-principal-type ServicePrincipal \
  --role "Contributor" \
  --scope "/subscriptions/$AZURE_SUBSCRIPTION_ID/resourceGroups/<pre-prod-rg>"

az role assignment create \
  --assignee-object-id $SP_OBJECT_ID \
  --assignee-principal-type ServicePrincipal \
  --role "Contributor" \
  --scope "/subscriptions/$AZURE_SUBSCRIPTION_ID/resourceGroups/<prod-rg>"

# Add federated credentials for GitHub Actions
# For pushes to main branch
az ad app federated-credential create --id $APP_ID --parameters '{
  "name": "github-main",
  "issuer": "https://token.actions.githubusercontent.com",
  "subject": "repo:'$GITHUB_ORG'/'$GITHUB_REPO':ref:refs/heads/main",
  "audiences": ["api://AzureADTokenExchange"]
}'

# For pull requests
az ad app federated-credential create --id $APP_ID --parameters '{
  "name": "github-pr",
  "issuer": "https://token.actions.githubusercontent.com",
  "subject": "repo:'$GITHUB_ORG'/'$GITHUB_REPO':pull_request",
  "audiences": ["api://AzureADTokenExchange"]
}'

# For environment: pre-production
az ad app federated-credential create --id $APP_ID --parameters '{
  "name": "github-env-preprod",
  "issuer": "https://token.actions.githubusercontent.com",
  "subject": "repo:'$GITHUB_ORG'/'$GITHUB_REPO':environment:pre-production",
  "audiences": ["api://AzureADTokenExchange"]
}'

# For environment: production
az ad app federated-credential create --id $APP_ID --parameters '{
  "name": "github-env-prod",
  "issuer": "https://token.actions.githubusercontent.com",
  "subject": "repo:'$GITHUB_ORG'/'$GITHUB_REPO':environment:production",
  "audiences": ["api://AzureADTokenExchange"]
}'

# Get values for GitHub secrets
echo "AZURE_CLIENT_ID: $APP_ID"
echo "AZURE_TENANT_ID: $(az account show --query tenantId -o tsv)"
echo "AZURE_SUBSCRIPTION_ID: $AZURE_SUBSCRIPTION_ID"
```

### 2. Configure GitHub Secrets

Go to **Settings → Secrets and variables → Actions → Secrets** and add:

| Secret | Description |
|--------|-------------|
| `AZURE_CLIENT_ID` | Azure AD application (client) ID |
| `AZURE_TENANT_ID` | Azure AD tenant ID |
| `AZURE_SUBSCRIPTION_ID` | Azure subscription ID |
| `ANTHROPIC_API_KEY` | API key from [Anthropic Console](https://console.anthropic.com/) |

### 3. Configure GitHub Variables

Go to **Settings → Secrets and variables → Actions → Variables** and add:

| Variable | Description |
|----------|-------------|
| `AZURE_RESOURCE_GROUP_PRE_PRODUCTION` | Resource group name for pre-production |
| `AZURE_RESOURCE_GROUP_PRODUCTION` | Resource group name for production |

### 4. Create GitHub Environments (Optional but Recommended)

For deployment protection rules, create environments:

1. Go to **Settings → Environments**
2. Create `pre-production` environment
3. Create `production` environment
   - Enable **Required reviewers** and add approvers
   - Optionally add **Wait timer** for additional safety

### 5. Update Bicep Parameter Files

Modify the parameter files in `bicep-deployment/` to match your Azure resources:

- `pre-production.bicepparam` - Pre-production environment parameters
- `production.bicepparam` - Production environment parameters

## Usage

### Pull Request Workflow

When a PR is opened against `main` that modifies files in `bicep-deployment/`:

1. What-if analysis runs for both environments
2. AI-powered summary is posted as a PR comment
3. Safety gate blocks merge if high-risk changes are detected

### Deployment Workflow

When changes are pushed to `main` (or manually triggered):

1. What-if analysis runs for **both** environments in parallel
2. If either fails, no deployments proceed
3. Pre-production deploys first
4. Production deploys only after pre-production succeeds

## Repository Structure

```
├── .github/
│   └── workflows/
│       └── bicep-sample-pipeline.yml    # GitHub Actions workflow
├── bicep-deployment/
│   ├── main.bicep                       # Main Bicep template
│   ├── pre-production.bicepparam        # Pre-production parameters
│   ├── production.bicepparam            # Production parameters
│   └── policy-logic/                    # Additional policy files
│       ├── apim-policy.xml
│       └── sce-jwt-parsing-and-logging.xml
└── README.md
```

## Related Resources

- [bicep-whatif-advisor on GitHub](https://github.com/neilpeterson/bicep-whatif-advisor)
- [bicep-whatif-advisor on PyPI](https://pypi.org/project/bicep-whatif-advisor/)
- [Azure Bicep Documentation](https://learn.microsoft.com/azure/azure-resource-manager/bicep/)
- [GitHub Actions OIDC with Azure](https://learn.microsoft.com/azure/developer/github/connect-from-azure)

## License

MIT
