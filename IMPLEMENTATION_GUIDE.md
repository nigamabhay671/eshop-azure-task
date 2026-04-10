# OrderItemsReserver Implementation Guide

This guide provides step-by-step instructions to complete the implementation of the OrderItemsReserver Azure Function service and its integration with the eShopOnWeb application.

## Overview

The OrderItemsReserver service is an Azure Function that:
1. Receives HTTP requests from the eShopOnWeb application after an order is created
2. Generates a JSON file containing order details (item ID, quantity)
3. Uploads the JSON file to Azure Blob Storage

Communication between eShopOnWeb and OrderItemsReserver is implemented via HTTP calls.

## Architecture

```
eShopOnWeb (Web Application)
    ↓
Checkout.cshtml.cs (OnPost)
    ↓
OrderItemsReserverService (HTTP POST)
    ↓
OrderItemsReserver Azure Function
    ↓
Azure Blob Storage (orders container)
```

## Changes Made

### 1. eShopOnWeb Web Project

#### Modified Files:

**src/ApplicationCore/Interfaces/IOrderService.cs**
- Modified `CreateOrderAsync` method to return the created `Order` object
- Change: `Task CreateOrderAsync(...)` → `Task<Order> CreateOrderAsync(...)`

**src/ApplicationCore/Services/OrderService.cs**
- Updated implementation to return the created `Order`

**src/Web/Interfaces/IOrderItemsReserverService.cs**
- Added using directive for `Microsoft.eShopWeb.ApplicationCore.Entities.OrderAggregate`

**src/Web/Services/OrderItemsReserverService.cs**
- Renamed file (removed trailing space)
- Added dependency injection for `ILogger<OrderItemsReserverService>`
- Added comprehensive error handling and logging
- Added null check for configuration URL

**src/Web/Pages/Basket/Checkout.cshtml.cs**
- Added `IOrderItemsReserverService` dependency injection
- Modified `OnPost` method to capture the returned `Order` object
- Added call to `_orderItemsReserverService.SendOrderAsync(order)` after successful order creation

**src/Web/appsettings.json**
- Corrected configuration structure
- Moved `OrderItemsReserver:Url` to the root level (from Logging section)
- Format: `"OrderItemsReserver": { "Url": "https://..." }`

**src/Web/Program.cs**
- Already contains: `builder.Services.AddHttpClient<IOrderItemsReserverService, OrderItemsReserverService>();`

### 2. OrderItemsReserver Azure Function Project

The following files are already in place:

**OrderItemsReserver/OrderItemsReserver.cs**
- HTTP-triggered Azure Function
- Accepts POST requests
- Deserializes order request from JSON
- Creates "orders" blob container if it doesn't exist
- Uploads order details as JSON file with timestamp

**OrderItemsReserver/Models/OrderRequest.cs**
- Contains `OrderId` and `Items` collection

**OrderItemsReserver/Models/OrderItemDto.cs**
- Contains `ItemId` and `Quantity`

**OrderItemsReserver/Program.cs**
- Configures BlobServiceClient dependency injection
- Uses connection string from `AzureWebJobsStorage` environment variable
- Enables Application Insights

## JSON File Format

Order request uploaded to Blob Storage:

```json
{
  "orderId": 123,
  "items": [
    {
      "itemId": 1,
      "quantity": 2
    },
    {
      "itemId": 5,
      "quantity": 1
    }
  ]
}
```

**File Naming**: `order-{OrderId}-{yyyyMMddHHmmss}.json`
- Example: `order-123-20260409143025.json`

## Deployment Instructions

### Prerequisites

- Azure Subscription
- Azure CLI installed
- Visual Studio 2026 (or compatible)
- .NET 10 SDK

### Step 1: Prepare Azure Resources

#### 1.1 Create Resource Group
```powershell
$resourceGroupName = "eshop-rg"
$location = "eastus"

az group create --name $resourceGroupName --location $location
```

#### 1.2 Create Storage Account
```powershell
$storageAccountName = "eshopaastorage123"  # Must be globally unique

az storage account create `
  --name $storageAccountName `
  --resource-group $resourceGroupName `
  --location $location `
  --sku Standard_LRS
```

#### 1.3 Create Blob Container
```powershell
$connectionString = az storage account show-connection-string `
  --name $storageAccountName `
  --resource-group $resourceGroupName `
  --query connectionString -o tsv

az storage container create `
  --name orders `
  --connection-string $connectionString
```

#### 1.4 Create App Service Plan
```powershell
$appServicePlanName = "eshop-asp"

az appservice plan create `
  --name $appServicePlanName `
  --resource-group $resourceGroupName `
  --sku B1 `
  --is-linux
```

#### 1.5 Create Function App
```powershell
$functionAppName = "eshop-orders-func"

az functionapp create `
  --resource-group $resourceGroupName `
  --consumption-plan-location $location `
  --runtime dotnet-isolated `
  --runtime-version 10.0 `
  --functions-version 4 `
  --name $functionAppName `
  --storage-account $storageAccountName
```

