# OrderItemsReserver Deployment Script
# This script automates the deployment of the OrderItemsReserver service to Azure

param(
    [Parameter(Mandatory = $true)]
    [string]$ResourceGroupName,
    
    [Parameter(Mandatory = $true)]
    [string]$Location,
    
    [Parameter(Mandatory = $true)]
    [string]$SubscriptionId,
    
    [Parameter(Mandatory = $true)]
    [string]$FunctionAppName,
    
    [Parameter(Mandatory = $true)]
    [string]$StorageAccountName,
    
    [Parameter(Mandatory = $true)]
    [string]$WebAppName,
    
    [Parameter(Mandatory = $true)]
    [string]$AppServicePlanName
)

# Color output functions
function Write-Success {
    param([string]$Message)
    Write-Host "✓ $Message" -ForegroundColor Green
}

function Write-Error {
    param([string]$Message)
    Write-Host "✗ $Message" -ForegroundColor Red
}

function Write-Info {
    param([string]$Message)
    Write-Host "ℹ $Message" -ForegroundColor Cyan
}

# Set subscription
Write-Info "Setting subscription to $SubscriptionId..."
az account set --subscription $SubscriptionId
if ($LASTEXITCODE -eq 0) { Write-Success "Subscription set" } else { Write-Error "Failed to set subscription"; exit 1 }

# Create resource group
Write-Info "Creating resource group: $ResourceGroupName..."
az group create --name $ResourceGroupName --location $Location
if ($LASTEXITCODE -eq 0) { Write-Success "Resource group created" } else { Write-Error "Failed to create resource group"; exit 1 }

# Create storage account
Write-Info "Creating storage account: $StorageAccountName..."
az storage account create `
    --name $StorageAccountName `
    --resource-group $ResourceGroupName `
    --location $Location `
    --sku Standard_LRS `
    --allow-blob-public-access false

if ($LASTEXITCODE -eq 0) { Write-Success "Storage account created" } else { Write-Error "Failed to create storage account"; exit 1 }

# Get storage connection string
Write-Info "Retrieving storage connection string..."
$ConnectionString = az storage account show-connection-string `
    --name $StorageAccountName `
    --resource-group $ResourceGroupName `
    --query connectionString -o tsv

if ($null -eq $ConnectionString) { Write-Error "Failed to retrieve connection string"; exit 1 }
Write-Success "Connection string retrieved"

# Create blob container
Write-Info "Creating 'orders' blob container..."
az storage container create `
    --name orders `
    --connection-string "$ConnectionString" `
    --public-access off

if ($LASTEXITCODE -eq 0) { Write-Success "Blob container created" } else { Write-Error "Failed to create blob container"; exit 1 }

# Create App Service Plan
Write-Info "Creating App Service Plan: $AppServicePlanName..."
az appservice plan create `
    --name $AppServicePlanName `
    --resource-group $ResourceGroupName `
    --sku B1 `
    --is-linux

if ($LASTEXITCODE -eq 0) { Write-Success "App Service Plan created" } else { Write-Error "Failed to create App Service Plan"; exit 1 }

# Create Function App
Write-Info "Creating Function App: $FunctionAppName..."
az functionapp create `
    --resource-group $ResourceGroupName `
    --consumption-plan-location $Location `
    --runtime dotnet-isolated `
    --runtime-version 10.0 `
    --functions-version 4 `
    --name $FunctionAppName `
    --storage-account $StorageAccountName

if ($LASTEXITCODE -eq 0) { Write-Success "Function App created" } else { Write-Error "Failed to create Function App"; exit 1 }

# Create Web App
Write-Info "Creating Web App: $WebAppName..."
az webapp create `
    --resource-group $ResourceGroupName `
    --plan $AppServicePlanName `
    --name $WebAppName `
    --runtime "DOTNET|10.0"

if ($LASTEXITCODE -eq 0) { Write-Success "Web App created" } else { Write-Error "Failed to create Web App"; exit 1 }

# Display connection information
Write-Info "================================================================"
Write-Info "Deployment Summary"
Write-Info "================================================================"
Write-Host "Resource Group: $ResourceGroupName" -ForegroundColor Yellow
Write-Host "Location: $Location" -ForegroundColor Yellow
Write-Host "Function App: $FunctionAppName" -ForegroundColor Yellow
Write-Host "Web App: $WebAppName" -ForegroundColor Yellow
Write-Host "Storage Account: $StorageAccountName" -ForegroundColor Yellow
Write-Info "================================================================"

# Save credentials to file
$CredentialsFile = "azure-credentials.txt"
@"
Deployment Information
Generated: $(Get-Date)

Resource Group Name: $ResourceGroupName
Function App Name: $FunctionAppName
Web App Name: $WebAppName
Storage Account Name: $StorageAccountName
Connection String: $ConnectionString

IMPORTANT: Keep this file secure and do not commit to version control.
"@ | Out-File $CredentialsFile
Write-Success "Credentials saved to $CredentialsFile (keep this file secure!)"

Write-Success "Azure resources created successfully!"
Write-Info "Next steps:"
Write-Info "1. Deploy Function App: cd ../OrderItemsReserver && func azure functionapp publish $FunctionAppName --build remote"
Write-Info "2. Get function key: az functionapp keys list --name $FunctionAppName --resource-group $ResourceGroupName"
Write-Info "3. Update appsettings.Production.json with the function URL"
Write-Info "4. Deploy Web App: cd src/Web && dotnet publish -c Release"
