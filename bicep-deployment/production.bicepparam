using 'main.bicep'

param vnetName = 'vnet-nepeters-prd'
param logAnalyticsName = 'law-nepeters-prd'

param branches = [
  {
    branchOfficeName: 'paris-prd'
    storageAccountName: 'stgprdparisbranch'
    appServicePlanName: 'asp-paris-prd-branch'
    webAppName: 'app-paris-prd-branch'
    breakSFI: false
    keyVaultName: 'akv-prd-paris-01-branch'
    nsgRulePriority: 205
    ipAddress: '71.197.100.86'
  }
]
