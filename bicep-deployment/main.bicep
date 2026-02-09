param apimName string

@description('Publisher email for APIM')
param publisherEmail string

@description('Publisher name for APIM')
param publisherName string

@description('Name of the Application Insights instance')
param appInsightsName string

@description('Headers to log in APIM diagnostics (backend request)')
param headersToLog array = []

@description('Name of the storage account')
param storageAccountName string

@description('Name of the Key Vault')
param keyVaultName string

resource apiManagementInstance 'Microsoft.ApiManagement/service@2022-08-01' = {
  name: apimName
  location: resourceGroup().location
  sku: {
    name: 'Developer'
    capacity: 1
  }
  properties: {
    publisherEmail: publisherEmail
    publisherName: publisherName
    virtualNetworkType: 'None'
  }
}

// Application Insights instance
resource appInsights 'Microsoft.Insights/components@2020-02-02' = {
  name: appInsightsName
  location: resourceGroup().location
  kind: 'web'
  properties: {
    Application_Type: 'web'
    publicNetworkAccessForIngestion: 'Enabled'
    publicNetworkAccessForQuery: 'Enabled'
  }
}

// APIM Logger for Application Insights
resource apimLogger 'Microsoft.ApiManagement/service/loggers@2022-08-01' = {
  parent: apiManagementInstance
  name: appInsightsName
  properties: {
    loggerType: 'applicationInsights'
    credentials: {
      instrumentationKey: appInsights.properties.InstrumentationKey
    }
    resourceId: appInsights.id
  }
}

// Application Insights diagnostics
resource apimDiagnosticsAppInsights 'Microsoft.ApiManagement/service/diagnostics@2023-03-01-preview' = {
  parent: apiManagementInstance
  name: 'applicationinsights'
  properties: {
    alwaysLog: 'allErrors'
    httpCorrelationProtocol: 'Legacy'
    verbosity: 'information'
    logClientIp: true
    loggerId: apimLogger.id
    sampling: {
      samplingType: 'fixed'
      percentage: 100
    }
    frontend: {
      request: { headers: headersToLog, body: { bytes: 0 } }
      response: { headers: headersToLog, body: { bytes: 0 } }
    }
    backend: {
      request: { headers: headersToLog, body: { bytes: 0 } }
      response: { headers: headersToLog, body: { bytes: 0 } }
    }
  }
}

resource storageAccount 'Microsoft.Storage/storageAccounts@2025-01-01' = {
  name: storageAccountName
  location: 'centralus'
  sku: {
    name: 'Standard_LRS'
  }
  kind: 'StorageV2'
  tags: {
    Environment: 'Production'
    ManagedBy: 'Bicep'
  }
  properties: {
    minimumTlsVersion: 'TLS1_2'
    allowBlobPublicAccess: false
    accessTier: 'Hot'
    publicNetworkAccess: 'Disabled'
  }
}

resource keyVault 'Microsoft.KeyVault/vaults@2023-07-01' = {
  name: keyVaultName
  location: resourceGroup().location
  properties: {
    tenantId: subscription().tenantId
    sku: {
      family: 'A'
      name: 'standard'
    }
    enableRbacAuthorization: true
    enableSoftDelete: true
    softDeleteRetentionInDays: 90
    publicNetworkAccess: 'Disabled'
    networkAcls: {
      defaultAction: 'Deny'
      bypass: 'AzureServices'
    }
  }
}


