# Azure DevOps Pipeline Setup

This directory contains the Azure DevOps pipeline configuration for deploying Bicep templates with what-if analysis using the `bicep-whatif-advisor` tool.

## Pipeline Overview

The pipeline includes four stages:

1. **PR Review**: Runs on pull requests, executes what-if analysis for both pre-production and production environments, and posts AI-generated summaries as PR comments
2. **Validate**: Runs on pushes to main branch, performs what-if analysis and publishes results as artifacts
3. **Deploy Pre-Production**: Deploys to pre-production environment after successful validation
4. **Deploy Production**: Deploys to production environment after successful pre-production deployment

## Prerequisites

### 1. Azure Service Connection

Create an Azure Resource Manager service connection in Azure DevOps:

- Go to **Project Settings** > **Service connections**
- Create a new **Azure Resource Manager** service connection
- Use **Service principal (automatic)** or **Service principal (manual)**
- Name it (e.g., `azure-service-connection`)
- Grant it access to the appropriate Azure subscription and resource groups

### 2. Variable Groups or Pipeline Variables

Set up the following variables in your pipeline:

| Variable Name | Description | Example |
|---------------|-------------|---------|
| `AZURE_SERVICE_CONNECTION` | Name of your Azure service connection | `azure-service-connection` |
| `AZURE_RESOURCE_GROUP_PRE_PRODUCTION` | Pre-production resource group name | `rg-app-preprod` |
| `AZURE_RESOURCE_GROUP_PRODUCTION` | Production resource group name | `rg-app-prod` |
| `ANTHROPIC_API_KEY` | API key for Claude (mark as secret) | `sk-ant-...` |

#### To create a variable group:

1. Go to **Pipelines** > **Library**
2. Create a new variable group (e.g., `bicep-deployment-vars`)
3. Add the variables listed above
4. Mark `ANTHROPIC_API_KEY` as secret
5. Link the variable group to your pipeline

### 3. Environments

Create the following environments in Azure DevOps:

- Go to **Pipelines** > **Environments**
- Create `pre-production` environment
- Create `production` environment
- Optionally add approvals and checks for the production environment

### 4. Enable System.AccessToken

The pipeline uses `System.AccessToken` to post PR comments. Ensure this is enabled:

1. Go to **Project Settings** > **Pipelines** > **Settings**
2. Enable **Limit job authorization scope to current project**
3. In your pipeline, the token is automatically available via `$(System.AccessToken)`

Alternatively, you can grant the build service permissions:

- Go to **Project Settings** > **Repositories** > **Security**
- Find **[Project Name] Build Service**
- Grant **Contribute to pull requests** permission

## Pipeline Configuration

### Triggers

- **Push to main**: Runs validation and deployment stages
- **Pull requests to main**: Runs PR review stage with what-if analysis
- **Manual**: Can be triggered manually via Azure DevOps UI

### Path Filters

The pipeline only runs when changes are made to:
- `bicep-deployment/*`
- `pipelines/azure-pipelines.yml`

## Using the Pipeline

### Pull Request Workflow

1. Create a branch and make changes to Bicep templates
2. Open a pull request to main
3. The pipeline automatically runs what-if analysis
4. Review the AI-generated summaries posted as PR comments
5. Merge the PR if changes look good

### Deployment Workflow

1. Merge PR to main branch
2. Pipeline automatically runs validation
3. What-if results are published as build artifacts
4. If validation passes, deployment to pre-production begins
5. After pre-production succeeds, deployment to production begins
6. Review environment approvals if configured

## Customization

### Adjusting Python Version

Modify the `PYTHON_VERSION` variable at the top of the pipeline:

```yaml
variables:
  PYTHON_VERSION: '3.11'
```

### Adding More Environments

To add additional environments (e.g., dev, staging), extend the matrix strategy:

```yaml
strategy:
  matrix:
    Dev:
      ENVIRONMENT_NAME: 'dev'
      BICEP_PARAMS: './bicep-deployment/dev.bicepparam'
      RESOURCE_GROUP: $(AZURE_RESOURCE_GROUP_DEV)
    PreProduction:
      # ... existing configuration
```

### Modifying What-If Advisor Options

The `bicep-whatif-advisor` tool supports several options:

- `--no-block`: Don't block on high-risk changes (useful for PR reviews)
- `--comment-title`: Custom title for PR comments
- `--format markdown`: Output format (markdown, json, text)
- `--bicep-dir`: Directory containing Bicep files for better context

Adjust these in the pipeline script as needed.

## Troubleshooting

### Permission Errors

If you see permission errors when posting PR comments:
- Verify `System.AccessToken` is being passed correctly
- Check build service permissions in repository security settings
- Ensure the build service has "Contribute to pull requests" permission

### What-If Analysis Fails

If the what-if analysis step fails:
- Verify the Azure service connection has appropriate permissions
- Check that resource groups exist
- Ensure Bicep template and parameter files are valid
- Review Azure CLI version compatibility

### Anthropic API Key Issues

If the AI analysis isn't working:
- Verify the `ANTHROPIC_API_KEY` variable is set correctly
- Ensure it's marked as secret in the variable group
- Check the API key has sufficient credits

## Additional Resources

- [bicep-whatif-advisor GitHub Repository](https://github.com/neilpeterson/bicep-whatif-advisor)
- [Azure DevOps Pipelines Documentation](https://learn.microsoft.com/en-us/azure/devops/pipelines/)
- [Azure Bicep What-If Documentation](https://learn.microsoft.com/en-us/azure/azure-resource-manager/bicep/deploy-what-if)