#### 1.6 Create App Service for eShopOnWeb
```powershell
$webAppName = "eshop-web-app"

az webapp create `
  --resource-group $resourceGroupName `
  --plan $appServicePlanName `
  --name $webAppName `
  --runtime "DOTNET|10.0"
```

### Step 2: Deploy OrderItemsReserver Function

#### 2.1 Build the Function Project
```powershell
cd ..\OrderItemsReserver
dotnet build --configuration Release
```

#### 2.2 Publish to Azure
```powershell
func azure functionapp publish $functionAppName --build remote
```

#### 2.3 Get Function URL
```powershell
$functionKey = az functionapp keys list `
  --name $functionAppName `
  --resource-group $resourceGroupName `
  --query "functionKeys.default" -o tsv

$functionUrl = "https://$functionAppName.azurewebsites.net/api/OrderItemsReserver?code=$functionKey"
echo $functionUrl
```

### Step 3: Configure eShopOnWeb Application

#### 3.1 Update appsettings.json for Azure
Modify `src/Web/appsettings.json`:

```json
{
  "OrderItemsReserver": {
    "Url": "https://<function-app-name>.azurewebsites.net/api/OrderItemsReserver?code=<function-key>"
  },
  "ConnectionStrings": {
    "CatalogConnection": "<Your Azure SQL Connection String>",
    "IdentityConnection": "<Your Azure SQL Connection String>"
  }
}
```

#### 3.2 Build eShopOnWeb
```powershell
cd src\Web
dotnet build --configuration Release
```

#### 3.3 Publish to Azure App Service
```powershell
dotnet publish --configuration Release

az webapp deployment source config-zip `
  --resource-group $resourceGroupName `
  --name $webAppName `
  --src ".\bin\Release\net10.0\publish\publish.zip"
```

### Step 4: Verify Configuration

#### 4.1 Check Function App Settings
```powershell
az functionapp config appsettings list `
  --name $functionAppName `
  --resource-group $resourceGroupName
```

Ensure `AzureWebJobsStorage` is properly set with the storage connection string.

#### 4.2 Check Web App Settings
```powershell
az webapp config appsettings list `
  --name $webAppName `
  --resource-group $resourceGroupName
```

#### 4.3 Monitor Blob Storage
```powershell
# List uploaded order files
az storage blob list `
  --container-name orders `
  --connection-string $connectionString `
  --output table
```

## Local Testing

### Prerequisites for Local Testing
- Azure Storage Emulator or Azure Storage Explorer
- Azure Functions Core Tools v4

### Test Steps

1. **Run eShopOnWeb locally**
```powershell
cd src\Web
dotnet run
```

2. **Run OrderItemsReserver locally**
```powershell
cd ..\OrderItemsReserver
func start
```

3. **Update local appsettings.json**
```json
{
  "OrderItemsReserver": {
    "Url": "http://localhost:7071/api/OrderItemsReserver"
  }
}
```

4. **Test Order Creation**
   - Navigate to the eShopOnWeb application
   - Add items to basket
   - Click checkout
   - Verify order is created and JSON file appears in Blob Storage

## Troubleshooting

### Function Not Receiving Request
- Check firewall rules on Function App
- Verify the URL in appsettings.json is correct
- Check Application Insights logs in Azure Portal

### Blob Storage Upload Failing
- Verify `AzureWebJobsStorage` connection string is correct
- Ensure "orders" container exists
- Check storage account access permissions

### Order Not Appearing After Checkout
- Check Application Insights in Azure Portal for errors
- Review OrderItemsReserverService logs
- Verify HTTP client timeout settings if needed

### Connection String Issues
- Retrieve using: `az storage account show-connection-string --name <storage-account-name> --resource-group <resource-group-name>`
- Use the connection string in local.settings.json and Function App settings

## Performance Considerations

- The HTTP call to the Azure Function is made synchronously after order creation
- For high-volume scenarios, consider implementing:
  - Async messaging (Service Bus, Event Grid)
  - Retry policies with exponential backoff
  - Connection pooling optimization

## Security Considerations

- Function Key is now required for access (AuthorizationLevel.Function)
- Never commit sensitive connection strings to version control
- Use Azure Key Vault for production secrets
- Implement CORS if Function is accessed from different domains
- Enable managed identities for Azure service authentication

## Verification Checklist

- [ ] Build succeeds without errors
- [ ] OrderItemsReserverService has proper logging
- [ ] Checkout page passes Order to OrderItemsReserverService
- [ ] Azure Function accepts POST requests
- [ ] Blob Storage connection is configured
- [ ] Order JSON files are uploaded to "orders" container
- [ ] Files have correct naming format (order-{id}-{timestamp}.json)
- [ ] Error handling covers all scenarios
- [ ] Application Insights configured for monitoring
- [ ] Documentation is updated

## Next Steps

1. Configure Application Insights for monitoring
2. Set up alerts for failed uploads
3. Implement retry logic for transient failures
4. Consider implementing a message queue for decoupled processing
5. Add audit logging for compliance
6. Set up automated backups for Blob Storage
