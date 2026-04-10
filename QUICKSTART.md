# Quick Start Guide - OrderItemsReserver Deployment

## 30-Minute Deployment Guide

### Prerequisites Check (2 min)
```powershell
# Check Azure CLI
az --version

# Check .NET SDK
dotnet --version

# Check PowerShell
$PSVersionTable.PSVersion

# Login to Azure
az login
az account list --output table
```

### Step 1: Prepare Azure (5 min)

Save the following as variables:
```powershell
$subscription = "YOUR-SUBSCRIPTION-ID"
$rg = "eshop-rg"
$location = "eastus"
$funcName = "eshop-orders-func"
$storName = "eshopstore123"  # Must be globally unique
$webApp = "eshop-web-app"
$aspName = "eshop-asp"
```

Run the automated deployment script:
```powershell
.\deploy.ps1 `
  -SubscriptionId $subscription `
  -ResourceGroupName $rg `
  -Location $location `
  -FunctionAppName $funcName `
  -StorageAccountName $storName `
  -WebAppName $webApp `
  -AppServicePlanName $aspName
```

**Result**: All Azure resources created ✓

### Step 2: Deploy Azure Function (8 min)

```powershell
# Navigate to function project
cd ..\OrderItemsReserver

# Build and publish
func azure functionapp publish $funcName --build remote

# Get function key
$funcKey = az functionapp keys list `
  --name $funcName `
  --resource-group $rg `
  --query "functionKeys.default" -o tsv

# Display function URL
$funcUrl = "https://$funcName.azurewebsites.net/api/OrderItemsReserver?code=$funcKey"
Write-Host "Function URL: $funcUrl" -ForegroundColor Green
```

**Result**: OrderItemsReserver Function deployed ✓

### Step 3: Configure & Deploy Web App (10 min)

```powershell
# Go back to web project
cd ..\eshop-azure-task\src\Web

# Update appsettings.Production.json with function URL
# Replace <your-function-app> and <function-key>

# Build and publish
dotnet publish --configuration Release

# Deploy to Azure App Service
cd bin\Release\net10.0\publish
$zipPath = "publish.zip"
Compress-Archive -Path * -DestinationPath $zipPath -Force

az webapp deployment source config-zip `
  --name $webApp `
  --resource-group $rg `
  --src $zipPath
```

**Result**: eShopOnWeb deployed to Azure ✓

### Step 4: Verify Deployment (5 min)

```powershell
# Check Function App is running
az functionapp show --name $funcName --resource-group $rg

# Check Web App is running
az webapp show --name $webApp --resource-group $rg

# List blob containers
$connStr = az storage account show-connection-string `
  --name $storName `
  --resource-group $rg `
  --query connectionString -o tsv

az storage container list --connection-string "$connStr"

# List orders uploaded
az storage blob list --container-name orders --connection-string "$connStr" --output table
```

### Step 5: Test Checkout Flow (Included in Step 4 timing)

1. Open web app URL (check App Service in Azure Portal)
2. Add items to basket
3. Proceed to checkout
4. Verify order created
5. Check Blob Storage for JSON file:
   ```powershell
   az storage blob list --container-name orders --connection-string "$connStr" --output table
   ```

## Troubleshooting Quick Fixes

### Function not accessible
```powershell
# Check function app status
az functionapp show --name $funcName --resource-group $rg --query state

# Restart function app
az functionapp restart --name $funcName --resource-group $rg
```

### Can't find blob container
```powershell
# Verify storage account connection
$connStr = az storage account show-connection-string `
  --name $storName --resource-group $rg --query connectionString -o tsv

# Create container if missing
az storage container create --name orders --connection-string "$connStr"
```

### Web app won't start
```powershell
# Check app service logs
az webapp log tail --name $webApp --resource-group $rg

# Check if function URL is correct in appsettings.Production.json
```

## Local Testing (Instead of Azure Deployment)

### Terminal 1: Start Azure Storage Emulator
```powershell
# Using Azure Storage Emulator or Azurite
azurite --silent --location c:\azurite
```

### Terminal 2: Start Azure Function
```powershell
cd ../OrderItemsReserver

# Update local.settings.json:
# "AzureWebJobsStorage": "UseDevelopmentStorage=true"

func start
```

### Terminal 3: Start Web App
```powershell
cd src/Web

# Update appsettings.json:
# "OrderItemsReserver": { "Url": "http://localhost:7071/api/OrderItemsReserver" }

dotnet run
```

**Result**: Full local testing environment ✓

## Cleanup (Delete All Resources)

```powershell
# Delete entire resource group (CAUTION: Deletes everything)
az group delete --name $rg --yes --no-wait
```

## Key Files Reference

| File | Purpose |
|------|---------|
| `IMPLEMENTATION_GUIDE.md` | Detailed step-by-step guide |
| `DEPLOYMENT_SUMMARY.md` | Architecture & overview |
| `IMPLEMENTATION_COMPLETE.md` | Complete implementation details |
| `deploy.ps1` | Automated Azure setup script |
| `appsettings.Production.json` | Production configuration template |

## Success Indicators

✅ **Function Deployed**
- `az functionapp show --name $funcName` returns active status

✅ **Web App Deployed**  
- Web app URL is accessible in browser

✅ **Order Flow Works**
- Checkout completes without error

✅ **Blob Storage Active**
- JSON files appear in "orders" container after checkout

✅ **Monitoring Active**
- Application Insights shows function invocations

## Common Configuration Values

For reference when deploying:

```json
{
  "Resource Group": "eshop-rg",
  "Location": "eastus",
  "Function App": "eshop-orders-func",
  "Storage Account": "eshopstore123",
  "Web App": "eshop-web-app",
  "App Service Plan": "eshop-asp",
  "API Endpoint": "/api/OrderItemsReserver",
  "Blob Container": "orders",
  "Function Trigger": "HTTP POST"
}
```

## Time Estimates

- Resource Creation: 5 minutes
- Function Deployment: 8 minutes  
- Web App Deployment: 10 minutes
- Verification & Testing: 5 minutes
- **Total: ~30 minutes**

---

**Need Help?**
- Detailed guide: `IMPLEMENTATION_GUIDE.md`
- Architecture details: `DEPLOYMENT_SUMMARY.md`
- All implementation info: `IMPLEMENTATION_COMPLETE.md`
- Troubleshooting: See IMPLEMENTATION_GUIDE.md Troubleshooting section
